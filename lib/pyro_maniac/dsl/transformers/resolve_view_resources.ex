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
    excluded_actions = Transformer.get_option(dsl, [:page], :exclude, [])

    views =
      for %View{} = view <- Transformer.get_entities(dsl, [:views]) do
        view
        |> resolve_resource(resource, module)
        |> validate_not_excluded(excluded_actions, module)
        |> tag_attachment_columns()
        |> resolve_tones_and_sizes(module)
      end

    dsl =
      Transformer.remove_entity(dsl, [:views], fn
        %View{} -> true
        _ -> false
      end)

    Enum.reduce(Enum.reverse(views), dsl, fn view, dsl ->
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

    %{view | columns: columns}
  end

  # Validates `decoration` (a decoration atom or an Ash expression) on the columns, and
  # records the fields that the expression needs. The record tree of a view
  # is resolved with the actions (`ExpandFormActions`).
  defp resolve_tones_and_sizes(%View{} = view, module) do
    columns =
      Enum.map(view.columns || [], fn column ->
        column
        |> resolve_decoration(view.resource, view, module)
        |> resolve_content(view, module)
        |> inherit_column_description(view.resource)
      end)

    read = Ash.Resource.Info.action(view.resource, view.read_action || List.first(view.name))
    description = PyroManiac.Content.inherit(view.description, read && read.description)

    %{view | columns: columns, description: description}
  end

  defp resolve_decoration(%{decoration: nil} = entity, _resource, _view, _module), do: entity

  defp resolve_decoration(%{decoration: decoration} = entity, resource, view, module) do
    decorations = PyroManiac.Dsl.Type.decorations()

    cond do
      decoration in decorations ->
        entity

      is_atom(decoration) ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :decoration) || Entity.anno(entity),
          path: [:views, :view, view_name(view), entity.name, :decoration],
          why:
            "#{inspect(decoration)} is not a decoration. The decorations are #{inspect(decorations)}",
          suggestions: Error.did_you_mean(decoration, decorations)
        )

      is_function(decoration) or is_nil(resource) ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :decoration) || Entity.anno(entity),
          path: [:views, :view, view_name(view), entity.name, :decoration],
          why: "`decoration` is a decoration or an Ash expression",
          fix:
            "use for example `decoration :danger` or `decoration expr(if overdue?, do: :danger)`"
        )

      true ->
        resolve_tone_expression(entity, resource, view, module)
    end
  end

  defp resolve_decoration(entity, _resource, _view, _module), do: entity

  # The refs of a `decoration` expression are loaded with the rows, so they can be
  # any field (`in_memory_only?: false`).
  defp resolve_tone_expression(entity, resource, view, module) do
    case PyroManiac.Dsl.Expression.validate_refs(resource, entity.decoration,
           in_memory_only?: false
         ) do
      {:ok, names} ->
        %{entity | __decoration_refs__: names}

      {:error, message} ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :decoration) || Entity.anno(entity),
          path: [:views, :view, view_name(view), entity.name, :decoration],
          why: "the `decoration` expression is invalid: #{message}"
        )
    end
  end

  # The expressions of `render`, `description`, and `label` of a column, on
  # the resource of the view.
  defp resolve_content(column, view, module) do
    case PyroManiac.Content.resolve_refs(column, view.resource) do
      {:ok, column} ->
        column

      {:error, key, message} ->
        Error.raise!(
          module: module,
          location: Entity.anno(column),
          path: [:views, :view, view_name(view), column.name, key],
          why: "the `#{key}` expression is invalid: #{message}"
        )
    end
  end

  # `description :inherit` on a column: the description of its field.
  defp inherit_column_description(column, resource) do
    {path, [name]} = Enum.split(column.source, -1)

    field =
      case PyroManiac.Info.resource_by_path(resource, path) do
        nil -> nil
        level -> Ash.Resource.Info.field(level, name)
      end

    %{
      column
      | description:
          PyroManiac.Content.inherit(column.description, field && Map.get(field, :description))
    }
  rescue
    _ -> column
  end

  defp view_name(%View{name: [name | _]}), do: name
  defp view_name(_view), do: :view

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

  defp resolve_resource(%View{resource: nil} = view, page_resource, _module),
    do: %{view | resource: page_resource}

  defp resolve_resource(view, _page_resource, _module), do: view

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
end
