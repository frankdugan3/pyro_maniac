defmodule PyroManiac.Dsl.Transformers.LiftViewActions do
  @moduledoc false

  # The actions of the views (`action`, `bulk_action`, the `action` of a
  # column, `edit_columns`) become the form actions of the page: one entity
  # for each action name and view, in the internal `[:forms]` path, with its
  # tree filtered by `only`. `ExpandFormActions` expands and validates them.
  #
  # - In a card, an action without nodes uses the tree of the card.
  # - An action with nodes has its own tree. `delegate_to` this page uses the
  #   tree of the same action in another view of the page.
  # - In a list view, an action has its own tree or `delegate_to`. An action
  #   without inputs (a destroy, a status change) is a confirmation.
  # - `only` names the read action of the view and the actions of the tree.
  # - Each exposed action of the resource is used by a view, or is in `page
  #   do exclude [...] end` (`validate_used/1`, from `ValidatePrimaryViews`).
  #
  # Sets `__editable?__` and `__actions__` of each view.

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Form.{Action, BulkAction, Tree}
  alias PyroManiac.View.{Column, EditColumns, View}

  @impl true
  def after?(PyroManiac.Dsl.Transformers.ResolveViewResources), do: true
  def after?(PyroManiac.Dsl.Transformers.ExpandViewArguments), do: true
  def after?(PyroManiac.Dsl.Transformers.ValidateViews), do: true
  def after?(_), do: false

  @impl true
  def before?(PyroManiac.Dsl.Transformers.ExpandFormActions), do: true
  def before?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    resource = Transformer.get_persisted(dsl, :resource, nil)
    views = for %View{} = view <- Transformer.get_entities(dsl, [:views]), do: view

    context = %{
      module: module,
      resource: resource,
      actions: Map.new(Ash.Resource.Info.actions(resource), &{&1.name, &1})
    }

    entries = Enum.flat_map(views, &view_entries(&1, context))
    entries = resolve_self_delegation(entries, module)

    Enum.each(views, &validate_only(&1, context))
    Enum.each(views, &validate_create_options(&1, entries, context))
    Enum.each(views, &validate_reorder(&1, context))
    validate_link_counts(views, module)
    Enum.each(views, &validate_paths(&1, context))

    dsl =
      Enum.reduce(views, dsl, fn view, dsl ->
        names = for entry <- entries, entry.__view__ == view_key(view), do: hd(entry.name)
        names = Enum.uniq(names)
        updated = %{view | "__editable?__": names != [], __actions__: names}
        Transformer.replace_entity(dsl, [:views], updated, &(&1 == view))
      end)

    {:ok, Enum.reduce(entries, dsl, &Transformer.add_entity(&2, [:forms], &1, type: :append))}
  end

  # The entries of a view -------------------------------------------------

  defp view_entries(%View{} = view, context) do
    key = view_key(view)

    action_entries =
      for %Action{} = action <- view.actions || [], name <- action.name do
        view_action(action, name, view, key, context)
      end

    bulk_entries =
      for %BulkAction{} = bulk <- view.bulk_actions || [], name <- bulk.name do
        %{bulk | name: [name], fields: Tree.for_action(bulk.fields, name), __view__: key}
      end

    action_entries ++ bulk_entries ++ column_entries(view, key, context)
  end

  defp view_action(action, name, view, key, context) do
    resource_action = resource_action!(action, name, view, context)

    tree =
      cond do
        action.fields != [] -> action.fields
        not is_nil(action.delegate_to) -> []
        view.type == :card -> view.fields
        no_inputs?(resource_action) -> []
        true -> no_tree_error(action, name, view, context)
      end

    %{action | name: [name], fields: Tree.for_action(tree, name), __view__: key}
  end

  # An action without inputs (no accepted attribute, no public argument) is
  # a confirmation: it has no form.
  defp no_inputs?(resource_action) do
    (Map.get(resource_action, :accept) || []) == [] and
      not Enum.any?(resource_action.arguments, & &1.public?)
  end

  defp resource_action!(%Action{resource: other} = action, name, view, context)
       when not is_nil(other) and other != context.resource do
    Ash.Resource.Info.action(other, name) || unknown_action(action, name, view, other, context)
  end

  defp resource_action!(action, name, view, context) do
    case Map.get(context.actions, name) do
      %{type: :read} ->
        Error.raise!(
          module: context.module,
          location: Entity.anno(action),
          path: [:view, :action, name],
          why:
            "#{inspect(name)} is a read action. The read action of a view is its name " <>
              "(or `read_action`); `action` names a write action",
          fix: "name a create, update, destroy, or generic action"
        )

      nil ->
        unknown_action(action, name, view, context.resource, context)

      resource_action ->
        resource_action
    end
  end

  defp unknown_action(action, name, _view, resource, context) do
    Error.raise!(
      module: context.module,
      location: Entity.anno(action),
      path: [:view, :action, name],
      why: "action #{inspect(name)} not found in resource #{inspect(resource)}",
      suggestions:
        Error.did_you_mean(name, resource |> Ash.Resource.Info.actions() |> Enum.map(& &1.name))
    )
  end

  defp no_tree_error(action, name, view, context) do
    Error.raise!(
      module: context.module,
      location: Entity.anno(action),
      path: [:view, :action, name],
      why:
        "`action #{inspect(name)}` in a #{inspect(view.type)} view has no form: a list view " <>
          "has no record tree to use",
      fix:
        "give the action its own nodes, or `delegate_to` a page whose view has the action " <>
          "(this page for its card)"
    )
  end

  # The `action` of a column (an inline edit of its cell) and `edit_columns`.
  defp column_entries(view, key, context) do
    names = for %Column{name: name} <- view.columns || [], do: name

    edit_entries =
      for %EditColumns{} = edit <- view.edit_columns || [] do
        validate_edit_columns(edit, names, view, context)

        %Action{
          name: [edit.action],
          state: edit.state,
          fields: edit.fields,
          __view__: key,
          __columns__: edit.columns,
          __spark_metadata__: edit.__spark_metadata__
        }
      end

    edited = Enum.flat_map(view.edit_columns || [], & &1.columns)

    cell_entries =
      for %Column{actions: actions} = column <- view.columns || [],
          %Action{} = action <- actions || [],
          name <- action.name do
        validate_cell_action(column, action, name, edited, view, context)
        %{action | name: [name], __view__: key, __column__: column.name}
      end

    cell_entries ++ edit_entries
  end

  defp validate_edit_columns(edit, names, view, context) do
    for column <- edit.columns, column not in names do
      Error.raise!(
        module: context.module,
        location: Entity.anno(edit),
        path: [:view, view_name(view), :edit_columns, edit.action],
        why: "#{inspect(column)} is not a column of the view",
        suggestions: Error.did_you_mean(column, names)
      )
    end
  end

  defp validate_cell_action(column, action, name, edited, view, context) do
    cond do
      column.name in edited ->
        Error.raise!(
          module: context.module,
          location: Entity.anno(action),
          path: [:view, view_name(view), :column, column.name, :action, name],
          why:
            "column #{inspect(column.name)} is in `edit_columns`, so it has no `action` of " <>
              "its own",
          fix: "remove the `action` of the column, or the column from `edit_columns`"
        )

      action.fields == [] ->
        Error.raise!(
          module: context.module,
          location: Entity.anno(action),
          path: [:view, view_name(view), :column, column.name, :action, name],
          why: "the `action` of column #{inspect(column.name)} has no inputs",
          fix: "add the inputs of the cell, for example `select #{inspect(column.name)}`"
        )

      node = Enum.find(Tree.all(action.fields), &(not inline_node?(&1))) ->
        Error.raise!(
          module: context.module,
          location: Entity.anno(node),
          path: [:view, view_name(view), :column, column.name, :action, name],
          why:
            "an inline edit has inputs only: `#{node.__struct__.__entity__().name}` is not " <>
              "an input",
          fix: "keep `field`, `select`, `combobox`, `input`, and `compound` in the cell"
        )

      option = Enum.find([:delegate_to, :resource], &Map.get(action, &1)) ->
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(action, option) || Entity.anno(action),
          path: [:view, view_name(view), :column, column.name, :action, name],
          why: "an inline edit is an action of the record of its row, without `#{option}`",
          fix: "remove `#{option}`"
        )

      true ->
        :ok
    end
  end

  # A node has one `link_to`: it links to one page.
  defp validate_link_counts(views, module) do
    for view <- views,
        entity <- (view.columns || []) ++ Tree.all(view.fields || []) ++ action_nodes(view),
        match?([_, _ | _], Map.get(entity, :link_to) || []) do
      Error.raise!(
        module: module,
        location: Entity.anno(entity),
        path: [:views, :view, view_name(view)],
        why:
          "#{inspect(entity.name)} has more than one `link_to`. A node links to one page: " <>
            "`single_view` for each record, `list_view` for all the records",
        fix: "keep one `link_to`"
      )
    end
  end

  defp action_nodes(view) do
    for %Action{fields: fields} <- view.actions || [], node <- Tree.all(fields), do: node
  end

  # The `path` of a node is a path of relationships from the resource of
  # the node that contains it.
  defp validate_paths(%View{} = view, context) do
    walk_paths(view.fields || [], view.resource || context.resource, view, context)
  end

  defp walk_paths(nodes, resource, view, context) do
    for node <- nodes do
      path = Map.get(node, :path) || []
      destination = follow_path(path, resource, node, view, context)
      walk_paths(Tree.children(node), destination, view, context)
    end
  end

  defp follow_path(path, resource, node, view, context) do
    Enum.reduce(path, resource, fn name, current ->
      case Ash.Resource.Info.relationship(current, name) do
        %{destination: destination} ->
          destination

        nil ->
          Error.raise!(
            module: context.module,
            location: Entity.property_anno(node, :path) || Entity.anno(node),
            path: [:views, :view, view_name(view), Map.get(node, :name) || :node, :path],
            why:
              "#{inspect(name)} in the path #{inspect(path)} is not a relationship of " <>
                inspect(current),
            suggestions:
              Error.did_you_mean(
                name,
                Enum.map(Ash.Resource.Info.relationships(current), & &1.name)
              )
          )
      end
    end)
  end

  defp inline_node?(%module{}),
    do:
      module in [
        PyroManiac.Form.Field,
        PyroManiac.Form.Select,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Input,
        PyroManiac.Form.Compound
      ]

  # `delegate_to` this page: the tree of the same action in another view.
  defp resolve_self_delegation(entries, module) do
    Enum.map(entries, fn
      %Action{delegate_to: ^module, name: [name]} = entry ->
        source =
          Enum.find(entries, fn other ->
            match?(%Action{delegate_to: nil, __column__: nil, __columns__: []}, other) and
              other.name == [name] and other.__view__ != entry.__view__
          end)

        case source do
          nil ->
            Error.raise!(
              module: module,
              location: Entity.property_anno(entry, :delegate_to) || Entity.anno(entry),
              path: [:view, elem(entry.__view__, 0), :action, name],
              why: "no other view of this page has the action #{inspect(name)}",
              fix: "name the action in the card of the page, or give it its own nodes"
            )

          source ->
            %{entry | delegate_to: nil, fields: source.fields, sets: entry.sets ++ source.sets}
        end

      entry ->
        entry
    end)
  end

  # `reorder?` needs an ordered resource and a list view.
  defp validate_reorder(%View{reorder?: false}, _context), do: :ok

  defp validate_reorder(%View{} = view, context) do
    resource = view.resource || context.resource

    cond do
      view.type not in [:data_table, :grid, :list] ->
        reorder_error(
          view,
          context,
          "a #{inspect(view.type)} view has no order to drag",
          "remove `reorder?`"
        )

      is_nil(PyroManiac.Ordering.Info.ordering(resource)) ->
        reorder_error(
          view,
          context,
          "#{inspect(resource)} has no order: `reorder?` moves a record with the move action of `PyroManiac.Ordering`",
          "add `PyroManiac.Ordering` to the extensions of the resource, with `ordering do attribute :position end`"
        )

      true ->
        :ok
    end
  end

  defp reorder_error(view, context, why, fix) do
    Error.raise!(
      module: context.module,
      location: Entity.property_anno(view, :reorder?) || Entity.anno(view),
      path: [:views, :view, view_name(view), :reorder?],
      why: why,
      fix: fix
    )
  end

  # `clone?` and `new_row?` need a create action of the view. A new row has
  # the inline edit of a column for each required input of the create.
  defp validate_create_options(%View{} = view, entries, context) do
    create =
      Enum.find(entries, fn entry ->
        match?(%Action{__column__: nil, __columns__: []}, entry) and
          entry.__view__ == view_key(view) and
          match?(%{type: :create}, Map.get(context.actions, hd(entry.name)))
      end)

    for option <- [:clone?, :new_row?], Map.get(view, option), is_nil(create) do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(view, option) || Entity.anno(view),
        path: [:views, :view, view_name(view), option],
        why: "`#{option}` makes records with a create action, but the view names none",
        fix: "add `action :create, :guard` (or another create action) to the view"
      )
    end

    if view.new_row? and create, do: validate_new_row(view, hd(create.name), entries, context)
  end

  defp validate_new_row(%View{type: type} = view, _create, _entries, context)
       when type != :data_table do
    Error.raise!(
      module: context.module,
      location: Entity.property_anno(view, :new_row?) || Entity.anno(view),
      path: [:views, :view, view_name(view), :new_row?],
      why: "`new_row?` is a row of a `:data_table`, not of a #{inspect(type)} view",
      fix: "remove `new_row?`"
    )
  end

  defp validate_new_row(view, create, entries, context) do
    inputs =
      for %Action{__column__: column, name: [^create], fields: fields} <- entries,
          column != nil,
          input <- Tree.inputs(fields),
          into: MapSet.new(),
          do: input.name

    action = Map.fetch!(context.actions, create)

    for name <- required_inputs(context.resource, action), not MapSet.member?(inputs, name) do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(view, :new_row?) || Entity.anno(view),
        path: [:views, :view, view_name(view), :new_row?],
        why:
          "the new row creates a record with #{inspect(create)}, which requires " <>
            "#{inspect(name)}, but no column edits it",
        fix:
          "add `column #{inspect(name)} do action #{inspect(create)}, :discard do field " <>
            "#{inspect(name)} end end`"
      )
    end
  end

  # The inputs that a create action requires: accepted attributes and
  # arguments that do not allow `nil` and have no default.
  defp required_inputs(resource, action) do
    attributes =
      for name <- Map.get(action, :accept) || [],
          %{allow_nil?: false} = attribute <- [Ash.Resource.Info.attribute(resource, name)],
          is_nil(attribute.default) and not attribute.generated?,
          do: name

    arguments =
      for %{allow_nil?: false, default: nil, public?: true, name: name} <- action.arguments,
          do: name

    attributes ++ arguments
  end

  # `only` ------------------------------------------------------------------

  # The names of `only` are the read action of the view and the actions of
  # the tree. An action with its own tree: its own names.
  defp validate_only(%View{} = view, context) do
    read = read_name(view)

    card_names =
      if view.type == :card,
        do:
          for(%Action{fields: [], delegate_to: nil} = a <- view.actions || [], n <- a.name, do: n),
        else: []

    validate_only_nodes(view.fields, [read | card_names], view, context)

    for %Action{fields: [_ | _]} = action <- view.actions || [] do
      validate_only_nodes(action.fields, action.name, view, context)
    end
  end

  defp validate_only_nodes(nodes, allowed, view, context) do
    for node <- Tree.all(nodes),
        only = Map.get(node, :only),
        not is_nil(only),
        name <- List.wrap(only),
        name not in allowed do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(node, :only) || Entity.anno(node),
        path: [:view, view_name(view), Map.get(node, :name) || :node, :only],
        why:
          "`only` has #{inspect(name)}, which is not an action of this tree. The actions are " <>
            inspect(allowed) <> " (the read action of the view is view mode)",
        suggestions: Error.did_you_mean(name, allowed)
      )
    end
  end

  # The actions of the page -------------------------------------------------

  @doc """
  Each exposed action of the resource is used by a view or excluded (on a
  page), and an excluded action is not used. Called by `ValidatePrimaryViews`, which runs
  last, so that the other errors of a page show first.
  """
  def validate_used(dsl) do
    views = for %View{} = view <- Transformer.get_entities(dsl, [:views]), do: view
    entries = Transformer.get_entities(dsl, [:forms])
    resource = Transformer.get_persisted(dsl, :resource, nil)
    context = %{module: Transformer.get_persisted(dsl, :module, nil), resource: resource}
    validate_used(dsl, views, entries, context)
  end

  defp validate_used(dsl, views, entries, context) do
    excluded = Transformer.get_option(dsl, [:page], :exclude, [])

    used =
      MapSet.new(
        Enum.flat_map(views, &view_read_names/1) ++
          for(
            %{name: name} = entry <- entries,
            Map.get(entry, :resource) in [nil, context.resource],
            do: name |> List.wrap() |> hd()
          ) ++
          kanban_moves(views, context.resource) ++ reorder_moves(views, context.resource)
      )

    for name <- excluded, MapSet.member?(used, name) do
      Error.raise!(
        module: context.module,
        location: Transformer.get_opt_anno(dsl, [:page], :exclude),
        path: [:page, :exclude],
        why: "action #{inspect(name)} is listed in `exclude`, but a view uses it",
        fix: "remove #{inspect(name)} from `exclude`, or remove it from the view"
      )
    end

    storage =
      PyroManiac.Dsl.Transformers.ExpandFormActions.ash_storage_action_names(context.resource)

    # A module without a `page` section reuses some views, so it does not
    # use each exposed action.
    missing =
      for %{name: name} <- Ash.Resource.Info.actions(context.resource),
          PyroManiac.Dsl.Transformers.ValidatePage.page?(dsl),
          PyroManiac.Resource.Info.exposed?(context.resource, name),
          name not in excluded,
          name not in storage,
          not MapSet.member?(used, name),
          do: name

    if missing != [] do
      Error.raise!(
        module: context.module,
        location: page_location(dsl, views),
        path: [:page],
        why:
          "the exposed actions #{inspect(missing)} of #{inspect(context.resource)} are not " <>
            "used by a view and not excluded",
        fix:
          "name each one in a view (the name of a view for a read action, `action` for the " <>
            "others), or add it to `page do exclude [...] end`"
      )
    end

    :ok
  end

  defp page_location(dsl, views) do
    case Transformer.get_section_anno(dsl, [:page]) do
      anno when anno in [nil, []] -> Enum.find_value(views, &Entity.anno/1)
      anno -> anno
    end
  end

  defp view_read_names(%View{} = view),
    do: List.wrap(view.read_action) ++ List.wrap(view.name)

  defp kanban_moves(views, resource) do
    if Enum.any?(views, &(&1.type == :kanban)) and PyroManiac.KanBan.Info.has_kanban?(resource),
      do: [PyroManiac.KanBan.Info.move_action!(resource)],
      else: []
  end

  defp reorder_moves(views, resource) do
    case Enum.any?(views, & &1.reorder?) && PyroManiac.Ordering.Info.ordering(resource) do
      %{move_action: move} -> [move]
      _ -> []
    end
  end

  defp read_name(%View{read_action: nil, name: [name | _]}), do: name
  defp read_name(%View{read_action: read_action}), do: read_action

  defp view_key(%View{type: type} = view), do: {view_name(view), type}

  defp view_name(%View{name: [name | _]}), do: name
  defp view_name(_view), do: :view
end
