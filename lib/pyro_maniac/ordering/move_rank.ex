defmodule PyroManiac.Ordering.MoveRank do
  @moduledoc """
  The change of the move action of `PyroManiac.Ordering`: the new rank of the
  record, computed atomically in the database by `pyro_order_compute_rank`
  (from `PyroManiac.KanBan.PostgresExtension`, version 3).

  Reads the arguments of the move action: `:target_id` (the record to move
  before or after) and `:placement` (`:before`, `:after`, or `:last`).

  ## Options

    * `:scope` — the attribute whose records have their own order, or `nil`
    * `:attribute` — the rank attribute
  """
  use Ash.Resource.Change

  require Ash.Expr

  @impl true
  def change(changeset, opts, _context) do
    scope = Keyword.get(opts, :scope)
    attribute = Keyword.fetch!(opts, :attribute)
    table = AshPostgres.DataLayer.Info.table(changeset.resource)
    scope_value = if scope, do: to_string(Ash.Changeset.get_attribute(changeset, scope))
    target_id = Ash.Changeset.get_argument(changeset, :target_id)

    rank =
      Ash.Expr.expr(
        fragment(
          "pyro_order_compute_rank(?, ?, ?, ?, ?, ?, ?)",
          ^table,
          ^(scope && Atom.to_string(scope)),
          ^Atom.to_string(attribute),
          ^scope_value,
          ^to_string(changeset.data.id),
          ^(target_id && to_string(target_id)),
          ^placement(changeset)
        )
      )

    Ash.Changeset.atomic_update(changeset, attribute, rank)
  end

  @doc false
  def placement(changeset) do
    case Ash.Changeset.get_argument(changeset, :placement) do
      nil -> "last"
      placement -> to_string(placement)
    end
  end
end
