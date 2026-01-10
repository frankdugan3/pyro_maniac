defmodule PyroManiac.Dsl.Persisters.DataTable do
  @moduledoc """
  Persists map data structures for fast access of DataTable info.
  """
  use Spark.Dsl.Transformer

  alias PyroManiac.DataTable.Action
  alias Spark.Dsl.Transformer

  @doc """
  Runs after all other transformers.
  """
  @spec after?(module()) :: boolean()
  def after?(_), do: true

  @doc """
  Persists DataTable actions by name for fast lookup.
  """
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl) do
    actions_by_name =
      for %Action{} = action <- Transformer.get_entities(dsl, [:data_table]), into: %{} do
        {action.name, action}
      end

    {:ok,
     dsl
     |> Transformer.persist(:data_table_actions_by_name, actions_by_name)}
  end
end
