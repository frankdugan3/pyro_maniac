defmodule PyroManiac.Test.ConnCase do
  @moduledoc """
  Test case for integration tests.

  Provides database sandboxing.
  """

  use ExUnit.CaseTemplate

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Brewery.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
