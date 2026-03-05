defmodule Brewery.Scope do
  @moduledoc """
  Test scope struct implementing `Ash.Scope.ToOpts`.
  """

  defstruct [:current_user, :tenant]

  defimpl Ash.Scope.ToOpts do
    def get_actor(%{current_user: user}), do: {:ok, user}
    def get_tenant(%{tenant: tenant}), do: {:ok, tenant}
    def get_context(_), do: :error
    def get_tracer(_), do: :error
    def get_authorize?(_), do: {:ok, false}
  end
end
