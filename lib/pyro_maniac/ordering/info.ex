defmodule PyroManiac.Ordering.Info do
  @moduledoc "Introspection of `PyroManiac.Ordering`."
  @moduledoc group: "PyroManiac.Resource"

  @doc "Whether a resource has `PyroManiac.Ordering`."
  @spec ordered?(Ash.Resource.t()) :: boolean()
  def ordered?(resource), do: PyroManiac.Ordering in Spark.extensions(resource)

  @doc """
  The ordering of a resource: `%{attribute:, scope:, move_action:,
  algorithm:}`, from `PyroManiac.Ordering` (or the lane and the priority of
  `PyroManiac.KanBan`), or `nil`.
  """
  @spec ordering(Ash.Resource.t()) :: map() | nil
  def ordering(resource) do
    cond do
      ordered?(resource) ->
        opt = &Spark.Dsl.Extension.get_opt(resource, [:ordering], &1, &2)

        %{
          attribute: opt.(:attribute, nil),
          scope: opt.(:scope, nil),
          move_action: opt.(:move_action, :move),
          algorithm: opt.(:algorithm, :fractional_index)
        }

      PyroManiac.KanBan.Lanes.lanes?(resource) ->
        opt = &Spark.Dsl.Extension.get_opt(resource, [:kan_ban_lanes], &1, &2)

        %{
          attribute: opt.(:position, :position),
          scope: opt.(:scope, nil),
          move_action: opt.(:move_action, :move),
          algorithm: :fractional_index
        }

      PyroManiac.KanBan.Info.has_kanban?(resource) ->
        %{
          attribute: PyroManiac.KanBan.Info.priority!(resource),
          scope: PyroManiac.KanBan.Info.lane_attribute!(resource),
          move_action: PyroManiac.KanBan.Info.move_action!(resource),
          algorithm: :fractional_index
        }

      true ->
        nil
    end
  rescue
    _ -> nil
  end
end
