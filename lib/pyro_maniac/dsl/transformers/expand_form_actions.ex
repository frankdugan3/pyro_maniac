defmodule PyroManiac.Dsl.Transformers.ExpandFormActions do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Form.{Action, BulkAction, Field, FieldGroup, Step}
  alias PyroManiac.Info
  alias PyroManiac.TypeInfer

  @built_in_form_types ~w(
    attachment boolean checkbox combobox
    date datetime default email interval naive_datetime
    nested_form number password select text textarea time toggle
  )a

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
      default_class: Transformer.get_option(dsl, [:forms], :class, nil),
      default_description: Transformer.get_option(dsl, [:forms], :description, nil),
      dsl: dsl,
      excluded_actions: Transformer.get_option(dsl, [:forms], :exclude, []),
      extra_form_types: Transformer.get_option(dsl, [:forms], :extra_form_types, []),
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
      |> Map.put(:class, action.class || context.default_class)
      |> expand_action_description(context)

    if delegated? do
      action
    else
      action
      |> Map.put(:fields, expand_fields(action.fields, context))
      |> resolve_action_field_types(action_resource, name, context)
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
      |> Map.put(:class, ba.class || context.default_class)
      |> expand_bulk_action_description(context)

    if delegated? do
      ba
    else
      ba
      |> Map.put(:fields, expand_fields(ba.fields, context))
      |> resolve_action_field_types(context.resource, name, context)
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

  defp expand_fields(fields, context, root_path \\ []) do
    Enum.map(fields, fn
      %Step{} = step ->
        step_path = maybe_append_path(root_path, step.path)

        step
        |> Map.put(:path, step_path)
        |> Map.put(:label, step.label || default_label(step))
        |> Map.put(:fields, expand_fields(step.fields, context, step_path))

      %Field{} = field ->
        field
        |> Map.put(:path, maybe_append_path(root_path, field.path))
        |> Map.put(:label, field.label || default_label(field))
        |> expand_field_description(context)

      %FieldGroup{} = group ->
        group_path = maybe_append_path(root_path, group.path)

        group
        |> Map.put(:path, group_path)
        |> Map.put(:label, group.label || group_default_label(group_path))
        |> expand_field_description(context)
        |> Map.put(:fields, expand_fields(group.fields, context, group_path))
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

  defp expand_field_description(%{description: :inherit} = field, context) do
    description =
      context.resource
      |> PyroManiac.Info.resource_by_path(field.path)
      |> Resource.Info.field(field.name)
      |> Map.get(:description)

    Map.put(field, :description, description)
  end

  defp expand_field_description(field, _context), do: field

  defp resolve_action_field_types(action, resource, action_name, context) do
    Map.update!(action, :fields, fn fields ->
      resolve_field_types(fields, resource, action_name, context)
    end)
  end

  defp resolve_field_types(fields, resource, action_name, context) do
    Enum.map(fields, fn
      %Step{} = step ->
        Map.update!(step, :fields, &resolve_field_types(&1, resource, action_name, context))

      %FieldGroup{} = group ->
        Map.update!(
          group,
          :fields,
          &resolve_field_types(&1, resource, action_name, context)
        )

      %Field{} = field ->
        resolve_field(field, resource, action_name, context)
    end)
  end

  defp resolve_field(%Field{form_only?: true} = field, _resource, _action_name, context) do
    validate_field_type(field, context)
  end

  defp resolve_field(%Field{type: :nested_form} = field, _resource, _action_name, context) do
    validate_field_type(field, context)
  end

  defp resolve_field(%Field{type: :attachment} = field, _resource, _action_name, context) do
    validate_field_type(field, context)
  end

  defp resolve_field(field, resource, action_name, context) do
    field_resource =
      if field.path != [],
        do: Info.resource_by_path(resource, field.path),
        else: resource

    attr_info = Info.action_field_info(field_resource, action_name, field.name)
    belongs_to = belongs_to_for(field_resource, field.name)

    field =
      if attr_info do
        effective_type =
          if field.type == :default and not is_nil(belongs_to),
            do: :combobox,
            else: field.type

        resolved_type = Info.resolve_field_type(field_resource, field.name, effective_type)

        enum_opts =
          if field.options != [] do
            field.options
          else
            TypeInfer.enum_options(attr_info.type, Map.get(attr_info, :constraints, [])) || []
          end

        field
        |> Map.put(:type, resolved_type)
        |> Map.put(:enum_options, enum_opts)
        |> Map.put(:allow_nil?, Map.get(attr_info, :allow_nil?, true))
        |> Map.put(:multiple?, TypeInfer.array_enum_type?(attr_info))
        |> populate_combobox_defaults(belongs_to, context)
      else
        field
      end

    field
    |> maybe_strip_id_label(belongs_to)
    |> validate_field_type(context)
  end

  # When a field maps to a belongs_to relationship and its name ends in `_id`,
  # drop the `_id` from the auto-generated label (e.g. `:supplier_id` -> "Supplier").
  # A custom label declared in the DSL is left untouched.
  defp maybe_strip_id_label(field, nil), do: field

  defp maybe_strip_id_label(%Field{name: name, label: label} = field, _belongs_to) do
    name_str = Atom.to_string(name)

    if String.ends_with?(name_str, "_id") and label == default_label(name) do
      stripped = String.replace_suffix(name_str, "_id", "")
      Map.put(field, :label, default_label(stripped))
    else
      field
    end
  end

  defp belongs_to_for(resource, field_name) do
    Enum.find(
      Ash.Resource.Info.relationships(resource),
      &match?(%Ash.Resource.Relationships.BelongsTo{source_attribute: ^field_name}, &1)
    )
  end

  defp populate_combobox_defaults(%Field{type: :combobox} = field, %{destination: dest}, context) do
    search_action =
      field.combobox_search_action || primary_read_action_name!(dest, field, context)

    validate_search_action!(dest, search_action, field, context)

    field
    |> Map.put(:combobox_search_action, search_action)
    |> Map.put(
      :combobox_option_label_key,
      field.combobox_option_label_key ||
        PyroManiac.Resource.Info.default_label(dest) ||
        :label
    )
    |> Map.put(
      :combobox_option_value_key,
      field.combobox_option_value_key || primary_key_attr(dest)
    )
  end

  defp populate_combobox_defaults(field, _belongs_to, _context), do: field

  defp primary_read_action_name!(resource, field, context) do
    case Ash.Resource.Info.primary_action(resource, :read) do
      %{name: name} ->
        name

      _ ->
        Error.raise!(
          module: context.module,
          location: Entity.anno(field),
          path: [:forms, :field, field.name, :combobox_search_action],
          why:
            "cannot auto-populate `combobox_search_action` for #{inspect(field.name)}: " <>
              "destination resource #{inspect(resource)} has no primary `:read` action.",
          fix:
            "either declare a primary read action on #{inspect(resource)} or set " <>
              "`combobox_search_action:` explicitly on the field."
        )
    end
  end

  defp validate_search_action!(resource, action_name, field, context) do
    case Ash.Resource.Info.action(resource, action_name) do
      %{type: :read} ->
        :ok

      %{type: type} ->
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(field, :combobox_search_action) || Entity.anno(field),
          path: [:forms, :field, field.name, :combobox_search_action],
          why:
            "combobox_search_action #{inspect(action_name)} on #{inspect(resource)} is a " <>
              "#{inspect(type)} action; expected a `:read` action.",
          fix: "point `combobox_search_action:` at a read action on #{inspect(resource)}."
        )

      nil ->
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(field, :combobox_search_action) || Entity.anno(field),
          path: [:forms, :field, field.name, :combobox_search_action],
          why:
            "combobox_search_action #{inspect(action_name)} does not exist on " <>
              "#{inspect(resource)}.",
          fix:
            "point `combobox_search_action:` at an existing read action on #{inspect(resource)}."
        )
    end
  end

  defp primary_key_attr(resource) do
    case Ash.Resource.Info.primary_key(resource) do
      [pk] -> pk
      _ -> :id
    end
  end

  defp validate_field_type(%Field{type: :default} = field, _context), do: field

  defp validate_field_type(%Field{type: type} = field, context) do
    allowed = @built_in_form_types ++ context.extra_form_types

    if type not in allowed do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(field, :type) || Entity.anno(field),
        path: [:forms, :field, field.name, :type],
        why:
          "unknown field type #{inspect(type)} for field #{inspect(field.name)}. " <>
            "Accepted types: #{inspect(allowed)}",
        suggestions: Error.did_you_mean(type, allowed)
      )
    end

    field
  end

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
      validate_form_only_fields_not_in_action(action, action_resource, module)
      validate_attachment_upload_declared(action, action_resource, module)
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

    has_bare_fields =
      Enum.any?(action.fields, &(is_struct(&1, Field) || is_struct(&1, FieldGroup)))

    if has_steps && has_bare_fields do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:forms, :action, action.name],
        why:
          "action must have either steps or bare fields/field_groups at the top level, not both",
        fix: "wrap the bare fields in a `step` block, or remove the steps"
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
    if count_autofocus(action.fields) != 1 do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:forms, :action, action.name],
        why: "exactly one field must have autofocus",
        fix: "add `autofocus: true` to exactly one field in this action"
      )
    end
  end

  defp count_autofocus(fields, total \\ 0) do
    Enum.reduce(fields, total, fn
      %Step{fields: step_fields}, acc -> count_autofocus(step_fields, acc)
      %FieldGroup{fields: group_fields}, acc -> count_autofocus(group_fields, acc)
      %Field{autofocus: true}, acc -> acc + 1
      _, acc -> acc
    end)
  end

  defp validate_no_duplicate_fields(action, module) do
    fields = collect_field_keys(action.fields)

    case find_duplicate(fields, &elem(&1, 0)) do
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

  defp collect_field_keys(fields, acc \\ []) do
    Enum.reduce(fields, acc, fn
      %Step{fields: step_fields}, acc ->
        collect_field_keys(step_fields, acc)

      %FieldGroup{fields: group_fields}, acc ->
        collect_field_keys(group_fields, acc)

      %Field{name: name, path: []} = field, acc ->
        [{inspect(name), field} | acc]

      %Field{name: name, path: path} = field, acc ->
        [{Enum.join(path ++ [name], "."), field} | acc]
    end)
  end

  defp validate_no_duplicate_field_labels(action, module) do
    fields = collect_field_labels(action.fields)

    case find_duplicate(fields, &elem(&1, 0)) do
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

  defp collect_field_labels(fields, acc \\ []) do
    Enum.reduce(fields, acc, fn
      %Step{fields: step_fields}, acc ->
        collect_field_labels(step_fields, acc)

      %FieldGroup{fields: group_fields, label: label, path: path} = group, acc ->
        collect_field_labels(group_fields, [{label_key(label, path), group} | acc])

      %Field{label: label, path: path} = field, acc ->
        [{label_key(label, path), field} | acc]
    end)
  end

  defp label_key(label, []), do: inspect(label)
  defp label_key(label, path), do: inspect(path) <> " -> " <> inspect(label)

  defp validate_all_fields_in_action(action, action_resource, module) do
    resource_action = Ash.Resource.Info.action(action_resource, action.name)

    inputs =
      resource_action.accept ++ Enum.map(resource_action.arguments, & &1.name)

    inputs_set = MapSet.new(inputs)

    for {field_name, field_struct} <- collect_action_input_fields_with_struct(action.fields),
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

  defp collect_action_input_fields_with_struct(fields, acc \\ []) do
    Enum.reduce(fields, acc, fn
      %Step{fields: step_fields}, acc ->
        collect_action_input_fields_with_struct(step_fields, acc)

      %FieldGroup{fields: group_fields, path: []}, acc ->
        collect_action_input_fields_with_struct(group_fields, acc)

      %FieldGroup{path: [name]} = group, acc ->
        [{name, group} | acc]

      %Field{form_only?: true}, acc ->
        acc

      %Field{type: :attachment}, acc ->
        acc

      %Field{name: name, path: []} = field, acc ->
        [{name, field} | acc]

      %Field{path: [name]} = field, acc ->
        [{name, field} | acc]

      _, acc ->
        acc
    end)
  end

  defp validate_all_accepted_included(action, action_resource, module) do
    fields = collect_attribute_fields(action.fields)
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

  defp collect_attribute_fields(fields) do
    Enum.reduce(fields, MapSet.new(), fn
      %Step{fields: step_fields}, acc ->
        MapSet.union(acc, collect_attribute_fields(step_fields))

      %FieldGroup{fields: group_fields, path: []}, acc ->
        MapSet.union(acc, collect_attribute_fields(group_fields))

      %FieldGroup{path: [name]}, acc ->
        MapSet.put(acc, name)

      %Field{form_only?: true}, acc ->
        acc

      %Field{name: name, path: []}, acc ->
        MapSet.put(acc, name)

      %Field{path: [name]}, acc ->
        MapSet.put(acc, name)

      _, acc ->
        acc
    end)
  end

  defp validate_all_arguments_included(action, action_resource, module) do
    fields = collect_argument_fields(action.fields)
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

  defp collect_argument_fields(fields) do
    Enum.reduce(fields, MapSet.new(), fn
      %Step{fields: step_fields}, acc ->
        MapSet.union(acc, collect_argument_fields(step_fields))

      %FieldGroup{fields: group_fields, path: []}, acc ->
        MapSet.union(acc, collect_argument_fields(group_fields))

      %FieldGroup{path: [name]}, acc ->
        MapSet.put(acc, name)

      %Field{form_only?: true}, acc ->
        acc

      %Field{name: name, path: []}, acc ->
        MapSet.put(acc, name)

      %Field{path: [name]}, acc ->
        MapSet.put(acc, name)

      _, acc ->
        acc
    end)
  end

  defp collect_set_names(sets), do: MapSet.new(sets || [], & &1.name)

  defp validate_form_only_fields_not_in_action(action, action_resource, module) do
    resource_action = Ash.Resource.Info.action(action_resource, action.name)

    inputs =
      MapSet.new(resource_action.accept ++ Enum.map(resource_action.arguments, & &1.name))

    for {name, field_struct} <- collect_form_only_fields_with_struct(action.fields),
        MapSet.member?(inputs, name) do
      Error.raise!(
        module: module,
        location: Entity.anno(field_struct),
        path: [:forms, :action, action.name, :field, name],
        why: "form_only field #{inspect(name)} shadows an accepted attribute or argument",
        fix:
          "rename the form_only field, or remove `form_only?: true` so it maps to the action input"
      )
    end
  end

  defp collect_form_only_fields_with_struct(fields, acc \\ []) do
    Enum.reduce(fields, acc, fn
      %Step{fields: step_fields}, acc ->
        collect_form_only_fields_with_struct(step_fields, acc)

      %FieldGroup{fields: group_fields, path: []}, acc ->
        collect_form_only_fields_with_struct(group_fields, acc)

      %Field{form_only?: true, name: name, path: []} = field, acc ->
        [{name, field} | acc]

      _, acc ->
        acc
    end)
  end

  defp validate_attachment_upload_declared(action, action_resource, module) do
    declared = attachment_field_names(action.fields)

    for name <- attachment_names(action_resource), name not in declared do
      Error.raise!(
        module: module,
        location: Entity.anno(action),
        path: [:forms, :action, action.name],
        why:
          "resource #{inspect(action_resource)} has an :#{name} attachment via AshStorage but " <>
            "this form action does not declare an :attachment field for it",
        fix:
          "add `field :#{name}, type: :attachment` to this action, or exclude :#{name} if " <>
            "attachments are not needed"
      )
    end
  end

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
    fields
    |> List.wrap()
    |> Enum.flat_map(fn
      %Field{type: :attachment, name: name} -> [name]
      %Step{fields: step_fields} -> attachment_field_names(step_fields)
      %FieldGroup{fields: group_fields} -> attachment_field_names(group_fields)
      _ -> []
    end)
  end

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

    for bulk_action <- bulk_actions do
      field_names_with_struct = collect_bulk_action_field_names_with_struct(bulk_action.fields)

      for {field_name, field_struct} <- field_names_with_struct,
          MapSet.member?(identity_keys, field_name) do
        Error.raise!(
          module: module,
          location: Entity.anno(field_struct) || Entity.anno(bulk_action),
          path: [:forms, :bulk_action, bulk_action.name, :field, field_name],
          why:
            "bulk_action #{inspect(bulk_action.name)} includes identity field " <>
              "#{inspect(field_name)}, which is not allowed",
          fix:
            "remove the field — bulk actions cannot mutate identity attributes since they " <>
              "must remain consistent across selected rows"
        )
      end
    end
  end

  defp collect_bulk_action_field_names_with_struct(fields) do
    Enum.flat_map(fields, fn
      %Field{name: name} = field -> [{name, field}]
      %FieldGroup{fields: children} -> collect_bulk_action_field_names_with_struct(children)
      %Step{fields: children} -> collect_bulk_action_field_names_with_struct(children)
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
      | class: action.class || source.class,
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
      | class: ba.class || source.class,
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
