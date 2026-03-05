defmodule PyroManiac.Navigation.Persisters.NavTree do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias PyroManiac.Navigation.{Group, Item}

  @impl true
  def after?(_), do: true

  @impl true
  def transform(dsl) do
    entities =
      dsl
      |> Spark.Dsl.Transformer.get_entities([:nav])
      |> resolve_paths_from_pages()

    route_manifest = build_route_manifest(entities)
    flat_items = flatten_items(entities)
    items_by_page = index_by_page(flat_items)

    {:ok,
     dsl
     |> Spark.Dsl.Transformer.persist(:nav_tree, entities)
     |> Spark.Dsl.Transformer.persist(:route_manifest, route_manifest)
     |> Spark.Dsl.Transformer.persist(:flat_items, flat_items)
     |> Spark.Dsl.Transformer.persist(:items_by_page, items_by_page)}
  end

  defp resolve_paths_from_pages(entities) do
    Enum.map(entities, fn
      %Item{page: page, path: nil} = item when not is_nil(page) ->
        case resolve_route_from_page(page) do
          nil -> item
          route -> %{item | path: route}
        end

      %Group{items: items} = group ->
        %{group | items: resolve_paths_from_pages(items || [])}

      other ->
        other
    end)
  end

  defp resolve_route_from_page(page_module) do
    PyroManiac.Info.route(page_module)
  rescue
    _ -> nil
  end

  defp build_route_manifest(entities) do
    Enum.flat_map(entities, fn
      %Item{page: page, path: path} when not is_nil(path) and not is_nil(page) ->
        [{path, page}]

      %Item{module: mod, path: path} when not is_nil(path) and not is_nil(mod) ->
        [{path, mod}]

      %Group{items: items} ->
        build_route_manifest(items || [])

      _ ->
        []
    end)
  end

  defp flatten_items(entities) do
    Enum.flat_map(entities, fn
      %Item{} = item -> [item]
      %Group{items: items} -> flatten_items(items || [])
    end)
  end

  defp index_by_page(items) do
    for %Item{page: page} = item when not is_nil(page) <- items,
        into: %{} do
      {page, item}
    end
  end
end
