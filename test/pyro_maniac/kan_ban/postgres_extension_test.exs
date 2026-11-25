defmodule PyroManiac.KanBan.PostgresExtensionTest do
  # The SQL functions of the rank of a move, on columns of each type: a lane
  # or a scope can be a text (an enum) or a uuid (a foreign key: the lanes
  # are records). The functions of the source are created in the sandbox
  # transaction (the DDL is rolled back with it).
  use ExUnit.Case, async: false

  alias Brewery.Repo
  alias PyroManiac.KanBan.PostgresExtension

  setup do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: false)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    for {_name, sql} <- PostgresExtension.sql_functions(), do: Repo.query!(sql)

    Repo.query!("""
    CREATE TEMP TABLE pyro_moves (
      id uuid PRIMARY KEY,
      lane_id uuid,
      lane_text text,
      rank text COLLATE "C"
    )
    """)

    lane = Ecto.UUID.generate()
    [a, b, c] = for _ <- 1..3, do: Ecto.UUID.generate()

    for {id, rank} <- [{a, "a0"}, {b, "a1"}, {c, "a2"}] do
      Repo.query!("INSERT INTO pyro_moves VALUES ($1::text::uuid, $2::text::uuid, 'todo', $3)", [
        id,
        lane,
        rank
      ])
    end

    %{lane: lane, a: a, b: b, c: c}
  end

  defp rank!(function, lane_col, lane, record, target, position) do
    %{rows: [[rank]]} =
      Repo.query!("SELECT #{function}('pyro_moves', $1, 'rank', $2, $3, $4, $5)", [
        lane_col,
        lane,
        record,
        target,
        position
      ])

    rank
  end

  test "a card moves before a card of a lane of uuid values", %{lane: lane, a: a, b: b, c: c} do
    rank = rank!("pyro_kanban_compute_rank", "lane_id", lane, c, b, "before")
    assert rank > "a0" and rank < "a1"

    assert rank!("pyro_kanban_compute_rank", "lane_id", lane, a, nil, "last") > "a2"
  end

  test "a card moves after a card of a lane of text values", %{c: c, a: a} do
    rank = rank!("pyro_kanban_compute_rank", "lane_text", "todo", c, a, "after")
    assert rank > "a0" and rank < "a1"
  end

  test "a record moves in a scope of uuid values (an ordering)", %{lane: lane, a: a, b: b, c: c} do
    rank = rank!("pyro_order_compute_rank", "lane_id", lane, a, c, "before")
    assert rank > "a1" and rank < "a2"

    assert rank!("pyro_order_compute_rank", "lane_id", lane, b, nil, "last") > "a2"
  end
end
