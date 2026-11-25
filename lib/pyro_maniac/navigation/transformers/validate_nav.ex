defmodule PyroManiac.Navigation.Transformers.ValidateNav do
  @moduledoc false

  # Validates the navigation and resolves the path of each `page` item from
  # the `route` of its page. The route of a page is in the page; groups are
  # not part of a route. No two routes of the navigation match the same URL.

  use Spark.Dsl.Transformer

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Navigation.{Command, Group, Item}
  alias Spark.Dsl.Entity
  alias Spark.Dsl.Transformer

  @impl true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module)
    entities = Transformer.get_entities(dsl, [:nav])

    commands = Transformer.get_entities(dsl, [:command_palette])

    with :ok <- validate_names_unique(entities, module),
         :ok <- validate_entities(entities, module),
         :ok <- validate_names_unique(commands, module) do
      entities = resolve_page_paths(entities, module)
      validate_routes_disjoint(entities, module)
      validate_commands(commands, module)
      {:ok, replace_entities(dsl, entities)}
    end
  end

  defp replace_entities(dsl, entities) do
    dsl = Transformer.remove_entity(dsl, [:nav], fn _ -> true end)
    Enum.reduce(entities, dsl, &Transformer.add_entity(&2, [:nav], &1, type: :append))
  end

  # Pages ---------------------------------------------------------------------

  defp resolve_page_paths(entities, module) do
    Enum.map(entities, fn
      %Item{page: page} = item when not is_nil(page) ->
        %{item | path: page_route!(page, item, [:nav, :item, item.name], module)}

      %Group{items: items} = group ->
        %{group | items: resolve_page_paths(items || [], module)}

      other ->
        other
    end)
  end

  # The route of a page: the page is a PyroManiac module with a `page`
  # section. A navigation link has no parameters, so the route has none.
  defp page_route!(page, entity, path, module) do
    cond do
      not Spark.Dsl.is?(page, PyroManiac) ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :page) || Entity.anno(entity),
          path: path ++ [:page],
          why: "`page #{inspect(page)}` is not a PyroManiac module",
          fix:
            "use `module #{inspect(page)}` with a `path`, or `use PyroManiac` in #{inspect(page)}"
        )

      not PyroManiac.Info.page?(page) ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :page) || Entity.anno(entity),
          path: path ++ [:page],
          why:
            "#{inspect(page)} has no `page` section, so it is not a page and has no route " <>
              "(it declares views for the pages that reuse them)",
          fix: ~s(add `page do route "/..." end` to #{inspect(page)})
        )

      params?(PyroManiac.Info.route(page)) ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(entity, :page) || Entity.anno(entity),
          path: path ++ [:page],
          why:
            "the route #{inspect(PyroManiac.Info.route(page))} of #{inspect(page)} has parameters, " <>
              "so a link of the navigation cannot open it",
          fix: "link to a page with a route without parameters"
        )

      true ->
        PyroManiac.Info.route(page)
    end
  end

  # Routes --------------------------------------------------------------------

  defp params?(route), do: Enum.any?(segments(route), &(param?(&1) or glob?(&1)))

  defp segments(route), do: String.split(route, "/", trim: true)

  defp param?(":" <> _), do: true
  defp param?(_segment), do: false

  defp glob?("*" <> _), do: true
  defp glob?(_segment), do: false

  @doc false
  # Two routes overlap when one URL matches both: each pair of segments is
  # equal, or one of them is a parameter (`:id`), up to a glob (`*path`).
  def overlap?(left, right), do: overlap_segments?(segments(left), segments(right))

  defp overlap_segments?([], []), do: true
  defp overlap_segments?(["*" <> _ | _], _), do: true
  defp overlap_segments?(_, ["*" <> _ | _]), do: true
  defp overlap_segments?([], _), do: false
  defp overlap_segments?(_, []), do: false

  defp overlap_segments?([a | left], [b | right]) do
    (a == b or param?(a) or param?(b)) and overlap_segments?(left, right)
  end

  defp validate_routes_disjoint(entities, module) do
    entities
    |> collect_paths_with_entity()
    |> Enum.reduce([], &check_route(&1, &2, module))
  end

  defp check_route({path, entity}, seen, module) do
    case Enum.find(seen, fn {other, _} -> overlap?(path, other) end) do
      nil -> [{path, entity} | seen]
      {other, other_entity} -> route_overlap!(path, entity, other, other_entity, module)
    end
  end

  defp route_overlap!(path, entity, other, other_entity, module) do
    why =
      if path == other,
        do:
          "duplicate route #{inspect(path)}: items #{inspect(other_entity.name)} and #{inspect(entity.name)}",
        else:
          "the route #{inspect(path)} of item #{inspect(entity.name)} overlaps the route " <>
            "#{inspect(other)} of item #{inspect(other_entity.name)}: one URL matches both"

    Error.raise!(
      module: module,
      location: Entity.property_anno(entity, :path) || Entity.anno(entity),
      path: [:nav, :item, entity.name],
      why: why,
      fix: "give each item a route that no other route matches"
    )
  end

  defp collect_paths_with_entity(entities) do
    Enum.flat_map(entities, fn
      %Item{path: path} = item when not is_nil(path) -> [{path, item}]
      %Group{items: items} -> collect_paths_with_entity(items || [])
      _ -> []
    end)
  end

  # Commands ------------------------------------------------------------------

  defp validate_commands(commands, module) do
    for %Command{} = command <- commands do
      validate_command_target(command, module)
      validate_command_path(command, module)
    end
  end

  # A command has exactly one target: `page`, `module`, `href`, or `render`.
  defp validate_command_target(command, module) do
    targets =
      Enum.count([command.page, command.module, command.href], &(not is_nil(&1))) +
        if(command.render == [], do: 0, else: 1)

    if targets != 1 do
      Error.raise!(
        module: module,
        location: Entity.anno(command),
        path: [:command_palette, :command, command.name],
        why:
          "command #{inspect(command.name)} has #{targets} targets; a command has exactly " <>
            "one of `page`, `module`, `href`, or `render`",
        fix: "keep one target"
      )
    end
  end

  # A `page` command opens the route of the page, or its own `path` (for
  # example with a query); a `module` command has a `path`.
  defp validate_command_path(%Command{page: page} = command, module) when not is_nil(page) do
    route = page_route!(page, command, [:command_palette, :command, command.name], module)

    if command.path && not String.starts_with?(command.path, route) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(command, :path) || Entity.anno(command),
        path: [:command_palette, :command, command.name, :path],
        why:
          "command #{inspect(command.name)} opens #{inspect(page)}, so its `path` starts with " <>
            "the route #{inspect(route)} of the page, got: #{inspect(command.path)}",
        fix: ~s(use `path "#{route}?..."`, or remove `path` to open the route of the page)
      )
    end
  end

  defp validate_command_path(%Command{module: mod, path: path} = command, module)
       when not is_nil(mod) do
    if !match?("/" <> _, path || "") do
      Error.raise!(
        module: module,
        location: Entity.anno(command),
        path: [:command_palette, :command, command.name, :path],
        why:
          "command #{inspect(command.name)} opens a module, so it has a `path` that starts with `/`",
        fix: ~s(set `path "/batches"`)
      )
    end
  end

  defp validate_command_path(_command, _module), do: :ok

  # Items ---------------------------------------------------------------------

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
           fix:
             "set one of `page BreweryWeb.RecipeLive`, `module BreweryWeb.HomeLive`, or `href \"/url\"`"
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

  defp validate_item_path(%Item{href: href, path: nil}, _module) when not is_nil(href), do: :ok

  defp validate_item_path(%Item{page: page, path: nil}, _module) when not is_nil(page), do: :ok

  defp validate_item_path(%Item{page: page} = item, module) when not is_nil(page) do
    {:error,
     Error.build(
       module: module,
       location: Entity.property_anno(item, :path) || Entity.anno(item),
       path: [:nav, :item, item.name, :path],
       why:
         "item #{inspect(item.name)} opens the page #{inspect(page)}, so its path is the " <>
           "`route` of the page; the navigation does not set it",
       fix:
         ~s(remove `path`, and set `page do route #{inspect(item.path)} end` in #{inspect(page)})
     )}
  end

  defp validate_item_path(%Item{href: href} = item, module) when not is_nil(href) do
    {:error,
     Error.build(
       module: module,
       location: Entity.property_anno(item, :path) || Entity.anno(item),
       path: [:nav, :item, item.name, :path],
       why: "item #{inspect(item.name)} opens the URL `href`, so it has no `path`",
       fix: "remove `path`"
     )}
  end

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
end
