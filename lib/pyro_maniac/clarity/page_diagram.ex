with {:module, _} <- Code.ensure_loaded(Clarity.Content),
     {:module, _} <- Code.ensure_loaded(Clarity.Vertex.Module) do
  defmodule PyroManiac.Clarity.PageDiagram do
    @moduledoc """
    Clarity content provider that renders a Mermaid flowchart of a
    `PyroManiac` page module — its bound resource, route, views, forms,
    and searches.

    Only compiled when [`:clarity`](https://hex.pm/packages/clarity) is a
    dependency of the current project.
    """

    @behaviour Clarity.Content

    alias Clarity.Vertex
    alias PyroManiac.Form.{Action, BulkAction}
    alias PyroManiac.Info, as: PI
    alias PyroManiac.View.View

    @impl Clarity.Content
    def name, do: "PyroManiac Page"

    @impl Clarity.Content
    def description, do: "Mermaid flowchart of the page's views, forms, and searches."

    @impl Clarity.Content
    def applies?(%Vertex.Module{module: module}, _lens), do: pyro_page?(module)
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Vertex.Module{module: module}, _lens) do
      {:mermaid, fn _props -> mermaid(module) end}
    end

    defp pyro_page?(module) do
      Code.ensure_loaded?(module) and PyroManiac.Dsl in Spark.extensions(module)
    rescue
      _ -> false
    end

    defp mermaid(module) do
      resource = PI.resource(module)

      lines =
        ["flowchart TD"]
        |> add_page_node(module)
        |> add_resource(resource)
        |> add_views(module)
        |> add_forms(module)
        |> add_searches(module)

      Enum.join(Enum.reverse(lines), "\n")
    end

    defp add_page_node([header], module) do
      label =
        [
          escape(inspect(module)),
          line("title", PI.title(module)),
          line("route", PI.route(module))
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join("<br/>")

      [~s|  page["#{label}"]|, header]
    end

    defp line(_label, nil), do: nil
    defp line(_label, ""), do: nil
    defp line(label, value), do: "#{label}: #{escape(value)}"

    defp add_resource(acc, nil), do: acc

    defp add_resource(acc, resource) do
      [~s/  page -->|"resource"| res[["#{escape(inspect(resource))}"]]/ | acc]
    end

    defp add_views(acc, module) do
      views = PI.views(module)

      if views == [] do
        acc
      else
        acc = [~s|  subgraph views_box ["Views"]| | acc]

        {acc, _} =
          Enum.reduce(views, {acc, 0}, fn view, {acc, i} ->
            {[view_node(view, i) | acc], i + 1}
          end)

        acc = ["  end" | acc]
        ["  page --> views_box" | acc]
      end
    end

    defp view_node(%View{} = view, i) do
      label =
        [
          view_name(view),
          "type: #{view.type}",
          view.relationship && "rel: #{view.relationship}",
          view.delegate_to && "delegate: #{escape(inspect(view.delegate_to))}"
        ]
        |> Enum.reject(&(&1 in [nil, false]))
        |> Enum.join("<br/>")

      ~s|    v#{i}["#{label}"]|
    end

    defp view_name(%View{name: []}), do: "(unnamed)"
    defp view_name(%View{name: names}) when is_list(names), do: Enum.join(names, ", ")
    defp view_name(%View{name: name}), do: to_string(name)

    defp add_forms(acc, module) do
      forms = PI.form_actions(module)
      bulk = PI.bulk_actions(module)
      all = forms ++ bulk

      if all == [] do
        acc
      else
        acc = [~s|  subgraph forms_box ["Forms"]| | acc]

        {acc, _} =
          Enum.reduce(all, {acc, 0}, fn form, {acc, i} ->
            {[form_node(form, i) | acc], i + 1}
          end)

        acc = ["  end" | acc]
        ["  page --> forms_box" | acc]
      end
    end

    defp form_node(%Action{name: names} = action, i) do
      label =
        [
          "action: #{Enum.join(List.wrap(names), ", ")}",
          action.resource && "on #{escape(inspect(action.resource))}"
        ]
        |> Enum.reject(&(&1 in [nil, false]))
        |> Enum.join("<br/>")

      ~s|    f#{i}["#{label}"]|
    end

    defp form_node(%BulkAction{name: names}, i) do
      label = "bulk: #{Enum.join(List.wrap(names), ", ")}"
      ~s|    f#{i}{{"#{label}"}}|
    end

    defp add_searches(acc, module) do
      searches = PI.searches(module)

      if searches == [] do
        acc
      else
        acc = [~s|  subgraph searches_box ["Searches"]| | acc]

        {acc, _} =
          Enum.reduce(searches, {acc, 0}, fn s, {acc, i} ->
            {[~s|    s#{i}(["#{escape(to_string(s.label || s.name))}"])| | acc], i + 1}
          end)

        acc = ["  end" | acc]
        ["  page --> searches_box" | acc]
      end
    end

    defp escape(value) when is_binary(value) do
      value
      |> String.replace("\"", "&quot;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
    end
  end
end
