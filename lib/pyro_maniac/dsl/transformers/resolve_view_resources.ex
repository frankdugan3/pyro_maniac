defmodule PyroManiac.Dsl.Transformers.ResolveViewResources do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.View.Column
  alias PyroManiac.View.View

  @ash_resource_transformers Resource.Dsl.transformers()

  @impl true
  def after?(module) when module in @ash_resource_transformers, do: true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    views = Transformer.get_entities(dsl, [:views])
    has_views? = Enum.any?(views, &match?(%View{}, &1))

    if has_views? do
      {:ok, resolve_views(dsl)}
    else
      {:ok, dsl}
    end
  end

  defp resolve_views(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    resource = Transformer.get_persisted(dsl, :resource, nil)
    excluded_actions = Transformer.get_option(dsl, [:views], :exclude, [])

    views =
      for %View{} = view <- Transformer.get_entities(dsl, [:views]) do
        view
        |> resolve_resource(resource, nil, module)
        |> validate_not_excluded(excluded_actions, module)
        |> resolve_nested_views(resource, module)
        |> tag_attachment_columns()
        |> resolve_tones_and_sizes(module)
      end

    dsl =
      Transformer.remove_entity(dsl, [:views], fn
        %View{} -> true
        _ -> false
      end)

    Enum.reduce(views, dsl, fn view, dsl ->
      Transformer.add_entity(dsl, [:views], view, prepend: true)
    end)
  end

  # Tags columns whose source is an `AshStorage` attachment relationship as
  # `type: :attachment` (recording the attachment destination resource), so
  # downstream renderers show the attachment affordance by default without
  # requiring an explicit `type:` in the DSL. Soft dependency: a no-op when
  # `AshStorage` isn't compiled or present on the resource. Only single-segment
  # column sources on the view's own resource are tagged; an explicit
  # non-default `type:` is left untouched.
  defp tag_attachment_columns(%View{} = view) do
    columns =
      Enum.map(view.columns || [], fn
        %Column{type: :default, source: [name]} = column ->
          case attachment_destination(view.resource, name) do
            nil -> column
            dest -> %{column | type: :attachment, __attachment_destination__: dest}
          end

        column ->
          column
      end)

    nested = Enum.map(view.views || [], &tag_attachment_columns/1)

    %{view | columns: columns, views: nested}
  end

  defp tag_attachment_columns(other), do: other

  # Validates `tone` (a tone atom or an Ash expression) on columns and view
  # fields, and records the fields that the expression needs. Resolves the
  # `size: :auto` of view fields.
  defp resolve_tones_and_sizes(%View{} = view, module) do
    resource = view.resource

    columns = Enum.map(view.columns || [], &resolve_tone(&1, resource, view, module))

    fields =
      Enum.map(view.fields || [], fn field ->
        field |> resolve_tone(resource, view, module) |> resolve_view_field_size(resource)
      end)

    sections =
      Enum.map(view.sections || [], fn section ->
        section_fields =
          Enum.map(section.fields || [], fn field ->
            field |> resolve_tone(resource, view, module) |> resolve_view_field_size(resource)
          end)

        %{section | fields: section_fields}
      end)

    nested = Enum.map(view.views || [], &resolve_tones_and_sizes(&1, module))

    %{view | columns: columns, fields: fields, sections: sections, views: nested}
  end

  defp resolve_tones_and_sizes(other, _module), do: other

  defp resolve_tone(%{tone: nil} = entity, _resource, _view, _module), do: entity

  defp resolve_tone(%{tone: tone} = entity, resource, view, module) do
    tones = PyroManiac.Dsl.Type.tones()

    cond do
      tone in tones ->
        entity

      is_atom(tone) ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :tone) || Entity.anno(entity),
          path: [:views, :view, view_name(view), entity.name, :tone],
          why: "#{inspect(tone)} is not a tone. The tones are #{inspect(tones)}",
          suggestions: Error.did_you_mean(tone, tones)
        )

      is_function(tone) or is_nil(resource) ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :tone) || Entity.anno(entity),
          path: [:views, :view, view_name(view), entity.name, :tone],
          why: "`tone` is a tone or an Ash expression",
          fix: "use for example `tone :danger` or `tone expr(if overdue?, do: :danger)`"
        )

      true ->
        resolve_tone_expression(entity, resource, view, module)
    end
  end

  defp resolve_tone(entity, _resource, _view, _module), do: entity

  # The refs of a `tone` expression are loaded with the rows, so they can be
  # any field (`in_memory_only?: false`).
  defp resolve_tone_expression(entity, resource, view, module) do
    case PyroManiac.Dsl.Expression.validate_refs(resource, entity.tone, in_memory_only?: false) do
      {:ok, names} ->
        %{entity | __tone_refs__: names}

      {:error, message} ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :tone) || Entity.anno(entity),
          path: [:views, :view, view_name(view), entity.name, :tone],
          why: "the `tone` expression is invalid: #{message}"
        )
    end
  end

  defp view_name(%View{name: [name | _]}), do: name
  defp view_name(_view), do: :view

  defp resolve_view_field_size(
         %PyroManiac.View.Field{size: :auto, source: [name]} = field,
         resource
       )
       when not is_nil(resource) do
    size =
      case Ash.Resource.Info.field(resource, name) do
        %{type: type} = info ->
          cond do
            PyroManiac.TypeInfer.text_type?(type) -> :prose
            PyroManiac.TypeInfer.boolean_type?(type) -> :term
            PyroManiac.TypeInfer.numeric_type?(type) -> :term
            PyroManiac.TypeInfer.date_type?(type) -> :term
            PyroManiac.TypeInfer.time_type?(type) -> :term
            true -> constraint_size(info)
          end

        _ ->
          :name
      end

    %{field | size: size}
  end

  defp resolve_view_field_size(%PyroManiac.View.Field{size: :auto} = field, _resource),
    do: %{field | size: :name}

  defp resolve_view_field_size(field, _resource), do: field

  defp constraint_size(%{constraints: constraints}) when is_list(constraints) do
    case Keyword.get(constraints, :max_length) do
      max when is_integer(max) and max <= 10 -> :code
      max when is_integer(max) and max <= 24 -> :term
      max when is_integer(max) and max >= 100 -> :phrase
      _ -> :name
    end
  end

  defp constraint_size(_info), do: :name

  defp attachment_destination(nil, _name), do: nil

  defp attachment_destination(resource, name) do
    if Code.ensure_loaded?(AshStorage) and Code.ensure_loaded?(AshStorage.Info) and
         AshStorage in Spark.extensions(resource) and
         Enum.any?(AshStorage.Info.attachments(resource), &(&1.name == name)) do
      case Ash.Resource.Info.relationship(resource, name) do
        %{destination: dest} -> dest
        _ -> nil
      end
    end
  rescue
    _ -> nil
  end

  defp resolve_resource(
         %View{relationship: nil, resource: nil} = view,
         parent_resource,
         _parent_rel_resource,
         _module
       ) do
    maybe_put_resource(view, parent_resource)
  end

  defp resolve_resource(
         %View{relationship: rel_name, resource: nil} = view,
         parent_resource,
         _parent_rel_resource,
         module
       ) do
    case Ash.Resource.Info.relationship(parent_resource, rel_name) do
      nil ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(view, :relationship) || Entity.anno(view),
          path: [:views, :view, hd(view.name || [:_])],
          why: "relationship #{inspect(rel_name)} does not exist on #{inspect(parent_resource)}",
          suggestions: relationship_suggestions(rel_name, parent_resource)
        )

      rel ->
        maybe_put_resource(view, rel.destination)
    end
  end

  defp resolve_resource(
         %View{relationship: nil, resource: explicit_resource} = view,
         _parent_resource,
         _parent_rel_resource,
         module
       ) do
    if Enum.empty?(view.sets || []) do
      Error.raise!(
        module: module,
        location: Entity.anno(view),
        path: [:views, :view, hd(view.name || [:_])],
        why:
          "view targeting #{inspect(explicit_resource)} without a relationship requires at " <>
            "least one `set` to map parent fields to the read action",
        fix:
          "add a `set :foo, ...` entity inside the view, or remove `resource:` and use " <>
            "`relationship:` instead"
      )
    end

    maybe_put_resource(view, explicit_resource)
  end

  defp resolve_resource(
         %View{relationship: rel_name, resource: explicit_resource} = view,
         parent_resource,
         _parent_rel_resource,
         module
       ) do
    case Ash.Resource.Info.relationship(parent_resource, rel_name) do
      nil ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(view, :relationship) || Entity.anno(view),
          path: [:views, :view, hd(view.name || [:_])],
          why: "relationship #{inspect(rel_name)} does not exist on #{inspect(parent_resource)}",
          suggestions: relationship_suggestions(rel_name, parent_resource)
        )

      _rel ->
        maybe_put_resource(view, explicit_resource)
    end
  end

  defp maybe_put_resource(%View{resource: nil} = view, resource), do: %{view | resource: resource}

  defp maybe_put_resource(view, _resource), do: view

  defp validate_not_excluded(%View{type: :delegated} = view, _excluded_actions, _module), do: view

  defp validate_not_excluded(%View{name: names} = view, excluded_actions, module) do
    for name <- names do
      if name in excluded_actions do
        Error.raise!(
          module: module,
          location: Entity.anno(view),
          path: [:views, :view, name],
          why: "action #{inspect(name)} is listed in exclude",
          fix:
            "either remove #{inspect(name)} from `exclude([...])`, or remove this `view #{inspect(name)}` block"
        )
      end
    end

    view
  end

  defp resolve_nested_views(%View{views: nil} = view, _parent_resource, _module), do: view
  defp resolve_nested_views(%View{views: []} = view, _parent_resource, _module), do: view

  defp resolve_nested_views(%View{views: nested_views} = view, _parent_resource, module) do
    view_resource = view.resource

    resolved =
      Enum.map(nested_views, fn nested ->
        nested
        |> resolve_resource(view_resource, view_resource, module)
        |> resolve_nested_views(view_resource, module)
      end)

    Map.put(view, :views, resolved)
  end

  defp relationship_suggestions(name, resource) do
    candidates =
      resource
      |> Ash.Resource.Info.relationships()
      |> Enum.map(& &1.name)

    Error.did_you_mean(name, candidates)
  end
end
