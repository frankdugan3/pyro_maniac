defmodule PyroManiac.KanBan.Expressions.FractionalKeyBetween do
  @moduledoc """
  Ash custom expression for computing fractional index keys.

  Can run in PostgreSQL (via `pyro_fractional_key_between` PL/pgSQL function)
  or in Elixir (via `PyroManiac.KanBan.FractionalIndex`).

  ## Usage in Ash expressions

      expr(fractional_key_between(prev_rank, next_rank))
  """
  use Ash.CustomExpression,
    name: :fractional_key_between,
    arguments: [
      [:string, :string]
    ]

  def expression(AshPostgres.DataLayer, [prev, next]) do
    {:ok, expr(fragment("pyro_fractional_key_between(?, ?)", ^prev, ^next))}
  end

  def expression(data_layer, [prev, next])
      when data_layer in [Ash.DataLayer.Ets, Ash.DataLayer.Simple] do
    {:ok, expr(fragment(&__MODULE__.compute/2, ^prev, ^next))}
  end

  def expression(_data_layer, _args), do: :unknown

  @doc "Elixir implementation of fractional key between."
  def compute(prev, next) do
    PyroManiac.KanBan.FractionalIndex.generate_key_between(prev, next)
  end
end
