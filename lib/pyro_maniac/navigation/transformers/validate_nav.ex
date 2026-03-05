defmodule PyroManiac.Navigation.Transformers.ValidateNav do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Navigation.{Group, Item}
  alias Spark.Dsl.Entity
  alias Spark.Dsl.Transformer

  @impl true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module)
    entities = Transformer.get_entities(dsl, [:nav])

    with :ok <- validate_names_unique(entities, module),
         :ok <- validate_entities(entities, module),
         :ok <- validate_paths_unique(entities, module) do
      {:ok, dsl}
    end
  end

  defp validate_entities(entities, module) do
    Enum.reduce_while(entities, :ok, fn entity, :ok ->
      case validate_entity(entity, module) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_entity(%Item{} = item, module) do
    with :ok <- validate_item_target(item, module),
         :ok <- validate_item_path(item, module) do
      validate_icon_image_exclusive(item, module)
    end
  end

  defp validate_entity(%Group{} = group, module) do
    with :ok <- validate_icon_image_exclusive(group, module),
         :ok <- validate_names_unique(group.items || [], module) do
      validate_entities(group.items || [], module)
    end
  end

  defp validate_item_target(%Item{href: href, module: mod, page: page} = item, module) do
    targets = Enum.count([page, mod, href], &(not is_nil(&1)))

    cond do
      targets == 0 ->
        {:error,
         Error.build(
           module: module,
           location: Entity.anno(item),
           path: [:nav, :item, item.name],
           why: "item #{inspect(item.name)} must have exactly one of `page`, `module`, or `href`",
           fix: "set one of `page MyApp.SomePage`, `module MyApp.LiveView`, or `href \"/url\"`"
         )}

      targets > 1 ->
        {:error,
         Error.build(
           module: module,
           location: Entity.anno(item),
           path: [:nav, :item, item.name],
           why:
             "item #{inspect(item.name)} has multiple targets — use only one of `page`, `module`, or `href`",
           fix: "remove all but one of `page`, `module`, or `href`"
         )}

      true ->
        :ok
    end
  end

  defp validate_item_path(%Item{href: href}, _module) when not is_nil(href), do: :ok

  defp validate_item_path(%Item{page: page, path: nil}, _module) when not is_nil(page), do: :ok

  defp validate_item_path(%Item{path: nil} = item, module) do
    {:error,
     Error.build(
       module: module,
       location: Entity.anno(item),
       path: [:nav, :item, item.name],
       why: "item #{inspect(item.name)} with `module` requires a `path`",
       fix: "add `path \"/some-path\"` to the item, or use a `page` reference instead"
     )}
  end

  defp validate_item_path(%Item{path: path} = item, module) do
    if String.starts_with?(path, "/") do
      :ok
    else
      {:error,
       Error.build(
         module: module,
         location: Entity.property_anno(item, :path) || Entity.anno(item),
         path: [:nav, :item, item.name, :path],
         why: "item #{inspect(item.name)} path must start with `/`, got: #{inspect(path)}",
         fix: "prefix the path with `/`, e.g. `path \"/#{path}\"`"
       )}
    end
  end

  defp validate_icon_image_exclusive(%{icon: icon, image: image} = entity, module)
       when not is_nil(icon) and not is_nil(image) do
    name = Map.get(entity, :name)

    {:error,
     Error.build(
       module: module,
       location: Entity.anno(entity),
       path: [:nav, :item, name],
       why: "#{inspect(name)} cannot have both `icon` and `image` — choose one",
       fix: "remove either `icon` or `image`"
     )}
  end

  defp validate_icon_image_exclusive(_, _), do: :ok

  defp validate_names_unique(entities, module) do
    entities
    |> Enum.reduce_while({:ok, MapSet.new()}, fn entity, {:ok, seen} ->
      name = entity.name

      if MapSet.member?(seen, name) do
        {:halt,
         {:error,
          Error.build(
            module: module,
            location: Entity.anno(entity),
            path: [:nav, :item, name],
            why: "duplicate name #{inspect(name)} at the same level"
          )}}
      else
        {:cont, {:ok, MapSet.put(seen, name)}}
      end
    end)
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp validate_paths_unique(entities, module) do
    entities
    |> collect_paths_with_entity()
    |> Enum.reduce_while({:ok, MapSet.new()}, fn {path, entity}, {:ok, seen} ->
      if MapSet.member?(seen, path) do
        {:halt,
         {:error,
          Error.build(
            module: module,
            location: Entity.property_anno(entity, :path) || Entity.anno(entity),
            path: [:nav, :item, entity.name, :path],
            why: "duplicate path #{inspect(path)}"
          )}}
      else
        {:cont, {:ok, MapSet.put(seen, path)}}
      end
    end)
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp collect_paths_with_entity(entities) do
    Enum.flat_map(entities, fn
      %Item{path: path} = item when not is_nil(path) -> [{path, item}]
      %Group{items: items} -> collect_paths_with_entity(items || [])
      _ -> []
    end)
  end
end
