with {:module, _} <- Code.ensure_loaded(Clarity.Content),
     {:module, _} <- Code.ensure_loaded(Clarity.Vertex.Ash.Resource) do
  defmodule PyroManiac.Clarity.KanBanDiagram do
    @moduledoc """
    Clarity content provider that renders a Mermaid flowchart of an Ash
    resource's `PyroManiac.KanBan` configuration — lanes, priority field,
    move/read actions, and per-lane settings.

    Only compiled when [`:clarity`](https://hex.pm/packages/clarity) is a
    dependency of the current project.
    """

    @behaviour Clarity.Content

    alias Clarity.Vertex
    alias PyroManiac.KanBan.Info, as: KI
    alias PyroManiac.TypeInfer

    @impl Clarity.Content
    def name, do: "KanBan"

    @impl Clarity.Content
    def description, do: "Mermaid flowchart of the resource's KanBan board configuration."

    @impl Clarity.Content
    def applies?(%Vertex.Ash.Resource{resource: resource}, _lens), do: has_kanban?(resource)
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Vertex.Ash.Resource{resource: resource}, _lens) do
      {:mermaid, fn _props -> mermaid(resource) end}
    end

    defp has_kanban?(resource) do
      Code.ensure_loaded?(resource) and PyroManiac.KanBan in Spark.extensions(resource)
    rescue
      _ -> false
    end

    defp mermaid(resource) do
      lane = KI.lane!(resource)
      priority = KI.priority!(resource)
      move_action = KI.move_action!(resource)
      read_action = KI.read_action!(resource)
      per_lane = KI.per_lane(resource)
      count? = KI.count?(resource)

      lane_values = lane_values(resource, lane)

      lines =
        ["flowchart TD"]
        |> add(~s|  resource[["#{escape(inspect(resource))}"]]|)
        |> add(~s|  lane["lane: #{escape(lane)}"]|)
        |> add(~s/  resource -->|"group_by"| lane/)
        |> add(~s|  priority["priority: #{escape(priority)}"]|)
        |> add(~s/  resource -->|"order"| priority/)
        |> add(~s|  move(["move_action: #{escape(move_action)}"])|)
        |> add(~s|  resource --> move|)
        |> add(~s|  read(["read_action: #{escape(read_action)}"])|)
        |> add(~s|  resource --> read|)
        |> add(~s|  config["per_lane: #{per_lane}<br/>count?: #{count?}"]|)
        |> add(~s|  resource --> config|)
        |> add_lanes(lane_values)

      Enum.join(Enum.reverse(lines), "\n")
    end

    defp lane_values(resource, lane) do
      case Ash.Resource.Info.attribute(resource, lane) do
        nil ->
          []

        attr ->
          values = TypeInfer.enum_values(attr.type, Map.get(attr, :constraints, [])) || []
          Enum.map(values, &decorate_value(attr.type, &1))
      end
    end

    defp decorate_value(type, value) when is_atom(type) and is_atom(value) do
      if Code.ensure_loaded?(type) and function_exported?(type, :label, 1) do
        {value, type.label(value)}
      else
        value
      end
    end

    defp decorate_value(_type, value), do: value

    defp add_lanes(acc, []), do: acc

    defp add_lanes(acc, values) do
      acc = add(acc, ~s|  subgraph lanes_box ["Lanes"]|)

      {acc, _} =
        Enum.reduce(values, {acc, 0}, fn value, {acc, i} ->
          {add(acc, ~s|    l#{i}["#{escape(value_label(value))}"]|), i + 1}
        end)

      acc
      |> add("  end")
      |> add("  lane --> lanes_box")
    end

    defp value_label({_name, label}) when is_binary(label), do: label
    defp value_label({name, opts}) when is_list(opts), do: opts[:label] || to_string(name)
    defp value_label(value), do: to_string(value)

    defp add(acc, line), do: [line | acc]

    defp escape(value) when is_binary(value) do
      value
      |> String.replace("\"", "&quot;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
    end

    defp escape(value), do: value |> to_string() |> escape()
  end
end
