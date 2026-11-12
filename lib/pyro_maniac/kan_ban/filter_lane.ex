defmodule PyroManiac.KanBan.FilterLane do
  @moduledoc """
  The preparation of the kanban read action. When the `lane_value` argument
  is set, the read returns only the cards of that lane.

  ## Options

    * `:lane` — the attribute name for lane grouping
  """
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, opts, _context) do
    lane_field = Keyword.fetch!(opts, :lane)

    case Ash.Query.get_argument(query, :lane_value) do
      nil -> query
      value -> Ash.Query.filter_input(query, %{lane_field => %{"eq" => value}})
    end
  end
end
