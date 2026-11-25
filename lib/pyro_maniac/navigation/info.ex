defmodule PyroManiac.Navigation.Info do
  @moduledoc """
  Runtime introspection for `PyroManiac.Navigation` modules.
  """

  alias PyroManiac.Navigation.Item

  @doc "Returns the full navigation tree (list of items and groups)."
  @spec nav_tree(PyroManiac.Navigation.t()) :: [Item.t() | PyroManiac.Navigation.Group.t()]
  def nav_tree(navigation) do
    Spark.Dsl.Extension.get_persisted(navigation, :nav_tree, [])
  end

  @doc """
  The axis of the navigation (`nav do orientation ... end`): `:vertical` (a
  sidebar, the default) or `:horizontal` (a top bar; its groups are menus).
  """
  @spec orientation(PyroManiac.Navigation.t()) :: :horizontal | :vertical
  def orientation(navigation) do
    Spark.Dsl.Extension.get_opt(navigation, [:nav], :orientation, :vertical)
  end

  @doc "Returns the flat route manifest as `[{path, module}]`."
  @spec route_manifest(PyroManiac.Navigation.t()) :: [{String.t(), module()}]
  def route_manifest(navigation) do
    Spark.Dsl.Extension.get_persisted(navigation, :route_manifest, [])
  end

  @doc "Returns all items flattened (no groups)."
  @spec flat_items(PyroManiac.Navigation.t()) :: [Item.t()]
  def flat_items(navigation) do
    Spark.Dsl.Extension.get_persisted(navigation, :flat_items, [])
  end

  @doc "Looks up the path for a given page module."
  @spec path_for_page(PyroManiac.Navigation.t(), module()) :: String.t() | nil
  def path_for_page(navigation, page_module) do
    case item_for_page(navigation, page_module) do
      %Item{path: path} -> path
      nil -> nil
    end
  end

  @doc "Looks up the full nav item for a given page module."
  @spec item_for_page(PyroManiac.Navigation.t(), module()) :: Item.t() | nil
  def item_for_page(navigation, page_module) do
    navigation
    |> Spark.Dsl.Extension.get_persisted(:items_by_page, %{})
    |> Map.get(page_module)
  end

  @doc """
  The command palette: `%{enabled?:, hotkey:, navigation?:, placeholder:,
  commands:}`. With `navigation?`, the renderer also lists the navigation
  items that the user can open (`flat_items/1`).
  """
  @spec command_palette(PyroManiac.Navigation.t()) :: map()
  def command_palette(navigation) do
    opt = &Spark.Dsl.Extension.get_opt(navigation, [:command_palette], &1, &2)

    %{
      enabled?: opt.(:enabled?, true),
      hotkey: opt.(:hotkey, "mod+k"),
      navigation?: opt.(:navigation?, true),
      placeholder: opt.(:placeholder, "Search"),
      commands:
        navigation
        |> Spark.Dsl.Extension.get_entities([:command_palette])
        |> Enum.map(&command_path/1)
    }
  end

  # A `page` command without `path` opens the `route` of the page.
  defp command_path(%{page: page, path: nil} = command) when not is_nil(page),
    do: %{command | path: PyroManiac.Info.route(page)}

  defp command_path(command), do: command
end
