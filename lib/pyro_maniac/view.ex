defmodule PyroManiac.View do
  @moduledoc """
  Runtime functions of the view DSL that all renderers use.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Expression

  @tones PyroManiac.Dsl.Type.tones()

  @doc """
  The tone of a cell or a view field for a record: a tone atom, or `nil`.

  A `tone` expression is evaluated in memory, with the record and the
  actor. A result that is not a tone gives `nil`.
  """
  @spec tone(map(), struct() | map(), term()) :: atom() | nil
  def tone(%{tone: nil}, _record, _actor), do: nil
  def tone(%{tone: tone}, _record, _actor) when tone in @tones, do: tone

  def tone(%{tone: expression}, %resource{} = record, actor) do
    filled = Expression.fill(expression, actor: actor)

    case Ash.Expr.eval(filled,
           record: record,
           resource: resource,
           actor: actor,
           unknown_on_unknown_refs?: true
         ) do
      {:ok, tone} when tone in @tones -> tone
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def tone(_column, _record, _actor), do: nil
end
