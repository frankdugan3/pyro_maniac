defmodule PyroManiac.View do
  @moduledoc """
  Runtime functions of the view DSL that all renderers use.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Expression

  @decorations PyroManiac.Dsl.Type.decorations()

  @doc """
  The decoration of a cell or a view field for a record: a decoration atom, or `nil`.

  A `decoration` expression is evaluated in memory, with the record and the
  actor. A result that is not a decoration gives `nil`.
  """
  @spec decoration(map(), struct() | map(), term()) :: atom() | nil
  def decoration(%{decoration: nil}, _record, _actor), do: nil

  def decoration(%{decoration: decoration}, _record, _actor) when decoration in @decorations,
    do: decoration

  def decoration(%{decoration: expression}, %resource{} = record, actor) do
    filled = Expression.fill(expression, actor: actor)

    case Ash.Expr.eval(filled,
           record: record,
           resource: resource,
           actor: actor,
           unknown_on_unknown_refs?: true
         ) do
      {:ok, decoration} when decoration in @decorations -> decoration
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def decoration(_column, _record, _actor), do: nil
end
