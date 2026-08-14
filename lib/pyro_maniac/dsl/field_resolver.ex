defmodule PyroManiac.Dsl.FieldResolver do
  @moduledoc """
  Fills in what a `PyroManiac.Form.Field` does not say about itself: which
  control to draw, whether nil is allowed, an enum's members, where a combobox
  searches and what it shows. All of it is already on the Ash resource.

  Shared so that a field resolves the same wherever it is declared — a `views`
  read argument by the same rules as a `forms` action's attribute.

  Runs at compile time. Context carries `:module` (error attribution),
  `:extra_form_types` (author-registered types) and `:path_root` (`[:forms]`,
  `[:views]` — where the error points).
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Form.Field
  alias PyroManiac.Info
  alias PyroManiac.TypeInfer
  alias Spark.Dsl.Entity
  alias Spark.Dsl.Transformer

  @built_in_form_types ~w(
    attachment boolean checkbox combobox
    date datetime default email interval naive_datetime
    nested_form number password select text textarea time toggle
  )a

  @doc "The field types every PyroManiac module understands without registering them."
  @spec built_in_form_types() :: [atom()]
  def built_in_form_types, do: @built_in_form_types

  @doc """
  Builds a `PyroManiac.Form.Field` the way the DSL would have.

  `%Field{}` on its own is every key nil; the schema's defaults are applied by
  Spark on the way in. A transformer synthesizing a field goes the same way.
  """
  @spec new_field(keyword()) :: Field.t()
  def new_field(attrs),
    do: Transformer.build_entity!(PyroManiac.Dsl, [:forms, :action], :field, attrs)

  @doc """
  Resolves one field against the resource and action it belongs to.

  A field describing no attribute or argument — form-only, nested form,
  attachment — has nothing to resolve, so only its type is checked.
  """
  @spec resolve(Field.t(), Ash.Resource.t(), atom(), map()) :: Field.t()
  def resolve(%Field{form_only?: true} = field, _resource, _action_name, context),
    do: validate_field_type(field, context)

  def resolve(%Field{type: :nested_form} = field, _resource, _action_name, context),
    do: validate_field_type(field, context)

  def resolve(%Field{type: :attachment} = field, _resource, _action_name, context),
    do: validate_field_type(field, context)

  def resolve(field, resource, action_name, context) do
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

  @doc """
  The `belongs_to` a field name is the foreign key of, if any.
  """
  @spec belongs_to_for(Ash.Resource.t(), atom()) ::
          Ash.Resource.Relationships.BelongsTo.t() | nil
  def belongs_to_for(resource, field_name) do
    Enum.find(
      Ash.Resource.Info.relationships(resource),
      &match?(%Ash.Resource.Relationships.BelongsTo{source_attribute: ^field_name}, &1)
    )
  end

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
          path: field_path(context, field, :combobox_search_action),
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
          path: field_path(context, field, :combobox_search_action),
          why:
            "combobox_search_action #{inspect(action_name)} on #{inspect(resource)} is a " <>
              "#{inspect(type)} action; expected a `:read` action.",
          fix: "point `combobox_search_action:` at a read action on #{inspect(resource)}."
        )

      nil ->
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(field, :combobox_search_action) || Entity.anno(field),
          path: field_path(context, field, :combobox_search_action),
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
    allowed = @built_in_form_types ++ Map.get(context, :extra_form_types, [])

    if type not in allowed do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(field, :type) || Entity.anno(field),
        path: field_path(context, field, :type),
        why:
          "unknown field type #{inspect(type)} for field #{inspect(field.name)}. " <>
            "Accepted types: #{inspect(allowed)}",
        suggestions: Error.did_you_mean(type, allowed)
      )
    end

    field
  end

  defp field_path(context, field, key),
    do: Map.get(context, :path_root, [:forms]) ++ [:field, field.name, key]

  defp default_label(name), do: PyroManiac.Dsl.Transformers.default_label(name)
end
