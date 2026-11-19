defmodule PyroManiac.Dsl.Transformers.ExpandFormActions do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Dsl.Expression
  alias PyroManiac.Dsl.FieldResolver

  alias PyroManiac.Form.{Action, BulkAction, Compound, Field, Group, Row, Step, Tree}

  @ash_resource_transformers Resource.Dsl.transformers()

  @impl true
  def after?(module) when module in @ash_resource_transformers, do: true

  @impl true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    if [] == Transformer.get_entities(dsl, [:forms]) do
      {:ok, dsl}
    else
      {:ok, expand_form_actions(dsl)}
    end
  end

  defp expand_form_actions(dsl) do
    context = %{
      default_description: Transformer.get_option(dsl, [:forms], :description, nil),
      dsl: dsl,
      excluded_actions: Transformer.get_option(dsl, [:forms], :exclude, []),
      path_root: [:forms],
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
    validate_action_not_excluded!(name, action, context, location)

    action_resource = action.resource || context.resource

    action =
      action
      |> Map.put(:label, action.label || default_label(name))
      |> expand_action_description(context)

    if delegated? do
      action
    else
      action
      |> Map.put(:fields, expand_fields(action.fields, action_resource))
      |> resolve_entities(action_resource, name, context)
    end
  end

  defp lookup_action!(%Action{resource: resource} = action, name, context, location)
       when not is_nil(resource) and resource != nil do
    if resource != context.resource do
      Resource.Info.action(resource, name) ||
        Error.raise!(
          module: context.module,
          location: location,
          path: [:forms, :action, name],
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
        path: [:forms, :action, name],
        why: "action #{inspect(name)} not found in resource #{inspect(context.resource)}",
        suggestions: action_name_suggestions(name, context.resource_actions, [:create, :update])
      )
  end

  defp validate_action_type!(%{type: type}, _name, _action, _context, _location)
       when type in [:create, :update],
       do: :ok

  defp validate_action_type!(%{type: type}, name, _action, context, location) do
    Error.raise!(
      module: context.module,
      location: location,
      path: [:forms, :action, name],
      why: "action #{inspect(name)} is an unsupported type: #{inspect(type)}",
      fix: "form actions must reference a create or update action; pick a different action"
    )
  end

  defp validate_action_not_excluded!(name, _action, context, location) do
    if name in context.excluded_actions do
      Error.raise!(
        module: context.module,
        location: location,
        path: [:forms, :action, name],
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
          path: [:forms, :bulk_action, name],
          why: "bulk_action #{inspect(name)} not found in resource #{inspect(context.resource)}",
          suggestions:
            action_name_suggestions(name, context.resource_actions, [:update, :destroy])
        )

    if resource_action.type not in [:update, :destroy] do
      Error.raise!(
        module: context.module,
        location: location,
        path: [:forms, :bulk_action, name],
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

    if delegated? do
      ba
    else
      ba
      |> Map.put(:fields, expand_fields(ba.fields, context.resource))
      |> resolve_entities(context.resource, name, context)
    end
  end

  defp expand_bulk_action_description(ba, context) do
    description = Map.get(ba, :description, context.default_description)

    description =
      if description == :inherit do
        resource_action = Map.get(context.resource_actions, ba.name)
        Map.get(resource_action, :description)
      else
        description
      end

    Map.put(ba, :description, description)
  end

  # Sets `__full_path__`, the default labels, and the inherited descriptions.
  defp expand_fields(fields, resource) do
    Tree.map_down(fields, [], fn
      %Step{} = step, root ->
        full = maybe_append_path(root, step.path)

        {%{step | __full_path__: full, label: step.label || default_label(step)}, full}

      %Group{} = group, root ->
        full = maybe_append_path(root, group.path)

        {%{group | __full_path__: full, label: group.label || group_default_label(full)}, full}

      %module{} = layout, root when module in [Row, Compound] ->
        {%{layout | __full_path__: root}, root}

      input, root ->
        full = maybe_append_path(root, input.path)

        input =
          %{input | __full_path__: full, label: input.label || default_label(input)}
          |> expand_input_description(resource)

        {input, full}
    end)
  end

  defp group_default_label([]), do: nil
  defp group_default_label(path), do: default_label(List.last(path))

  defp expand_action_description(action, context) do
    description = Map.get(action, :description, context.default_description)

    description =
      if description == :inherit do
        Map.get(context.resource_action, :description)
      else
        description
      end

    Map.put(action, :description, description)
  end

  defp expand_input_description(%{description: :inherit} = input, resource) do
    description =
      case resource
           |> PyroManiac.Info.resource_by_path(input.__full_path__)
           |> Resource.Info.field(input.name) do
        nil -> nil
        field -> Map.get(field, :description)
      end

    %{input | description: description}
  end

  defp expand_input_description(input, _resource), do: input

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
      if Tree.input?(entity),
        do: FieldResolver.resolve(entity, resource, action_name, context),
        else: entity

    resolve_visibility(entity, resource, action_name, context)
  end

  defp resolve_visibility(%{visible?: nil} = entity, _resource, _action_name, _context),
    do: entity

  defp resolve_visibility(%{visible?: condition} = entity, resource, action_name, context) do
    if is_function(condition) do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(entity, :visible?) || Entity.anno(entity),
        path: [:forms, :action, action_name],
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
          path: [:forms, :action, action_name],
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
        path: [:forms, :action, action_name],
        why:
          "the `visible?` expression uses `^arg(#{inspect(arg)})`, which is not an argument of #{inspect(action_name)}",
        suggestions: Error.did_you_mean(arg, arguments)
      )
    end
  end

  # The level at which a `visible?` is evaluated. A group with a `path` shows or
  # hides all its rows, so its level is the level that contains it. The
  # level of the other entities is their full path.
  defp visibility_level(%Group{path: [_ | _] = path, __full_path__: full_path}),
    do: Enum.drop(full_path, -length(path))

  defp visibility_level(entity), do: entity.__full_path__

  # Validation -----------------------------------------------------------------

  defp validate(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    resource = Transformer.get_persisted(dsl, :resource, nil)
    excluded_actions = Transformer.get_option(dsl, [:forms], :exclude, [])

    actions = for %Action{} = action <- Transformer.get_entities(dsl, [:forms]), do: action
    bulk_actions = for %BulkAction{} = ba <- Transformer.get_entities(dsl, [:forms]), do: ba

    validate_all_actions_defined(dsl, actions, excluded_actions, module)
    validate_no_duplicate_actions(actions, module)

    for action <- actions do
      action_resource = action.resource || resource

      validate_steps_or_fields(action, module)
      validate_unique_step_names(action, module)
      validate_review_step_position(action, module)
      validate_exactly_one_autofocus(action, module)
      validate_no_duplicate_fields(action, module)
      validate_no_duplicate_field_labels(action, module)
      validate_all_fields_in_action(action, action_resource, module)
      validate_all_accepted_included(action, action_resource, module)
      validate_all_arguments_included(action, action_resource, module)
      validate_attachment_upload_declared(action, action_resource, module)
      validate_layout(action, [:forms, :action, action.name], module)
    end

    for ba <- bulk_actions do
      validate_layout(ba, [:forms, :bulk_action, ba.name], module)
    end

    validate_bulk_actions_valid(bulk_actions, resource, module)
    validate_bulk_action_no_identities(bulk_actions, resource, module)

    :ok
  end

  defp validate_all_actions_defined(dsl, actions, excluded_actions, module) do
    primary_actions = Enum.filter(actions, &is_nil(&1.resource))
    defined_names = MapSet.new(primary_actions, & &1.name)
    resource = Transformer.get_persisted(dsl, :resource, nil)
    storage_action_names = ash_storage_action_names(resource)

    missing =
      dsl
      |> get_resource_actions()
      |> Enum.filter(fn ra ->
        ra.type in [:create, :update] &&
          ra.name not in excluded_actions &&
          ra.name not in storage_action_names &&
          !MapSet.member?(defined_names, ra.name)
      end)
      |> Enum.map(& &1.name)

    if missing != [] do
      Error.raise!(
        module: module,
        location: Transformer.get_section_anno(dsl, [:forms]),
        path: [:forms],
        why:
          "the following :create/:update actions are not defined or excluded: #{inspect(missing)}",
        fix: "either define `action` blocks for these actions, or add them to `exclude([...])`"
      )
    end
  end

  defp validate_no_duplicate_actions(actions, module) do
    actions
    |> Enum.group_by(& &1.resource)
    |> Enum.each(fn {_resource, group} -> raise_if_duplicate_action_name(group, module) end)

    case find_duplicate(actions, & &1.label) do
      nil ->
        :ok

      duplicate ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(duplicate, :label) || Entity.anno(duplicate),
          path: [:forms, :action, duplicate.name],
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
          path: [:forms, :action, duplicate.name],
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
        path: [:forms, :action, action.name],
        why: "action must have either steps or inputs and groups at the top level, not both",
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
          path: [:forms, :action, action.name, :step, duplicate.name],
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
          path: [:forms, :action, action.name, :step, step.name],
          why: "step #{inspect(step.name)} has review? true but is not the last step",
          fix: "move the review step to the end, or remove `review? true`"
        )
      end
    end
  end

  defp validate_exactly_one_autofocus(action, module) do
    count = action.fields |> Tree.inputs() |> Enum.count(& &1.autofocus)

    if count != 1 do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:forms, :action, action.name],
        why: "exactly one field must have autofocus",
        fix: "add `autofocus: true` to exactly one field in this action"
      )
    end
  end

  defp validate_no_duplicate_fields(action, module) do
    keys =
      action.fields
      |> Tree.inputs()
      |> Enum.map(fn input -> {input_key(input), input} end)

    case find_duplicate(keys, &elem(&1, 0)) do
      nil ->
        :ok

      {key, duplicate} ->
        Error.raise!(
          module: module,
          location: Entity.anno(duplicate),
          path: [:forms, :action, action.name],
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
    labels = collect_labels(action.fields, nil)

    case find_duplicate(labels, &elem(&1, 0)) do
      nil ->
        :ok

      {key, duplicate} ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(duplicate, :label) || Entity.anno(duplicate),
          path: [:forms, :action, action.name],
          why: "another field already uses the label #{key}"
        )
    end
  end

  defp collect_labels(entities, compound_label) do
    Enum.flat_map(entities, fn
      %Group{label: label} = group ->
        [{label_key(label, group.__full_path__), group} | collect_labels(group.fields, nil)]

      %Compound{label: label} = compound ->
        [
          {label_key(label, compound.__full_path__), compound}
          | collect_labels(compound.fields, label)
        ]

      entity ->
        cond do
          Tree.input?(entity) and compound_label ->
            [{label_key("#{compound_label}, #{entity.label}", entity.__full_path__), entity}]

          Tree.input?(entity) ->
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
    inputs = resource_action.accept ++ Enum.map(resource_action.arguments, & &1.name)
    inputs_set = MapSet.new(inputs)

    for {field_name, field_struct} <- action_input_entities(action.fields),
        not MapSet.member?(inputs_set, field_name) do
      Error.raise!(
        module: module,
        location: Entity.anno(field_struct),
        path: [:forms, :action, action.name, :field, field_name],
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

      %module{__full_path__: [name | _]} = entity when module in [Group, Step] ->
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

  defp validate_all_accepted_included(action, action_resource, module) do
    fields = action.fields |> action_input_entities() |> MapSet.new(&elem(&1, 0))
    set_names = collect_set_names(action.sets)

    for accept <- Ash.Resource.Info.action(action_resource, action.name).accept,
        not MapSet.member?(fields, accept),
        not MapSet.member?(set_names, accept) do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:forms, :action, action.name],
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
        path: [:forms, :action, action.name],
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
        path: [:forms, :action, action.name],
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

  defp ash_storage_action_names(nil), do: []

  defp ash_storage_action_names(resource) do
    Enum.flat_map(attachment_names(resource), fn name ->
      [:"attach_#{name}", :"detach_#{name}", :"purge_#{name}"]
    end)
  end

  defp attachment_field_names(fields) do
    for %Field{type: :attachment, name: name} <- Tree.inputs(fields), do: name
  end

  # The rules of section 4.4 of the plan for `row`, `compound`, and `group`.
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

  defp validate_layout_entity(%Group{collapsed?: true, collapsible?: false} = group, path, module) do
    Error.raise!(
      module: module,
      location: Entity.property_anno(group, :collapsed?) || Entity.anno(group),
      path: path ++ [:group, group.label],
      why: "group #{inspect(group.label)} has `collapsed? true` but not `collapsible? true`",
      fix: "add `collapsible? true`"
    )
  end

  defp validate_layout_entity(%Group{collapsed?: true} = group, path, module) do
    if Enum.any?(Tree.inputs(group.fields), & &1.autofocus) do
      Error.raise!(
        module: module,
        location: Entity.anno(group),
        path: path ++ [:group, group.label],
        why:
          "group #{inspect(group.label)} starts closed, but it contains the input with " <>
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
          path: [:forms, :bulk_action, bulk_action.name],
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
          path: [:forms, :bulk_action, bulk_action.name],
          why:
            "bulk_action #{inspect(bulk_action.name)} must reference an update or destroy " <>
              "action, got #{inspect(resource_action.type)}",
          fix: "pick an update or destroy action, or change the action's type"
        )
      end
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
        path: [:forms, :bulk_action, bulk_action.name, :field, input.name],
        why:
          "bulk_action #{inspect(bulk_action.name)} includes identity field " <>
            "#{inspect(input.name)}, which is not allowed",
        fix:
          "remove the field — bulk actions cannot mutate identity attributes since they " <>
            "must remain consistent across selected rows"
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
        path: [:forms, :action, name],
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
          path: [:forms, :action, name],
          why: "#{inspect(target)} has no form action #{inspect(name)}",
          suggestions: Error.did_you_mean(name, Enum.map(target_actions, & &1.name))
        )

    %{
      action
      | max_columns: action.max_columns || source.max_columns,
        description: action.description || source.description,
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
        path: [:forms, :bulk_action, name],
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
          path: [:forms, :bulk_action, name],
          why: "#{inspect(target)} has no bulk action #{inspect(name)}",
          suggestions: Error.did_you_mean(name, Enum.map(target_bulk_actions, & &1.name))
        )

    %{
      ba
      | max_columns: ba.max_columns || source.max_columns,
        description: ba.description || source.description,
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
