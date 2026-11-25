defmodule PyroManiac.Dsl.Transformers.ExpandFormActions do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Dsl.Expression
  alias PyroManiac.Dsl.FieldResolver

  alias PyroManiac.Form.{
    Action,
    Attachments,
    BulkAction,
    Combobox,
    Compound,
    Field,
    Input,
    Related,
    Row,
    Section,
    Select,
    Step,
    Tab,
    Tabs,
    Tree,
    Workflow
  }

  @ash_resource_transformers Resource.Dsl.transformers()

  @impl true
  def after?(module) when module in @ash_resource_transformers, do: true
  def after?(PyroManiac.Dsl.Transformers.LiftViewActions), do: true

  @impl true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    dsl =
      if [] == Transformer.get_entities(dsl, [:forms]),
        do: dsl,
        else: expand_form_actions(dsl)

    {:ok, resolve_view_trees(dsl)}
  end

  defp expand_form_actions(dsl) do
    context = %{
      default_description: nil,
      dsl: dsl,
      excluded_actions: Transformer.get_option(dsl, [:page], :exclude, []),
      path_root: [:view],
      module: Transformer.get_persisted(dsl, :module, nil),
      resource: Transformer.get_persisted(dsl, :resource, nil),
      resource_actions: get_resource_actions(dsl) |> Enum.reduce(%{}, &Map.put(&2, &1.name, &1))
    }

    actions =
      for %Action{name: names} = action <-
            Transformer.get_entities(dsl, [:forms]),
          name <- names do
        %{action | name: name}
        |> expand_action(context)
      end

    bulk_actions =
      for %BulkAction{name: names} = ba <-
            Transformer.get_entities(dsl, [:forms]),
          name <- names do
        %{ba | name: name}
        |> expand_bulk_action(context)
      end

    dsl =
      Transformer.remove_entity(dsl, [:forms], fn
        %Action{} -> true
        %BulkAction{} -> true
        _ -> false
      end)

    dsl =
      Enum.reduce(actions, dsl, fn action, dsl ->
        Transformer.add_entity(dsl, [:forms], action, prepend: true)
      end)

    dsl =
      Enum.reduce(bulk_actions, dsl, fn ba, dsl ->
        Transformer.add_entity(dsl, [:forms], ba, prepend: true)
      end)

    validate(dsl)

    dsl
  end

  defp expand_action(%Action{name: name} = action, context) do
    delegated? = action.delegate_to != nil
    action = maybe_resolve_action_delegation(action, context)
    location = Entity.anno(action)

    resource_action = lookup_action!(action, name, context, location)
    validate_action_type!(resource_action, name, action, context, location)

    if is_nil(action.resource) or action.resource == context.resource,
      do: validate_action_not_excluded!(name, action, context, location)

    action_resource = action.resource || context.resource

    action =
      action
      |> Map.put(:label, action.label || default_label(name))
      |> expand_action_description(resource_action)

    action =
      if delegated? do
        action
      else
        action
        |> Map.put(:fields, expand_fields(action.fields, action_resource))
        |> Map.update!(:fields, &mark_read_only(&1, action_resource, resource_action))
        |> resolve_entities(action_resource, name, context)
      end

    resolve_confirm(action, action_resource, context)
  end

  defp form_kind(%BulkAction{}), do: :bulk_action
  defp form_kind(_action), do: :action

  # `confirm`: a text, or an expression of the record that gives a message
  # or `nil`. Its refs are loaded with the record.
  defp resolve_confirm(%{confirm: nil} = action, _resource, _context), do: action
  defp resolve_confirm(%{confirm: false} = action, _resource, _context), do: action

  defp resolve_confirm(%{confirm: text} = action, _resource, _context) when is_binary(text),
    do: action

  defp resolve_confirm(%{confirm: confirm} = action, resource, context) do
    case is_atom(confirm) or is_function(confirm) or
           PyroManiac.Dsl.Expression.validate_refs(resource, confirm, in_memory_only?: false) do
      {:ok, names} ->
        %{action | __confirm_refs__: names}

      result ->
        why =
          case result do
            {:error, message} -> "the `confirm` expression is invalid: #{message}"
            _ -> "`confirm` is a text or an Ash expression, not #{inspect(confirm)}"
          end

        Error.raise!(
          module: context.module,
          location: Entity.property_anno(action, :confirm) || Entity.anno(action),
          path: [:view, form_kind(action), action.name, :confirm],
          why: why,
          fix:
            "use for example `confirm \"Delete?\"`, `confirm expr(if count > 0, do: \"Delete?\")`, " <>
              "or `confirm false` (no confirmation)"
        )
    end
  end

  defp lookup_action!(%Action{resource: resource} = action, name, context, location)
       when not is_nil(resource) and resource != nil do
    if resource != context.resource do
      Resource.Info.action(resource, name) ||
        Error.raise!(
          module: context.module,
          location: location,
          path: [:view, :action, name],
          why: "action #{inspect(name)} not found in resource #{inspect(resource)}",
          suggestions: action_name_suggestions(name, resource, [:create, :update])
        )

      Resource.Info.action(resource, name)
    else
      lookup_local_action!(name, action, context, location)
    end
  end

  defp lookup_action!(_action, name, context, location),
    do: lookup_local_action!(name, nil, context, location)

  defp lookup_local_action!(name, _action, context, location) do
    Map.get(context.resource_actions, name) ||
      Error.raise!(
        module: context.module,
        location: location,
        path: [:view, :action, name],
        why: "action #{inspect(name)} not found in resource #{inspect(context.resource)}",
        suggestions: action_name_suggestions(name, context.resource_actions, [:create, :update])
      )
  end

  defp validate_action_type!(%{type: type}, _name, _action, _context, _location)
       when type in [:create, :update, :destroy, :action],
       do: :ok

  defp validate_action_type!(%{type: type}, name, _action, context, location) do
    Error.raise!(
      module: context.module,
      location: location,
      path: [:view, :action, name],
      why: "action #{inspect(name)} is an unsupported type: #{inspect(type)}",
      fix: "name a create, update, destroy, or generic action"
    )
  end

  defp validate_action_not_excluded!(name, _action, context, location) do
    if name in context.excluded_actions do
      Error.raise!(
        module: context.module,
        location: location,
        path: [:view, :action, name],
        why: "action #{inspect(name)} is listed in exclude",
        fix:
          "either remove #{inspect(name)} from `exclude([...])`, or remove this `action #{inspect(name)}` block"
      )
    end
  end

  defp expand_bulk_action(%BulkAction{name: name} = ba, context) do
    delegated? = ba.delegate_to != nil
    ba = maybe_resolve_bulk_action_delegation(ba, context)
    location = Entity.anno(ba)

    resource_action =
      Map.get(context.resource_actions, name) ||
        Error.raise!(
          module: context.module,
          location: location,
          path: [:view, :bulk_action, name],
          why: "bulk_action #{inspect(name)} not found in resource #{inspect(context.resource)}",
          suggestions:
            action_name_suggestions(name, context.resource_actions, [:update, :destroy])
        )

    if resource_action.type not in [:update, :destroy] do
      Error.raise!(
        module: context.module,
        location: location,
        path: [:view, :bulk_action, name],
        why:
          "bulk_action #{inspect(name)} must reference an update or destroy action, " <>
            "got #{inspect(resource_action.type)}",
        fix: "pick an update or destroy action, or change the action's type"
      )
    end

    ba =
      ba
      |> Map.put(:label, ba.label || default_label(name))
      |> expand_bulk_action_description(context)

    ba =
      if delegated? do
        ba
      else
        ba
        |> Map.put(:fields, expand_fields(ba.fields, context.resource))
        |> resolve_entities(context.resource, name, context)
      end

    resolve_confirm(ba, context.resource, context)
  end

  defp expand_bulk_action_description(ba, context) do
    resource_action = Map.get(context.resource_actions, ba.name)
    %{ba | description: inherit_description(ba.description, resource_action)}
  end

  # `description :inherit`: the description of the action, attribute, or
  # argument, as a text (or none).
  defp inherit_description(entries, source) do
    Enum.flat_map(entries || [], fn
      %PyroManiac.Description{kind: :inherit} = entry ->
        case source && Map.get(source, :description) do
          text when is_binary(text) -> [%{entry | kind: :text, implementation: text}]
          _none -> []
        end

      entry ->
        [entry]
    end)
  end

  # Sets `__full_path__`, the default labels, and the inherited descriptions.
  defp expand_fields(fields, resource) do
    Tree.map_down(fields, [], fn
      %Step{} = step, root ->
        full = maybe_append_path(root, step.path)

        {%{step | __full_path__: full, label: step.label || default_label(step)}, full}

      %Section{} = section, root ->
        full = maybe_append_path(root, section.path)

        {%{section | __full_path__: full, label: section.label || group_default_label(full)},
         full}

      %module{} = layout, root when module in [Row, Compound, Tabs] ->
        {%{layout | __full_path__: root}, root}

      %Tab{} = tab, root ->
        {%{tab | __full_path__: root, label: tab.label || default_label(tab.name)}, root}

      %module{} = leaf, root when module in [Related, Attachments] ->
        {%{leaf | __full_path__: root, label: leaf.label || default_label(leaf.name)}, root}

      %Workflow{} = workflow, root ->
        {%{workflow | __full_path__: root, label: workflow.label || "Status"}, root}

      input, root ->
        full = maybe_append_path(root, input.path)

        input =
          %{input | __full_path__: full, label: input.label || default_label(input)}
          |> expand_input_description(resource)

        {input, full}
    end)
  end

  # A `field` that is not an input of the action shows its value in both
  # modes. At the top level: a public attribute that the action does not
  # accept, a calculation, an aggregate, or a `belongs_to`/`has_one`. In a
  # nested form: a calculation, an aggregate, or a relationship of the
  # destination. Any other name stays an input, and the validation of the
  # action names the error. A `select`, `combobox`, or `input` at the top
  # level on a public attribute that the action does not accept shows its
  # value too (for example the tree of a card, the form of a transition).
  defp mark_read_only(fields, resource, resource_action) do
    inputs =
      MapSet.new(
        (Map.get(resource_action, :accept) || []) ++
          Enum.map(resource_action.arguments, & &1.name)
      )

    Tree.map(fields, fn
      %Field{type: type} = field when type in [:attachment, :nested_form] ->
        field

      %Field{__full_path__: []} = field ->
        if MapSet.member?(inputs, field.name),
          do: field,
          else: %{field | "__read_only?__": read_only_field?(resource, field.name, :top)}

      %Field{__full_path__: full_path} = field ->
        nested = PyroManiac.Info.resource_by_path(resource, full_path)
        %{field | "__read_only?__": read_only_field?(nested, field.name, :nested)}

      %module{__full_path__: []} = input when module in [Select, Combobox, Input] ->
        if MapSet.member?(inputs, input.name),
          do: input,
          else: %{input | "__read_only?__": read_only_attribute?(resource, input.name)}

      entity ->
        entity
    end)
  end

  defp read_only_attribute?(resource, name) do
    match?(%Resource.Attribute{public?: true}, Resource.Info.attribute(resource, name))
  end

  defp read_only_field?(resource, name, level) do
    case Resource.Info.field(resource, name) || Resource.Info.relationship(resource, name) do
      %Resource.Attribute{public?: public?} -> level == :top and public?
      %Resource.Calculation{public?: public?} -> public?
      %Resource.Aggregate{public?: public?} -> public?
      %Resource.Relationships.BelongsTo{public?: public?} -> public?
      %Resource.Relationships.HasOne{public?: public?} -> public?
      _ -> false
    end
  end

  defp group_default_label([]), do: nil
  defp group_default_label(path), do: default_label(List.last(path))

  defp expand_action_description(action, resource_action),
    do: %{action | description: inherit_description(action.description, resource_action)}

  defp expand_input_description(input, resource) do
    field =
      resource
      |> PyroManiac.Info.resource_by_path(input.__full_path__)
      |> Resource.Info.field(input.name)

    %{input | description: inherit_description(input.description, field)}
  end

  # Resolves each input and each `visible?`.
  defp resolve_entities(action, resource, action_name, context) do
    level_inputs =
      action.fields
      |> Tree.inputs()
      |> Enum.group_by(& &1.__full_path__, & &1.name)

    context = Map.put(context, :level_inputs, level_inputs)

    Map.update!(action, :fields, fn fields ->
      Tree.map(fields, &resolve_entity(&1, resource, action_name, context))
    end)
  end

  defp resolve_entity(entity, resource, action_name, context) do
    entity =
      cond do
        Tree.input?(entity) ->
          FieldResolver.resolve(entity, resource, action_name, context)

        # A read-only select, combobox, or input keeps its options and its label.
        Tree.read_only?(entity) and not is_struct(entity, Field) ->
          FieldResolver.resolve(entity, resource, action_name, context)

        Tree.read_only?(entity) ->
          resolve_read_only(entity, resource, context)

        is_struct(entity, Related) ->
          put_destination(entity, resource)

        is_struct(entity, Workflow) ->
          put_workflow(entity, resource)

        true ->
          entity
      end

    entity
    |> resolve_decoration(resource, context)
    |> resolve_content(resource, context)
    |> resolve_visibility(resource, action_name, context)
  end

  # The expressions of `render` and `description`, on the resource of the
  # node. Their refs are loaded with the record.
  defp resolve_content(entity, resource, context) do
    level = PyroManiac.Info.resource_by_path(resource, Map.get(entity, :__full_path__) || [])

    case PyroManiac.Content.resolve_refs(entity, level) do
      {:ok, entity} ->
        entity

      {:error, key, message} ->
        Error.raise!(
          module: context.module,
          location: Entity.anno(entity),
          path: context.path_root ++ [Map.get(entity, :name) || :node, key],
          why: "the `#{key}` expression is invalid: #{message}"
        )
    end
  end

  # The `decoration` of a field in view mode: a decoration, or an Ash expression on the
  # resource of the field. Its refs are loaded with the record.
  defp resolve_decoration(%module{decoration: decoration} = field, resource, context)
       when module in [Field, Select, Combobox, Input] and not is_nil(decoration) do
    decorations = PyroManiac.Dsl.Type.decorations()
    level = PyroManiac.Info.resource_by_path(resource, field.__full_path__)

    cond do
      decoration in decorations ->
        field

      is_atom(decoration) or is_function(decoration) ->
        decoration_error(
          field,
          context,
          "`decoration` is one of #{inspect(decorations)} or an Ash expression, not #{inspect(decoration)}",
          if(is_atom(decoration), do: Error.did_you_mean(decoration, decorations), else: [])
        )

      true ->
        resolve_tone_expression(field, level, context)
    end
  end

  defp resolve_decoration(entity, _resource, _context), do: entity

  defp resolve_tone_expression(field, level, context) do
    case Expression.validate_refs(level, field.decoration, in_memory_only?: false) do
      {:ok, names} ->
        %{field | __decoration_refs__: names}

      {:error, message} ->
        decoration_error(field, context, "the `decoration` expression is invalid: #{message}", [])
    end
  end

  defp decoration_error(field, context, why, suggestions) do
    Error.raise!(
      module: context.module,
      location: Entity.property_anno(field, :decoration) || Entity.anno(field),
      path: context.path_root ++ [field.__struct__.__entity__().name, field.name, :decoration],
      why: why,
      suggestions: suggestions
    )
  end

  defp put_workflow(%Workflow{} = workflow, resource) do
    %{
      workflow
      | __engine__: PyroManiac.Workflow.engine(resource),
        __state__: PyroManiac.Workflow.state_attribute(resource)
    }
  end

  defp put_destination(%Related{} = related, resource) do
    case Resource.Info.relationship(resource, related.name) do
      %{destination: destination} -> %{related | __destination__: destination}
      nil -> related
    end
  end

  # A read-only field has the label and the size of a value. `link_to` needs
  # a relationship: the link goes to its record.
  defp resolve_read_only(%Field{} = field, resource, context) do
    level_resource = PyroManiac.Info.resource_by_path(resource, field.__full_path__)
    relationship = Resource.Info.relationship(level_resource, field.name)

    if field.link_to != [] and is_nil(relationship) do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(field, :link_to) || Entity.anno(field),
        path: context.path_root ++ [:field, field.name, :link_to],
        why: "field #{inspect(field.name)} is not a relationship, so it has no record to link to",
        fix: "remove `link_to`, or show the relationship (for example `field :recipe`)"
      )
    end

    field
  end

  defp resolve_visibility(%{visible?: nil} = entity, _resource, _action_name, _context),
    do: entity

  defp resolve_visibility(%{visible?: condition} = entity, resource, action_name, context) do
    if is_function(condition) do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(entity, :visible?) || Entity.anno(entity),
        path: [:view, :action, action_name],
        why: "`visible?` is an Ash expression, not a function",
        fix: "use `visible? expr(...)`, for example `visible? expr(standard == true)`"
      )
    end

    level = visibility_level(entity)
    attributes = visibility_refs!(entity, condition, resource, level, action_name, context)
    args = Expression.arg_names(condition)
    if level == [], do: validate_visibility_args!(entity, args, resource, action_name, context)

    %{entity | __depends_on__: Enum.uniq(attributes ++ args)}
  end

  defp resolve_visibility(entity, _resource, _action_name, _context), do: entity

  # The refs of the expression at its level. `parent(...)` refers to the
  # level above it.
  defp visibility_refs!(entity, condition, resource, level, action_name, context) do
    level_resource = PyroManiac.Info.resource_by_path(resource, level)

    parent_resource =
      if level != [], do: PyroManiac.Info.resource_by_path(resource, Enum.drop(level, -1))

    case Expression.validate_refs(level_resource, condition,
           in_memory_only?: true,
           parent: parent_resource
         ) do
      {:ok, names} ->
        names

      {:error, message} ->
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(entity, :visible?) || Entity.anno(entity),
          path: [:view, :action, action_name],
          why: "the `visible?` expression is invalid: #{message}"
        )
    end
  end

  # `^arg(:name)` is an argument of the action (checked at the top level,
  # where the action is known).
  defp validate_visibility_args!(entity, args, resource, action_name, context) do
    arguments =
      resource
      |> Resource.Info.action(action_name)
      |> Map.get(:arguments, [])
      |> Enum.map(& &1.name)

    for arg <- args, arg not in arguments do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(entity, :visible?) || Entity.anno(entity),
        path: [:view, :action, action_name],
        why:
          "the `visible?` expression uses `^arg(#{inspect(arg)})`, which is not an argument of #{inspect(action_name)}",
        suggestions: Error.did_you_mean(arg, arguments)
      )
    end
  end

  # The level at which a `visible?` is evaluated. A section with a `path` shows or
  # hides all its rows, so its level is the level that contains it. The
  # level of the other entities is their full path.
  defp visibility_level(%Section{path: [_ | _] = path, __full_path__: full_path}),
    do: Enum.drop(full_path, -length(path))

  defp visibility_level(entity), do: entity.__full_path__

  # The record tree of each view in view mode: its nodes for the read action
  # of the view (`only`), resolved. A view that names a write action
  # resolves its inputs with the first write action of its own tree (the
  # inputs show their values); the other views have values only. A card
  # without nodes whose write action is delegated shows the delegated tree.
  defp resolve_view_trees(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    resource = Transformer.get_persisted(dsl, :resource, nil)
    entries = Transformer.get_entities(dsl, [:forms])

    context = %{
      default_description: nil,
      dsl: dsl,
      excluded_actions: [],
      path_root: [:view],
      module: module,
      resource: resource,
      resource_actions: get_resource_actions(dsl) |> Enum.reduce(%{}, &Map.put(&2, &1.name, &1))
    }

    dsl
    |> Transformer.get_entities([:views])
    |> Enum.reduce(dsl, fn view, dsl ->
      tree = view_tree(view, entries, context)
      Transformer.replace_entity(dsl, [:views], %{view | __tree__: tree}, &(&1 == view))
    end)
  end

  defp view_tree(%PyroManiac.View.View{} = view, entries, context) do
    key = {List.first(view.name), view.type}
    read = view.read_action || List.first(view.name)
    resource = view.resource || context.resource

    own = Enum.find(entries, &own_action?(&1, key, resource))

    cond do
      view.fields != [] ->
        view.fields
        |> Tree.for_action(read)
        |> expand_view_tree(view, read, own, resource, context)

      own && view.type == :card ->
        own.fields

      true ->
        []
    end
  end

  # An action of the view on its resource, with the tree of the view (not a
  # column or `edit_columns`).
  defp own_action?(
         %Action{__column__: nil, __columns__: [], __view__: key} = entry,
         key,
         resource
       ),
       do: is_nil(entry.resource) or entry.resource == resource

  defp own_action?(_entry, _key, _resource), do: false

  defp expand_view_tree(tree, view, read, own, resource, context) do
    name = List.first(view.name) || read
    context = %{context | path_root: [:view, name]}
    fields = expand_fields(tree, resource)

    fields =
      case own do
        %Action{name: write} ->
          write = write |> List.wrap() |> hd()
          mark_read_only(fields, resource, Map.fetch!(context.resource_actions, write))

        nil ->
          values_only(fields, view, context)
      end

    pseudo = %Action{name: read, fields: fields}
    validate_record_leaves(pseudo, resource, context.module)
    resolve_entities(pseudo, resource, read, context).fields
  end

  # A view without a write action shows values: each `field` is read-only,
  # and it has no other input.
  defp values_only(fields, view, context) do
    Tree.map(fields, fn
      %Field{} = field ->
        %{field | "__read_only?__": true}

      %module{} = input when module in [Select, Combobox, Input] ->
        Error.raise!(
          module: context.module,
          location: Entity.anno(input),
          path: [:view, List.first(view.name), input.name],
          why:
            "#{inspect(input.name)} is an input, but the view names no write action, so it " <>
              "shows values only",
          fix: "use `field #{inspect(input.name)}`, or name a write action in the view (`action`)"
        )

      entity ->
        entity
    end)
  end

  # Validation -----------------------------------------------------------------

  defp validate(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    resource = Transformer.get_persisted(dsl, :resource, nil)

    actions = for %Action{} = action <- Transformer.get_entities(dsl, [:forms]), do: action
    bulk_actions = for %BulkAction{} = ba <- Transformer.get_entities(dsl, [:forms]), do: ba

    validate_no_duplicate_actions(actions, module)

    for action <- actions, do: validate_action(action, action.resource || resource, module)

    for ba <- bulk_actions do
      validate_layout(ba, [:view, :bulk_action, ba.name], module)
      validate_confirm(ba, :bulk_action, module)
    end

    validate_bulk_actions_valid(bulk_actions, resource, module)
    validate_bulk_action_no_identities(bulk_actions, resource, module)
    validate_bulk_action_inputs_only(bulk_actions, module)

    :ok
  end

  defp validate_action(action, action_resource, module) do
    inline? = not is_nil(action.__column__) or action.__columns__ != []

    validate_steps_or_fields(action, module)
    validate_unique_step_names(action, module)
    validate_review_step_position(action, module)
    # An inline edit focuses its cell.
    if not inline?, do: validate_exactly_one_autofocus(action, module)
    validate_overridable_sets(action, module)
    validate_no_duplicate_fields(action, module)
    validate_no_duplicate_field_labels(action, module)
    validate_all_fields_in_action(action, action_resource, module)
    validate_inputs_included(action, action_resource, inline?, module)
    validate_attachment_upload_declared(action, action_resource, module)
    validate_layout(action, [:view, :action, action.name], module)
    validate_tabs(action, action_resource, module)
    validate_record_leaves(action, action_resource, module)
    validate_autofocus_shown(action, module)
    if not inline?, do: validate_confirm(action, :action, module)
  end

  # An action without an input runs from its button (a row, a card, the
  # selection). It asks first or not, as the page says: a renderer never
  # adds a confirmation.
  defp validate_confirm(%{confirm: nil} = action, kind, module) do
    if Tree.inputs(action.fields) == [] do
      where =
        case action do
          %BulkAction{} -> "bulk action"
          %Action{__view__: {_, :card}} -> "action of the card"
          _ -> "action"
        end

      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:view, kind, action.name],
        why: "#{where} #{inspect(action.name)} has no input, so its button runs it at once",
        fix:
          "set `confirm` on it: a text (`confirm \"#{default_label(action.name)}?\"`), " <>
            "an expression, or `confirm false` to run it without a confirmation"
      )
    end
  end

  defp validate_confirm(_action, _kind, _module), do: :ok

  # An inline edit (a column, `edit_columns`) changes some of the values,
  # with inputs only; a form has every input of the action.
  defp validate_inputs_included(action, _action_resource, true, module),
    do: validate_inline_inputs(action, module)

  defp validate_inputs_included(action, action_resource, false, module) do
    validate_all_accepted_included(action, action_resource, module)
    validate_all_arguments_included(action, action_resource, module)
  end

  defp validate_inline_inputs(action, module) do
    for value <- Tree.values(action.fields), not Tree.input?(value) do
      Error.raise!(
        module: module,
        location: Entity.anno(value),
        path: [:view, :action, action.name, :field, value.name],
        why:
          "#{inspect(value.name)} is not an input of #{inspect(action.name)}. An inline edit " <>
            "has inputs only",
        fix: "remove #{inspect(value.name)}, or name an action that accepts it"
      )
    end
  end

  defp validate_no_duplicate_actions(actions, module) do
    actions
    |> Enum.group_by(&{&1.resource, &1.__view__, &1.__column__, &1.__columns__})
    |> Enum.each(fn {_key, group} -> raise_if_duplicate_action_name(group, module) end)

    labelled = for %Action{__column__: nil, __columns__: []} = action <- actions, do: action

    labelled
    |> Enum.group_by(& &1.__view__)
    |> Enum.each(fn {_view, group} -> raise_if_duplicate_label_of(group, module) end)
  end

  defp raise_if_duplicate_label_of(actions, module) do
    case find_duplicate(actions, & &1.label) do
      nil ->
        :ok

      duplicate ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(duplicate, :label) || Entity.anno(duplicate),
          path: [:view, :action, duplicate.name],
          why: "another form action already uses the label #{inspect(duplicate.label)}"
        )
    end
  end

  defp raise_if_duplicate_action_name(actions, module) do
    case find_duplicate(actions, & &1.name) do
      nil ->
        :ok

      duplicate ->
        Error.raise!(
          module: module,
          location: Entity.anno(duplicate),
          path: [:view, :action, duplicate.name],
          why: "action #{inspect(duplicate.name)} is already defined for this resource"
        )
    end
  end

  defp validate_steps_or_fields(action, module) do
    has_steps = Enum.any?(action.fields, &is_struct(&1, Step))
    has_other = Enum.any?(action.fields, &(not is_struct(&1, Step)))

    if has_steps && has_other do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:view, :action, action.name],
        why: "action must have either steps or inputs and sections at the top level, not both",
        fix: "wrap the other entities in a `step` block, or remove the steps"
      )
    end
  end

  defp validate_unique_step_names(action, module) do
    steps = Enum.filter(action.fields, &is_struct(&1, Step))

    case find_duplicate(steps, & &1.name) do
      nil ->
        :ok

      duplicate ->
        Error.raise!(
          module: module,
          location: Entity.anno(duplicate),
          path: [:view, :action, action.name, :step, duplicate.name],
          why: "step #{inspect(duplicate.name)} is already defined"
        )
    end
  end

  defp validate_review_step_position(action, module) do
    steps = Enum.filter(action.fields, &is_struct(&1, Step))

    if steps != [] do
      last_idx = length(steps) - 1

      for {step, idx} <- Enum.with_index(steps), step.review?, idx != last_idx do
        Error.raise!(
          module: module,
          location: Entity.property_anno(step, :review?) || Entity.anno(step),
          path: [:view, :action, action.name, :step, step.name],
          why: "step #{inspect(step.name)} has review? true but is not the last step",
          fix: "move the review step to the end, or remove `review? true`"
        )
      end
    end
  end

  defp validate_exactly_one_autofocus(action, module) do
    inputs = Tree.inputs(action.fields)
    count = Enum.count(inputs, & &1.autofocus)

    if inputs != [] and count != 1 do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:view, :action, action.name],
        why: "exactly one field must have autofocus",
        fix: "add `autofocus: true` to exactly one field in this action"
      )
    end
  end

  # A value is once in the tree of an action (the tree is filtered by `only`).
  defp validate_no_duplicate_fields(action, module) do
    action.fields
    |> Tree.values()
    |> Enum.map(fn input -> {input_key(input), input} end)
    |> raise_if_duplicate_field(action, module)
  end

  defp raise_if_duplicate_field(keys, action, module) do
    case find_duplicate(keys, &elem(&1, 0)) do
      nil ->
        :ok

      {key, duplicate} ->
        Error.raise!(
          module: module,
          location: Entity.anno(duplicate),
          path: [:view, :action, action.name],
          why: "field #{key} is already defined"
        )
    end
  end

  defp input_key(%{name: name, __full_path__: []}), do: inspect(name)
  defp input_key(%{name: name, __full_path__: path}), do: Enum.join(path ++ [name], ".")

  # The labels of the parts of a compound are scoped to the compound (a
  # screen reader reads "Temperature, Unit"), so they are compared with the
  # compound label as a prefix.
  defp validate_no_duplicate_field_labels(action, module) do
    action.fields
    |> collect_labels(nil)
    |> raise_if_duplicate_label(action, module)
  end

  defp raise_if_duplicate_label(labels, action, module) do
    case find_duplicate(labels, &elem(&1, 0)) do
      nil ->
        :ok

      {key, duplicate} ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(duplicate, :label) || Entity.anno(duplicate),
          path: [:view, :action, action.name],
          why: "another field already uses the label #{key}"
        )
    end
  end

  defp collect_labels(entities, compound_label) do
    Enum.flat_map(entities, fn
      %Section{label: label} = section ->
        [{label_key(label, section.__full_path__), section} | collect_labels(section.fields, nil)]

      %module{label: label} = leaf when module in [Related, Attachments] ->
        [{label_key(label, leaf.__full_path__), leaf}]

      %Compound{label: label} = compound ->
        [
          {label_key(label, compound.__full_path__), compound}
          | collect_labels(compound.fields, label)
        ]

      entity ->
        cond do
          Tree.value?(entity) and compound_label ->
            [{label_key("#{compound_label}, #{entity.label}", entity.__full_path__), entity}]

          Tree.value?(entity) ->
            [{label_key(entity.label, entity.__full_path__), entity}]

          true ->
            collect_labels(Tree.children(entity), compound_label)
        end
    end)
  end

  defp label_key(label, []), do: inspect(label)
  defp label_key(label, path), do: inspect(path) <> " -> " <> inspect(label)

  defp validate_all_fields_in_action(action, action_resource, module) do
    resource_action = Ash.Resource.Info.action(action_resource, action.name)

    inputs =
      (Map.get(resource_action, :accept) || []) ++ Enum.map(resource_action.arguments, & &1.name)

    inputs_set = MapSet.new(inputs)

    for {field_name, field_struct} <- action_input_entities(action.fields),
        not MapSet.member?(inputs_set, field_name) do
      Error.raise!(
        module: module,
        location: Entity.anno(field_struct),
        path: [:view, :action, action.name, :field, field_name],
        why:
          "field #{inspect(field_name)} is not an accepted attribute or argument for this action",
        suggestions: Error.did_you_mean(field_name, inputs)
      )
    end
  end

  # The top-level inputs of the action, and the first segment of each nested
  # path (the argument that manages the relationship), with the entity.
  defp action_input_entities(fields) do
    fields
    |> Tree.all()
    |> Enum.flat_map(fn
      %Field{type: :attachment} ->
        []

      %module{__full_path__: [name | _]} = entity when module in [Section, Step] ->
        if entity.path != [], do: [{name, entity}], else: []

      entity ->
        cond do
          not Tree.input?(entity) ->
            []

          entity.__full_path__ == [] ->
            [{entity.name, entity}]

          entity.path != [] and length(entity.__full_path__) == length(entity.path) ->
            [{hd(entity.__full_path__), entity}]

          true ->
            []
        end
    end)
  end

  # An overridable `set` gives the first value of an input of the form.
  defp validate_overridable_sets(action, module) do
    inputs = action.fields |> Tree.inputs() |> MapSet.new(& &1.name)

    for %{overridable?: true, name: name} = set <- action.sets || [],
        not MapSet.member?(inputs, name) do
      Error.raise!(
        module: module,
        location: Entity.anno(set),
        path: [:view, :action, action.name, :set, name],
        why:
          "`set #{inspect(name)}` is overridable, so the user changes the value in an input, " <>
            "but the form has no input #{inspect(name)}",
        fix: "add an input #{inspect(name)} to the form, or remove `overridable? true`"
      )
    end
  end

  defp validate_all_accepted_included(action, action_resource, module) do
    fields = action.fields |> action_input_entities() |> MapSet.new(&elem(&1, 0))
    set_names = collect_set_names(action.sets)

    for accept <- Ash.Resource.Info.action(action_resource, action.name).accept,
        not MapSet.member?(fields, accept),
        not MapSet.member?(set_names, accept) do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:view, :action, action.name],
        why: "accepted attribute #{inspect(accept)} is not a form field",
        fix:
          "add `field #{inspect(accept)}` to this action, exclude #{inspect(accept)} from " <>
            "the action's `accept` list, or add it as a `set`"
      )
    end
  end

  defp validate_all_arguments_included(action, action_resource, module) do
    fields =
      action.fields
      |> action_input_entities()
      |> MapSet.new(&elem(&1, 0))
      |> MapSet.union(MapSet.new(attachment_field_names(action.fields)))

    set_names = collect_set_names(action.sets)

    for argument <- Ash.Resource.Info.action(action_resource, action.name).arguments,
        not MapSet.member?(fields, argument.name),
        not MapSet.member?(set_names, argument.name) do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:view, :action, action.name],
        why: "argument #{inspect(argument.name)} is not a form field",
        fix: "add `field #{inspect(argument.name)}` to this action, or set it via `set`"
      )
    end
  end

  defp collect_set_names(sets), do: MapSet.new(sets || [], & &1.name)

  defp validate_attachment_upload_declared(action, action_resource, module) do
    declared = attachment_field_names(action.fields)

    for name <- file_argument_names(action, action_resource), name not in declared do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:view, :action, action.name],
        why:
          "action #{inspect(action.name)} has a file argument :#{name} but this form does not " <>
            "declare a `type: :attachment` field for it",
        fix: "add `field :#{name}, type: :attachment` to this action"
      )
    end
  end

  defp file_argument_names(action, action_resource) do
    action_resource
    |> Ash.Resource.Info.action(action.name)
    |> Map.fetch!(:arguments)
    |> Enum.filter(&file_type?(&1.type))
    |> Enum.map(& &1.name)
  end

  defp file_type?(Ash.Type.File), do: true
  defp file_type?({:array, type}), do: file_type?(type)
  defp file_type?(_), do: false

  defp attachment_names(resource) do
    if Code.ensure_loaded?(AshStorage) and AshStorage in Spark.extensions(resource) do
      Enum.map(AshStorage.Info.attachments(resource), & &1.name)
    else
      []
    end
  end

  @doc false
  def ash_storage_action_names(nil), do: []

  def ash_storage_action_names(resource) do
    Enum.flat_map(attachment_names(resource), fn name ->
      [:"attach_#{name}", :"detach_#{name}", :"purge_#{name}"]
    end)
  end

  defp attachment_field_names(fields) do
    for %Field{type: :attachment, name: name} <- Tree.inputs(fields), do: name
  end

  # The rules of `row`, `compound`, and `section`.
  defp validate_layout(action, path, module) do
    for entity <- Tree.all(action.fields) do
      validate_layout_entity(entity, path, module)
    end
  end

  defp validate_layout_entity(%Row{fields: children} = row, path, module) do
    if length(children) < 2 do
      Error.raise!(
        module: module,
        location: Entity.anno(row),
        path: path ++ [:row],
        why: "a `row` needs at least 2 children",
        fix: "add an input to the row, or remove the `row` block"
      )
    end

    for %{size: :prose} = child <- children do
      Error.raise!(
        module: module,
        location: Entity.anno(child),
        path: path ++ [:row, child.name],
        why: "#{inspect(child.name)} has the size `:prose`, which always uses the full row",
        fix: "move it out of the `row`"
      )
    end
  end

  defp validate_layout_entity(%Compound{fields: parts, label: label} = compound, path, module) do
    if length(parts) < 2 do
      Error.raise!(
        module: module,
        location: Entity.anno(compound),
        path: path ++ [:compound, label],
        why: "compound #{inspect(label)} has fewer than 2 parts. One input is not a compound",
        fix: "add a part, or use the input without `compound`"
      )
    end

    for %{size: size} = part <- parts, size in [:phrase, :prose] do
      Error.raise!(
        module: module,
        location: Entity.anno(part),
        path: path ++ [:compound, label],
        why:
          "#{inspect(part.name)} has the size #{inspect(size)}. The parts of a compound are tiny inputs",
        fix: "set a smaller `size`, or move it out of the compound"
      )
    end
  end

  defp validate_layout_entity(
         %Section{collapsed?: true, collapsible?: false} = section,
         path,
         module
       ) do
    Error.raise!(
      module: module,
      location: Entity.property_anno(section, :collapsed?) || Entity.anno(section),
      path: path ++ [:section, section.label],
      why: "section #{inspect(section.label)} has `collapsed? true` but not `collapsible? true`",
      fix: "add `collapsible? true`"
    )
  end

  defp validate_layout_entity(%Section{collapsed?: true} = section, path, module) do
    if Enum.any?(Tree.inputs(section.fields), & &1.autofocus) do
      Error.raise!(
        module: module,
        location: Entity.anno(section),
        path: path ++ [:section, section.label],
        why:
          "section #{inspect(section.label)} starts closed, but it contains the input with " <>
            "`autofocus`. The focus would go to an input that the user cannot see",
        fix: "move `autofocus` to another input, or remove `collapsed? true`"
      )
    end
  end

  defp validate_layout_entity(_entity, _path, _module), do: :ok

  defp validate_bulk_actions_valid(bulk_actions, resource, module) do
    for bulk_action <- bulk_actions do
      resource_action = Ash.Resource.Info.action(resource, bulk_action.name)
      location = Entity.anno(bulk_action)

      if is_nil(resource_action) do
        Error.raise!(
          module: module,
          location: location,
          path: [:view, :bulk_action, bulk_action.name],
          why:
            "bulk_action #{inspect(bulk_action.name)} references an action that does not exist " <>
              "on the resource #{inspect(resource)}",
          suggestions: action_name_suggestions(bulk_action.name, resource, [:update, :destroy])
        )
      end

      if resource_action.type not in [:update, :destroy] do
        Error.raise!(
          module: module,
          location: location,
          path: [:view, :bulk_action, bulk_action.name],
          why:
            "bulk_action #{inspect(bulk_action.name)} must reference an update or destroy " <>
              "action, got #{inspect(resource_action.type)}",
          fix: "pick an update or destroy action, or change the action's type"
        )
      end
    end
  end

  # A bulk action changes many records: it has no record to show, so only
  # inputs.
  defp validate_bulk_action_inputs_only(bulk_actions, module) do
    for bulk_action <- bulk_actions,
        %leaf_module{} = leaf <- Tree.leaves(bulk_action.fields),
        leaf_module in [Related, Attachments] do
      kind = if leaf_module == Related, do: :related, else: :attachments

      Error.raise!(
        module: module,
        location: Entity.anno(leaf),
        path: [:view, :bulk_action, bulk_action.name],
        why:
          "bulk_action #{inspect(bulk_action.name)} has `#{kind} #{inspect(leaf.name)}`. " <>
            "A bulk action changes many records, so it has no record to show",
        fix: "remove it from the bulk action"
      )
    end
  end

  defp validate_bulk_action_no_identities(bulk_actions, resource, module) do
    identity_keys =
      resource
      |> Ash.Resource.Info.identities()
      |> Enum.flat_map(& &1.keys)
      |> MapSet.new()

    for bulk_action <- bulk_actions,
        input <- Tree.inputs(bulk_action.fields),
        MapSet.member?(identity_keys, input.name) do
      Error.raise!(
        module: module,
        location: Entity.anno(input) || Entity.anno(bulk_action),
        path: [:view, :bulk_action, bulk_action.name, :field, input.name],
        why:
          "bulk_action #{inspect(bulk_action.name)} includes identity field " <>
            "#{inspect(input.name)}, which is not allowed",
        fix:
          "remove the field — bulk actions cannot mutate identity attributes since they " <>
            "must remain consistent across selected rows"
      )
    end
  end

  # Tabs ---------------------------------------------------------------------

  # One `tabs`, the last node of the top level, with two or more tabs. The
  # nodes before it show on every tab.
  defp validate_tabs(action, resource, module) do
    path = [:view, :action, action.name]

    case Enum.filter(action.fields, &is_struct(&1, Tabs)) do
      [] ->
        :ok

      [tabs] ->
        validate_tabs_last(action, tabs, path, module)
        validate_tab_list(tabs, resource, path, module)

      [_, second | _] ->
        Error.raise!(
          module: module,
          location: Entity.anno(second),
          path: path ++ [:tabs],
          why: "a record has one `tabs`",
          fix: "put all the tabs in one `tabs` block"
        )
    end
  end

  defp validate_tabs_last(action, tabs, path, module) do
    if List.last(action.fields) != tabs do
      Error.raise!(
        module: module,
        location: Entity.anno(tabs),
        path: path ++ [:tabs],
        why:
          "a node is after `tabs`. The nodes before `tabs` show on every tab, and the " <>
            "other nodes are in a tab",
        fix: "move the node into a `tab`, or before `tabs`"
      )
    end
  end

  defp validate_tab_list(%Tabs{fields: tab_list} = tabs, resource, path, module) do
    if length(tab_list) < 2 do
      Error.raise!(
        module: module,
        location: Entity.anno(tabs),
        path: path ++ [:tabs],
        why: "`tabs` needs at least 2 tabs",
        fix: "add a tab, or remove `tabs` and keep the content of the tab"
      )
    end

    case find_duplicate(tab_list, & &1.name) do
      nil ->
        :ok

      duplicate ->
        Error.raise!(
          module: module,
          location: Entity.anno(duplicate),
          path: path ++ [:tabs, :tab, duplicate.name],
          why: "tab #{inspect(duplicate.name)} is already defined"
        )
    end

    for tab <- tab_list do
      validate_count(tab, resource, path ++ [:tabs, :tab, tab.name], module)
    end
  end

  # `count` is a public aggregate or calculation of the resource: the record
  # has it, so the count needs no other query.
  defp validate_count(%{count: nil}, _resource, _path, _module), do: :ok

  defp validate_count(%{count: count} = entity, resource, path, module) do
    case Resource.Info.field(resource, count) do
      %struct{public?: true} when struct in [Resource.Aggregate, Resource.Calculation] ->
        :ok

      _ ->
        candidates =
          Enum.map(
            Resource.Info.public_aggregates(resource) ++
              Resource.Info.public_calculations(resource),
            & &1.name
          )

        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :count) || Entity.anno(entity),
          path: path ++ [:count],
          why:
            "count #{inspect(count)} is not a public aggregate or calculation of " <>
              inspect(resource),
          suggestions: Error.did_you_mean(count, candidates)
        )
    end
  end

  # The input with `autofocus` shows when the form opens: not on a tab after
  # the first one.
  defp validate_autofocus_shown(action, module) do
    case Tree.tabs(action.fields) do
      %Tabs{fields: [_first | later]} ->
        for tab <- later, Enum.any?(Tree.inputs(tab.fields), & &1.autofocus) do
          Error.raise!(
            module: module,
            location: Entity.anno(tab),
            path: [:view, :action, action.name, :tabs, :tab, tab.name],
            why:
              "tab #{inspect(tab.name)} contains the input with `autofocus`, but the form " <>
                "opens on the first tab. The focus would go to an input that the user cannot see",
            fix: "move `autofocus` to an input of the first tab, or above `tabs`"
          )
        end

      _ ->
        :ok
    end
  end

  # `related` and `attachments` -----------------------------------------------

  defp validate_record_leaves(action, resource, module) do
    path = [:view, :action, action.name]

    for leaf <- Tree.leaves(action.fields), not Tree.value?(leaf) do
      validate_top_level_leaf(leaf, path, module)
      validate_record_leaf(leaf, resource, path, module)
    end
  end

  # The records of a relationship and the files are of the record, not of a
  # record of a nested form.
  defp validate_top_level_leaf(%{__full_path__: []}, _path, _module), do: :ok

  defp validate_top_level_leaf(%module{} = leaf, path, mod) do
    kind = leaf_kind(module)
    name = Map.get(leaf, :name)

    Error.raise!(
      module: mod,
      location: Entity.anno(leaf),
      path: path ++ [kind | List.wrap(name)],
      why:
        "`#{kind}#{if name, do: " #{inspect(name)}", else: ""}` is in a section with a " <>
          "`path`. It shows the #{leaf_shows(kind)} of the record, not of a related record",
      fix: "move it out of the section with the `path`"
    )
  end

  defp leaf_kind(Related), do: :related
  defp leaf_kind(Attachments), do: :attachments
  defp leaf_kind(Workflow), do: :workflow

  defp leaf_shows(:related), do: "records"
  defp leaf_shows(:attachments), do: "files"
  defp leaf_shows(:workflow), do: "workflow"

  defp validate_record_leaf(%Related{} = related, resource, path, module) do
    path = path ++ [:related, related.name]

    case Resource.Info.relationship(resource, related.name) do
      %{public?: true} ->
        :ok

      _ ->
        Error.raise!(
          module: module,
          location: Entity.anno(related),
          path: path,
          why: "#{inspect(related.name)} is not a public relationship of #{inspect(resource)}",
          suggestions:
            Error.did_you_mean(
              related.name,
              Enum.map(Resource.Info.public_relationships(resource), & &1.name)
            )
        )
    end

    if related.delegate_to && (related.fields != [] or related.limit) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(related, :delegate_to) || Entity.anno(related),
        path: path,
        why:
          "`related #{inspect(related.name)}` has `delegate_to` and fields or `limit`. " <>
            "The delegated page has its own columns and pages",
        fix: "remove `delegate_to`, or remove the fields and `limit`"
      )
    end

    validate_count(related, resource, path, module)
  end

  defp validate_record_leaf(%Workflow{} = workflow, resource, path, module) do
    if workflow.type == :badge and workflow.orientation == :vertical do
      Error.raise!(
        module: module,
        location: Entity.property_anno(workflow, :orientation) || Entity.anno(workflow),
        path: path ++ [:workflow, :orientation],
        why:
          "`orientation` is the axis of the states of `type :steps`, but this workflow is " <>
            "`type :badge` (the current state only), so it would be ignored",
        fix: "remove `orientation`, or set `type :steps`"
      )
    end

    if is_nil(PyroManiac.Workflow.engine(resource)) do
      Error.raise!(
        module: module,
        location: Entity.anno(workflow),
        path: path ++ [:workflow],
        why:
          "`workflow` shows the state machine of the record, but #{inspect(resource)} uses " <>
            "neither AshStateMachine nor AshWorkflow",
        fix: "add `AshStateMachine` (or `AshWorkflow`) to the extensions of the resource"
      )
    end

    history = workflow.history && Resource.Info.relationship(resource, workflow.history)

    if workflow.history && !match?(%{public?: true, cardinality: :many}, history) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(workflow, :history) || Entity.anno(workflow),
        path: path ++ [:workflow, :history],
        why:
          "`history #{inspect(workflow.history)}` is not a public relationship to many " <>
            "records of #{inspect(resource)}",
        fix: "name the relationship of the transition log, for example `history :transitions`"
      )
    end
  end

  defp validate_record_leaf(%Attachments{} = attachments, resource, path, module) do
    names = attachment_names(resource)

    if attachments.name not in names do
      Error.raise!(
        module: module,
        location: Entity.anno(attachments),
        path: path ++ [:attachments, attachments.name],
        why:
          "#{inspect(attachments.name)} is not an AshStorage attachment of #{inspect(resource)}",
        suggestions: Error.did_you_mean(attachments.name, names)
      )
    end
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

  defp maybe_resolve_action_delegation(%Action{delegate_to: nil} = action, _context), do: action

  defp maybe_resolve_action_delegation(%Action{delegate_to: target, name: name} = action, context) do
    location = Entity.anno(action)

    if action.fields != [] do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(action, :delegate_to) || location,
        path: [:view, :action, name],
        why: "delegate_to and inline fields are mutually exclusive",
        fix: "remove either `delegate_to` or the inline `field` entries"
      )
    end

    target_actions =
      target
      |> Spark.Dsl.Extension.get_entities([:forms])
      |> Enum.filter(&match?(%Action{}, &1))

    source =
      Enum.find(target_actions, &(&1.name == name)) ||
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(action, :delegate_to) || location,
          path: [:view, :action, name],
          why: "#{inspect(target)} has no form action #{inspect(name)}",
          suggestions: Error.did_you_mean(name, Enum.map(target_actions, & &1.name))
        )

    %{
      action
      | max_columns: action.max_columns || source.max_columns,
        description:
          if(action.description == [], do: source.description, else: action.description),
        fields: source.fields,
        label: action.label || source.label,
        sets: merge_sets(action.sets, source.sets)
    }
  end

  defp maybe_resolve_bulk_action_delegation(%BulkAction{delegate_to: nil} = ba, _context), do: ba

  defp maybe_resolve_bulk_action_delegation(
         %BulkAction{delegate_to: target, name: name} = ba,
         context
       ) do
    location = Entity.anno(ba)

    if ba.fields != [] do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(ba, :delegate_to) || location,
        path: [:view, :bulk_action, name],
        why: "delegate_to and inline fields are mutually exclusive",
        fix: "remove either `delegate_to` or the inline `field` entries"
      )
    end

    target_bulk_actions =
      target
      |> Spark.Dsl.Extension.get_entities([:forms])
      |> Enum.filter(&match?(%BulkAction{}, &1))

    source =
      Enum.find(target_bulk_actions, &(&1.name == name)) ||
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(ba, :delegate_to) || location,
          path: [:view, :bulk_action, name],
          why: "#{inspect(target)} has no bulk action #{inspect(name)}",
          suggestions: Error.did_you_mean(name, Enum.map(target_bulk_actions, & &1.name))
        )

    %{
      ba
      | max_columns: ba.max_columns || source.max_columns,
        description: if(ba.description == [], do: source.description, else: ba.description),
        fields: source.fields,
        label: ba.label || source.label
    }
  end

  defp merge_sets(local_sets, source_sets) do
    local_names = MapSet.new(local_sets || [], & &1.name)

    merged_source =
      (source_sets || [])
      |> Enum.reject(&MapSet.member?(local_names, &1.name))

    (local_sets || []) ++ merged_source
  end

  defp action_name_suggestions(name, %{} = resource_actions, types) do
    candidates =
      resource_actions
      |> Map.values()
      |> Enum.filter(&(&1.type in types))
      |> Enum.map(& &1.name)

    Error.did_you_mean(name, candidates)
  end

  defp action_name_suggestions(name, resource, types) when is_atom(resource) do
    candidates =
      resource
      |> Resource.Info.actions()
      |> Enum.filter(&(&1.type in types))
      |> Enum.map(& &1.name)

    Error.did_you_mean(name, candidates)
  end
end
