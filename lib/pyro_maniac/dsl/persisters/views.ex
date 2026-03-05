defmodule PyroManiac.Dsl.Persisters.Views do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias PyroManiac.View.View

  @doc """
  Runs after all other transformers.
  """
  @spec after?(module()) :: boolean()
  def after?(_), do: true

  @doc """
  Persists view entities by `{action_name, type}` for fast lookup.

  Since views use `{:wrap_list, :atom}` for names, a single view entity
  with `name: [:read, :published]` creates two entries in the map.
  """
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl) do
    views_by_action_and_type =
      for %View{name: names, type: type} = view <-
            Spark.Dsl.Transformer.get_entities(dsl, [:views]),
          name <- names,
          into: %{} do
        {{name, type}, view}
      end

    {:ok,
     dsl
     |> Spark.Dsl.Transformer.persist(:views_by_action_and_type, views_by_action_and_type)}
  end
end
