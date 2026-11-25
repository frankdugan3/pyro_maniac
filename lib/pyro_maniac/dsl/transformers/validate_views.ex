defmodule PyroManiac.Dsl.Transformers.ValidateViews do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias Ash.Resource
  alias PyroManiac.Dsl.Error
  alias PyroManiac.View.{Column, View}

  @ash_resource_transformers Resource.Dsl.transformers()

  @impl true
  def after?(PyroManiac.Dsl.Transformers.ResolveViewResources), do: true
  def after?(module) when module in @ash_resource_transformers, do: true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    views = Transformer.get_entities(dsl, [:views])

    validate_no_duplicate_views(views, module)

    default_resource = Transformer.get_persisted(dsl, :resource, nil)

    {final_views, any_kanban_mutated?} =
      Enum.map_reduce(views, false, fn
        %View{type: :kanban} = view, _mutated? ->
          resource = view.resource || default_resource
          validate_named_view(view, module)
          validate_no_kanban_options(view, module)
          validate_view(view, resource, module)
          view = populate_kanban_from_extension(view, resource)
          {view, true}

        %View{} = view, mutated? ->
          resource = view.resource || default_resource
          validate_named_view(view, module)
          validate_view(view, resource, module)
          {view, mutated?}
      end)

    dsl =
      if any_kanban_mutated? do
        dsl =
          Transformer.remove_entity(dsl, [:views], fn
            %View{} -> true
            _ -> false
          end)

        Enum.reduce(Enum.reverse(final_views), dsl, fn view, dsl ->
          Transformer.add_entity(dsl, [:views], view, prepend: true)
        end)
      else
        dsl
      end

    {:ok, dsl}
  end

  defp validate_no_duplicate_views(views, module) do
    pairs =
      for %View{name: names, type: type} = view <- views,
          name <- names do
        {name, type, view}
      end

    Enum.reduce(pairs, %{}, fn {name, type, view}, seen ->
      key = {name, type}

      if Map.has_key?(seen, key) do
        Error.raise!(
          module: module,
          location: Entity.anno(view),
          path: [:views, :view, name, type],
          why:
            "view {#{inspect(name)}, #{inspect(type)}} is already defined. " <>
              "Each action + type combination must be unique."
        )
      else
        Map.put(seen, key, true)
      end
    end)
  end

  defp validate_named_view(%View{} = view, module) do
    if view.name == [] do
      Error.raise!(
        module: module,
        location: Entity.anno(view),
        path: [:views, :view],
        why: "a view requires `name` to be set",
        fix: "add an action name like `view :read do ... end`"
      )
    end
  end

  # The options of one view type. A value on another type would be ignored.
  @type_options [
    orientation: [:timeline, :kanban],
    granularity: [:calendar],
    parent_field: [:list]
  ]

  defp validate_type_options(%View{type: type} = view, module) do
    for {option, for_types} <- @type_options,
        type not in for_types,
        not is_nil(Map.get(view, option)) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, option) || Entity.anno(view),
        path: [:views, :view, hd(view.name), option],
        why:
          "`#{option}` is an option of a #{Enum.map_join(for_types, " or ", &"`#{inspect(&1)}`")} " <>
            "view, but this view is `#{inspect(type)}`, so it would be ignored",
        fix:
          "remove `#{option}`, or make the view " <>
            Enum.map_join(for_types, " or ", &"`type #{inspect(&1)}`")
      )
    end
  end

  # The orientation of a stepper needs steps: on the view (a value other
  # than the default), the tree of the view or of one of its actions; on an
  # action, the tree of its form.
  defp validate_step_orientation(%View{} = view, module) do
    if view.step_orientation != :horizontal and not steps?(view.fields) and
         not Enum.any?(view.actions, &steps?(&1.fields)) do
      raise_step_orientation(view, view, module)
    end

    for %PyroManiac.Form.Action{step_orientation: orientation, delegate_to: nil} = action <-
          view.actions,
        not is_nil(orientation),
        not steps?(if(action.fields == [], do: view.fields, else: action.fields)) do
      raise_step_orientation(action, view, module)
    end

    :ok
  end

  defp steps?(nodes), do: Enum.any?(nodes, &is_struct(&1, PyroManiac.Form.Step))

  defp raise_step_orientation(entity, view, module) do
    Error.raise!(
      module: module,
      location: Entity.property_anno(entity, :step_orientation) || Entity.anno(entity),
      path: [:views, :view, hd(view.name), :step_orientation],
      why:
        "`step_orientation` is the axis of the stepper of the `step` entities of a form, " <>
          "but this form has no `step`, so it would be ignored",
      fix: "remove `step_orientation`, or divide the form into `step` entities"
    )
  end

  # The tree of a `:list`: a `belongs_to` of the resource to itself.
  defp validate_parent_field(%View{type: :list, parent_field: parent} = view, resource, module)
       when not is_nil(parent) do
    case Ash.Resource.Info.relationship(resource, parent) do
      %Ash.Resource.Relationships.BelongsTo{destination: ^resource} ->
        :ok

      _other ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(view, :parent_field) || Entity.anno(view),
          path: [:views, :view, hd(view.name), :parent_field],
          why:
            "`parent_field #{inspect(parent)}` makes a tree of the records, but it is not a " <>
              "`belongs_to` from #{inspect(resource)} to #{inspect(resource)}",
          fix:
            "name the `belongs_to` of a record to its parent, for example `parent_field :parent`"
        )
    end
  end

  defp validate_parent_field(_view, _resource, _module), do: :ok

  defp validate_view(%View{} = view, resource, module) do
    validate_type_options(view, module)
    validate_step_orientation(view, module)
    validate_parent_field(view, resource, module)
    validate_ensure_loaded(view, resource, module)
    do_validate_view(view, resource, module)
  end

  defp validate_ensure_loaded(%View{ensure_loaded: []}, _resource, _module), do: :ok

  defp validate_ensure_loaded(%View{ensure_loaded: ensure_loaded} = view, resource, module) do
    query = Ash.Query.load(Ash.Query.new(resource), ensure_loaded)

    if !query.valid? do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :ensure_loaded) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :ensure_loaded],
        why:
          "#{inspect(ensure_loaded)} is an invalid Ash load statement for #{inspect(resource)}.\n\n" <>
            Ash.Error.error_descriptions(query.errors)
      )
    end
  end

  defp do_validate_view(%View{type: :data_table} = view, resource, module) do
    validate_action_exists(view, resource, module)
    validate_no_duplicate_columns(view, module)
    validate_all_columns_valid(view, resource, module)
    validate_all_exposed_included(view, resource, module)
    validate_default_displays_valid(view, module)
    validate_default_sorts_valid(view, resource, module)
  end

  defp do_validate_view(%View{type: :render} = view, _resource, module) do
    if view.render == [] do
      Error.raise!(
        module: module,
        location: Entity.anno(view),
        path: [:views, :view, hd(view.name)],
        why: "a `:render` view has a `render` for each renderer of the page",
        fix:
          "add `render PyroManiac.LiveView, BreweryWeb.Components.Dashboard` inside the view block"
      )
    end
  end

  defp do_validate_view(%View{type: :kanban} = view, resource, module) do
    validate_action_exists(view, resource, module)

    if !PyroManiac.KanBan.Info.has_kanban?(resource) do
      Error.raise!(
        module: module,
        location: Entity.anno(view),
        path: [:views, :view, hd(view.name)],
        why:
          "kanban views require the resource #{inspect(resource)} to use the PyroManiac.KanBan extension",
        fix: "add `use PyroManiac.KanBan` to the resource"
      )
    end
  end

  defp do_validate_view(%View{type: :calendar} = view, resource, module) do
    validate_action_exists(view, resource, module)

    if is_nil(view.date_field) do
      candidates = date_attribute_names(resource)

      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :date_field) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :date_field],
        why: "calendar views require `date_field` to be set",
        suggestions: candidates,
        fix: "set `date_field :brew_date` to a date or datetime attribute on the resource"
      )
    end
  end

  defp do_validate_view(%View{type: :timeline} = view, resource, module) do
    validate_action_exists(view, resource, module)

    if is_nil(view.date_field) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :date_field) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :date_field],
        why: "timeline views require `date_field` to be set",
        suggestions: date_attribute_names(resource),
        fix: "set `date_field :brew_date` to a date or datetime attribute on the resource"
      )
    end
  end

  defp do_validate_view(%View{type: :gantt} = view, resource, module) do
    validate_action_exists(view, resource, module)
    candidates = date_attribute_names(resource)

    if is_nil(view.start_field) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :start_field) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :start_field],
        why: "gantt views require `start_field` to be set",
        suggestions: candidates,
        fix: "set `start_field :brew_date` to a date or datetime attribute on the resource"
      )
    end

    if is_nil(view.end_field) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :end_field) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :end_field],
        why: "gantt views require `end_field` to be set",
        suggestions: candidates,
        fix: "set `end_field :package_date` to a date or datetime attribute on the resource"
      )
    end
  end

  defp do_validate_view(%View{} = view, resource, module) do
    validate_action_exists(view, resource, module)
  end

  # A kanban view takes its lanes, its move action, and its order from the
  # `kan_ban` section of the resource. A value on the view would be ignored.
  @kanban_options [:group_by, :kanban_action, :priority, :default_sort]

  defp validate_no_kanban_options(view, module) do
    for option <- @kanban_options, not is_nil(Map.get(view, option)) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, option) || Entity.anno(view),
        path: [:views, :view, hd(view.name), option],
        why:
          "a `:kanban` view takes `#{option}` from the `kan_ban` section of the resource, so " <>
            "this value would be ignored",
        fix:
          "remove `#{option}` from the view, and set it in the `kan_ban` section of the resource"
      )
    end
  end

  defp populate_kanban_from_extension(view, resource) do
    lane = PyroManiac.KanBan.Info.lane_attribute!(resource)
    priority = PyroManiac.KanBan.Info.priority!(resource)
    move_action = PyroManiac.KanBan.Info.move_action!(resource)

    %{
      view
      | default_sort: Atom.to_string(priority),
        group_by: lane,
        kanban_action: move_action,
        priority: priority
    }
  end

  defp validate_action_exists(%View{name: names} = view, resource, module) do
    for name <- names do
      resource_action = Resource.Info.action(resource, name)

      if !resource_action do
        suggestions = read_action_suggestions(name, resource)

        Error.raise!(
          module: module,
          location: Entity.anno(view),
          path: [:views, :view, name],
          why: "action #{inspect(name)} not found on resource #{inspect(resource)}",
          suggestions: suggestions
        )
      end

      if resource_action.type != :read do
        Error.raise!(
          module: module,
          location: Entity.anno(view),
          path: [:views, :view, name],
          why:
            "action #{inspect(name)} is type #{inspect(resource_action.type)}, " <>
              "but views require :read actions",
          fix: "pick a read action, or change action #{inspect(name)} to type :read"
        )
      end

      validate_pagination_supported(view, name, resource_action, resource, module)
      validate_count_supported(view, name, resource_action, resource, module)
    end
  end

  defp validate_count_supported(%View{count?: true} = view, name, action, resource, module) do
    if action.pagination == false or
         (action.pagination && action.pagination.countable not in [true, :by_default]) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :count?) || Entity.anno(view),
        path: [:views, :view, name, :count?],
        why:
          "view declares `count? true` but action #{inspect(name)} on #{inspect(resource)} " <>
            "is not countable",
        fix:
          "add `countable true` to the action's `pagination` block on #{inspect(resource)}, " <>
            "or drop `count?` and let the strategy's default stand"
      )
    end
  end

  defp validate_count_supported(_view, _name, _action, _resource, _module), do: :ok

  defp validate_pagination_supported(%View{pagination: nil}, _name, _action, _resource, _module),
    do: :ok

  defp validate_pagination_supported(
         %View{pagination: :none},
         _name,
         _action,
         _resource,
         _module
       ),
       do: :ok

  defp validate_pagination_supported(
         %View{pagination: type} = view,
         name,
         action,
         resource,
         module
       ) do
    supported? =
      case {type, action.pagination} do
        {_type, pagination} when pagination in [nil, false] -> false
        {:keyset, pagination} -> pagination.keyset?
        {:offset, pagination} -> pagination.offset?
      end

    if !supported? do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :pagination) || Entity.anno(view),
        path: [:views, :view, name, :pagination],
        why:
          "view declares `pagination #{inspect(type)}` but action #{inspect(name)} on " <>
            "#{inspect(resource)} does not support it",
        fix:
          "add `#{type}? true` to the action's `pagination` block on #{inspect(resource)}, " <>
            "or declare a strategy it already supports"
      )
    end
  end

  defp validate_no_duplicate_columns(%View{columns: columns} = view, module) do
    case find_duplicate(columns, & &1.name) do
      nil ->
        :ok

      duplicate ->
        Error.raise!(
          module: module,
          location: Entity.anno(duplicate),
          path: [:views, :view, hd(view.name), :column, duplicate.name],
          why: "column #{inspect(duplicate.name)} is already defined"
        )
    end

    case find_duplicate(columns, &PyroManiac.Content.text(&1.label)) do
      nil ->
        :ok

      duplicate ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(duplicate, :label) || Entity.anno(duplicate),
          path: [:views, :view, hd(view.name), :column, duplicate.name],
          why:
            "another column already uses the label " <>
              inspect(PyroManiac.Content.text(duplicate.label))
        )
    end
  end

  defp validate_all_columns_valid(%View{columns: columns} = view, resource, module) do
    for %Column{} = column <- columns do
      {name, path} = List.pop_at(column.source, -1)
      source_resource = PyroManiac.Info.resource_by_path(resource, path)
      field = Resource.Info.field(source_resource, name)

      if !field do
        Error.raise!(
          module: module,
          location: Entity.property_anno(column, :source) || Entity.anno(column),
          path: [:views, :view, hd(view.name), :column, column.name],
          why:
            "column #{inspect(column.name)} source #{inspect(path)} -> #{inspect(name)} " <>
              "does not exist on #{inspect(source_resource)}",
          suggestions: source_attr_suggestions(name, source_resource)
        )
      end

      if !field.public? do
        Error.raise!(
          module: module,
          location: Entity.property_anno(column, :source) || Entity.anno(column),
          path: [:views, :view, hd(view.name), :column, column.name],
          why:
            "column #{inspect(column.name)} source #{inspect(path)} -> #{inspect(name)} " <>
              "is not public on #{inspect(source_resource)}",
          fix: "mark the field public on #{inspect(source_resource)}, or pick a different source"
        )
      end
    end
  end

  # Each exposed field of the read actions of the view is a column, or it is
  # excluded. Refer to `PyroManiac.Resource.Expose`.
  defp validate_all_exposed_included(
         %View{columns: columns, exclude: exclude} = view,
         resource,
         module
       ) do
    excluded = MapSet.new(exclude || [])

    root = for %Column{source: [key]} <- columns, into: excluded, do: key

    # A column traversing a relationship shows it.
    nested = for %Column{source: [head | _]} <- columns, into: excluded, do: head

    for name <- exposed_fields(view, resource) do
      {kind, shown} =
        if Resource.Info.relationship(resource, name),
          do: {:relationship, nested},
          else: {:field, root}

      if !MapSet.member?(shown, name), do: raise_not_included(view, name, kind, module)
    end
  end

  defp raise_not_included(view, name, :relationship, module) do
    Error.raise!(
      module: module,
      location: Entity.anno(view),
      path: [:views, :view, hd(view.name)],
      why: "exposed relationship #{inspect(name)} is not a defined or excluded column",
      fix: "either add a column traversing #{inspect(name)}, or list it in `exclude([...])`"
    )
  end

  defp raise_not_included(view, name, :field, module) do
    Error.raise!(
      module: module,
      location: Entity.anno(view),
      path: [:views, :view, hd(view.name)],
      why: "exposed field #{inspect(name)} is not a defined or excluded column",
      fix: "either add `column #{inspect(name)}` or list it in `exclude([...])`"
    )
  end

  # The first field of each path of the exposed loads of the read actions of
  # the view.
  defp exposed_fields(%View{name: names}, resource) do
    names
    |> List.wrap()
    |> Enum.flat_map(fn name ->
      case PyroManiac.Resource.Info.exposed(resource, name) do
        nil -> []
        expose -> PyroManiac.Surface.top_level(expose.loads)
      end
    end)
    |> Enum.uniq()
  end

  defp validate_default_displays_valid(%View{default_display: nil}, _module), do: :ok

  defp validate_default_displays_valid(%View{default_display: []} = view, module) do
    Error.raise!(
      module: module,
      location: Entity.property_anno(view, :default_display) || Entity.anno(view),
      path: [:views, :view, hd(view.name), :default_display],
      why: "must display at least one column by default",
      fix: "list at least one column name, e.g. `default_display([:name, :status])`"
    )
  end

  defp validate_default_displays_valid(
         %View{columns: columns, default_display: display} = view,
         module
       ) do
    column_names = MapSet.new(columns, & &1.name)
    column_name_list = Enum.map(columns, & &1.name)

    for col <- display, not MapSet.member?(column_names, col) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :default_display) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :default_display],
        why: "#{inspect(col)} is an undefined or excluded column",
        suggestions: Error.did_you_mean(col, column_name_list)
      )
    end
  end

  defp validate_default_sorts_valid(%View{default_sort: nil}, _resource, _module), do: :ok

  defp validate_default_sorts_valid(%View{default_sort: default_sort} = view, resource, module) do
    location = Entity.property_anno(view, :default_sort) || Entity.anno(view)

    # The rank of a user-defined order (`PyroManiac.Ordering`) is the order
    # of the records, shown or not.
    columns =
      view.columns
      |> MapSet.new(&List.wrap(&1.source))
      |> MapSet.union(rank_keys(resource))

    case Ash.Sort.parse_input(resource, default_sort) do
      {:ok, []} ->
        Error.raise!(
          module: module,
          location: location,
          path: [:views, :view, hd(view.name), :default_sort],
          why: "#{inspect(default_sort)}: must sort on at least one column"
        )

      {:ok, sort} when is_list(sort) ->
        column_source_keys =
          view.columns
          |> Enum.map(&List.wrap(&1.source))
          |> Enum.filter(&match?([_], &1))
          |> Enum.map(&hd/1)

        for sort_key <- flatten_sort(sort), !MapSet.member?(columns, sort_key) do
          raise_unknown_sort_key(sort_key, column_source_keys, view, module, location)
        end

      {:error, error} ->
        Error.raise!(
          module: module,
          location: location,
          path: [:views, :view, hd(view.name), :default_sort],
          why:
            "#{inspect(default_sort)} is an invalid Ash sort.\n\n" <>
              Ash.Error.error_descriptions(error)
        )
    end
  end

  defp rank_keys(resource) do
    case PyroManiac.Ordering.Info.ordering(resource) do
      %{attribute: attribute} -> MapSet.new([[attribute]])
      _ -> MapSet.new()
    end
  end

  @spec raise_unknown_sort_key(term(), [atom()], View.t(), module(), :erl_anno.anno() | nil) ::
          no_return()
  defp raise_unknown_sort_key(sort_key, column_source_keys, view, module, location) do
    suggestions = sort_key_suggestions(sort_key, column_source_keys)

    Error.raise!(
      module: module,
      location: location,
      path: [:views, :view, hd(view.name), :default_sort],
      why: "key #{inspect(sort_key)} is an undefined or excluded column",
      suggestions: suggestions
    )
  end

  defp sort_key_suggestions([single], candidates),
    do: Error.did_you_mean(single, candidates)

  defp sort_key_suggestions(_, _), do: []

  defp flatten_sort(sort, acc \\ [], path \\ []) do
    Enum.reduce(sort, acc, fn
      {key, nested}, acc when is_list(nested) ->
        flatten_sort(nested, acc, path ++ [key])

      {key, direction}, acc when is_atom(direction) ->
        [path ++ [key] | acc]
    end)
  end

  defp find_duplicate(entities, key_fn) do
    result =
      Enum.reduce_while(entities, MapSet.new(), fn entity, seen ->
        key = key_fn.(entity)

        if MapSet.member?(seen, key) do
          {:halt, entity}
        else
          {:cont, MapSet.put(seen, key)}
        end
      end)

    case result do
      %MapSet{} -> nil
      duplicate -> duplicate
    end
  end

  defp date_attribute_names(resource) do
    resource
    |> Resource.Info.public_attributes()
    |> Enum.filter(&date_type?/1)
    |> Enum.map(& &1.name)
  end

  defp date_type?(%{type: type}) do
    type in [
      Ash.Type.Date,
      Ash.Type.DateTime,
      Ash.Type.UtcDatetime,
      Ash.Type.UtcDatetimeUsec,
      Ash.Type.NaiveDatetime
    ]
  end

  defp read_action_suggestions(name, resource) do
    candidates =
      resource
      |> Resource.Info.actions()
      |> Enum.filter(&(&1.type == :read))
      |> Enum.map(& &1.name)

    Error.did_you_mean(name, candidates)
  end

  defp source_attr_suggestions(name, source_resource) do
    candidates =
      Enum.map(Resource.Info.public_attributes(source_resource), & &1.name) ++
        Enum.map(Resource.Info.public_calculations(source_resource), & &1.name) ++
        Enum.map(Resource.Info.public_aggregates(source_resource), & &1.name) ++
        Enum.map(Resource.Info.public_relationships(source_resource), & &1.name)

    Error.did_you_mean(name, candidates)
  end
end
