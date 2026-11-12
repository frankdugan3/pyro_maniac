defmodule PyroManiac.KanBan.RerankOnLaneChange do
  @moduledoc """
  Ash resource change for the updates that change the lane of a card but not
  its priority, for example a form or a bulk update. It puts the card at the
  end of its new lane.

  Without it, the card keeps its old priority. That key can already be in
  use in the new lane, and then the unique index on the lane and the
  priority refuses the update.

  The move action sets the priority itself (`PyroManiac.KanBan.MoveCard`),
  so the change does nothing for it. An update that does not change the lane
  stays atomic.

  ## Options

    * `:lane` — the attribute name for lane grouping
    * `:priority` — the attribute name for the rank string
    * `:move_action` — the name of the move action
  """
  use Ash.Resource.Change

  alias PyroManiac.KanBan.AssignRank

  @impl true
  def change(changeset, opts, context) do
    lane_field = Keyword.fetch!(opts, :lane)
    priority_field = Keyword.fetch!(opts, :priority)

    if rerank?(changeset, opts) do
      Ash.Changeset.before_action(changeset, fn changeset ->
        lane_value = Ash.Changeset.get_attribute(changeset, lane_field)

        rank =
          AssignRank.rank_after_last(changeset, lane_field, priority_field, lane_value, context)

        Ash.Changeset.force_change_attribute(changeset, priority_field, rank)
      end)
    else
      changeset
    end
  end

  @impl true
  def atomic(changeset, opts, context) do
    if rerank?(changeset, opts) do
      {:not_atomic, "a change of the kanban lane must calculate a new priority"}
    else
      {:ok, change(changeset, opts, context)}
    end
  end

  defp rerank?(changeset, opts) do
    lane_field = Keyword.fetch!(opts, :lane)
    priority_field = Keyword.fetch!(opts, :priority)

    changeset.action && changeset.action.name != Keyword.fetch!(opts, :move_action) &&
      changing?(changeset, lane_field) && !changing?(changeset, priority_field)
  end

  defp changing?(changeset, field) do
    Ash.Changeset.changing_attribute?(changeset, field) or
      Keyword.has_key?(changeset.atomics, field)
  end
end
