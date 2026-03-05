defmodule PyroManiac.Dsl.Transformers.ResolveViewResources do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
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
