with {:module, _} <- Code.ensure_loaded(Clarity.Content),
     {:module, _} <- Code.ensure_loaded(Clarity.Vertex.Module) do
  defmodule PyroManiac.Clarity.NavigationDiagram do
    @moduledoc """
    Clarity content provider that renders a Mermaid flowchart of any
    `PyroManiac.Navigation` module's nav tree.

    Only compiled when [`:clarity`](https://hex.pm/packages/clarity) is a
    dependency of the current project.
    """

    @behaviour Clarity.Content

    alias Clarity.Vertex
    alias PyroManiac.Navigation
    alias PyroManiac.Navigation.{Group, Item}

    @impl Clarity.Content
    def name, do: "Navigation"

    @impl Clarity.Content
    def description, do: "Mermaid flowchart of the navigation tree."

    @impl Clarity.Content
    def applies?(%Vertex.Module{module: module}, _lens), do: pyro_navigation?(module)
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Vertex.Module{module: module}, _lens) do
      {:mermaid, fn _props -> mermaid(module) end}
    end

    defp pyro_navigation?(module) do
      Code.ensure_loaded?(module) and Navigation.Dsl in Spark.extensions(module)
    rescue
      _ -> false
    end

    defp mermaid(module) do
      tree = Navigation.Info.nav_tree(module)
      {lines, _} = walk(tree, "root", 0, [])

      header = ["flowchart TD", ~s|  root["#{escape(inspect(module))}"]|]
      Enum.join(header ++ Enum.reverse(lines), "\n")
    end

    defp walk(entries, parent, counter, acc) do
      Enum.reduce(entries, {acc, counter}, fn entry, {acc, c} ->
        render(entry, parent, c, acc)
      end)
    end

    defp render(%Group{label: label, items: items}, parent, counter, acc) do
      id = "g#{counter}"

      acc = [~s|  subgraph #{id} ["#{escape(label)}"]| | acc]
      {acc, next} = walk(items || [], id, counter + 1, acc)
      acc = ["  end" | acc]
      acc = ["  #{parent} --> #{id}" | acc]
      {acc, next}
    end

    defp render(%Item{} = item, parent, counter, acc) do
      id = "n#{counter}"
      acc = [~s|  #{id}["#{item_label(item)}"]| | acc]
      acc = ["  #{parent} --> #{id}" | acc]
      acc = item_target(item, id, counter) ++ acc
      {acc, counter + 1}
    end

    defp item_label(%Item{} = item) do
      [
        item.name |> Atom.to_string() |> escape(),
        item.path && escape(item.path),
        item.href && escape(item.href)
      ]
      |> Enum.reject(&(&1 in [nil, false]))
      |> Enum.join("<br/>")
    end

    defp item_target(%Item{page: page}, from, _counter) when not is_nil(page) do
      tid = module_id(page)
      [~s|  #{from} -.-> #{tid}[["#{escape(inspect(page))}"]]|]
    end

    defp item_target(%Item{module: module}, from, _counter) when not is_nil(module) do
      tid = module_id(module)
      [~s|  #{from} -.-> #{tid}[["#{escape(inspect(module))}"]]|]
    end

    defp item_target(%Item{href: href}, from, counter) when not is_nil(href) do
      tid = "ext#{counter}"
      [~s|  #{from} -.-> #{tid}(["#{escape(href)}"])|]
    end

    defp item_target(_item, _from, _counter), do: []

    defp module_id(module) do
      "m_" <> (module |> inspect() |> String.replace(~r/[^A-Za-z0-9]/, "_"))
    end

    defp escape(value) when is_binary(value) do
      value
      |> String.replace("\"", "&quot;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
    end
  end
end
