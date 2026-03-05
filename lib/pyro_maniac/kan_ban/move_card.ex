defmodule PyroManiac.KanBan.MoveCard do
  @moduledoc """
  Generic Ash resource change for kanban card moves.

  Calls `pyro_kanban_compute_rank` PostgreSQL function atomically
  to compute the new rank in a single UPDATE. All neighbor lookups
  happen inside the DB function.

  Reads `kanban_target_id` and `kanban_position` from changeset context.

  ## Options

    * `:lane` — the attribute name for lane grouping
    * `:priority` — the attribute name for the rank string
  """
  use Ash.Resource.Change

  require Ash.Expr

  @impl true
  def change(changeset, opts, _context) do
    lane_field = Keyword.fetch!(opts, :lane)
    priority_field = Keyword.fetch!(opts, :priority)
    resource = changeset.resource

    target_id = changeset.context[:kanban_target_id]
    position = changeset.context[:kanban_position] || "last"
    new_lane = Ash.Changeset.get_attribute(changeset, lane_field)
    record_id = changeset.data.id

    table = AshPostgres.DataLayer.Info.table(resource)
    lane_col = Atom.to_string(lane_field)
    priority_col = Atom.to_string(priority_field)

    rank_expr =
      Ash.Expr.expr(
        fragment(
          "pyro_kanban_compute_rank(?, ?, ?, ?, ?, ?, ?)",
          ^table,
          ^lane_col,
          ^priority_col,
          ^to_string(new_lane),
          ^to_string(record_id),
          ^(target_id && to_string(target_id)),
          ^position
        )
      )

    Ash.Changeset.atomic_update(changeset, priority_field, rank_expr)
  end
end
