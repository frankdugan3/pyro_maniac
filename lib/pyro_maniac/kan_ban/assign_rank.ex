defmodule PyroManiac.KanBan.AssignRank do
  @moduledoc """
  Ash resource change that assigns a fractional index rank on create
  if one is not already set. Appends the card to the end of its lane.

  ## Options

    * `:lane` — the attribute name for lane grouping
    * `:priority` — the attribute name for the rank string
  """
  use Ash.Resource.Change

  alias PyroManiac.KanBan.FractionalIndex

  @impl true
  def change(changeset, opts, _context) do
    lane_field = Keyword.fetch!(opts, :lane)
    priority_field = Keyword.fetch!(opts, :priority)

    if Ash.Changeset.get_attribute(changeset, priority_field) do
      changeset
    else
      resource = changeset.resource

      Ash.Changeset.before_action(changeset, fn changeset ->
        lane_value = Ash.Changeset.get_attribute(changeset, lane_field)
        last_rank = last_rank(resource, lane_field, priority_field, lane_value)
        rank = FractionalIndex.generate_key_between(last_rank, nil)
        Ash.Changeset.force_change_attribute(changeset, priority_field, rank)
      end)
    end
  end

  defp last_rank(_resource, _lane_field, _priority_field, nil), do: nil

  defp last_rank(resource, lane_field, priority_field, lane_value) do
    resource
    |> Ash.Query.filter_input(%{lane_field => %{"eq" => lane_value}})
    |> Ash.Query.sort([{priority_field, :desc}])
    |> Ash.Query.limit(1)
    |> Ash.read!()
    |> case do
      [record] -> Map.get(record, priority_field)
      _ -> nil
    end
  end
end
