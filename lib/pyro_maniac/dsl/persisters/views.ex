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
  Persists view entities by `{action_name, type}` for fast lookup, and the
  primary views as `:__primary_single_view__` and `:__primary_list_view__`.

  Since views use `{:wrap_list, :atom}` for names, a single view entity
  with `name: [:read, :published]` creates two entries in the map.
  """
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl) do
    views = Spark.Dsl.Transformer.get_entities(dsl, [:views])

    views_by_action_and_type =
      for %View{name: names, type: type} = view <- views,
          name <- names,
          into: %{} do
        {{name, type}, view}
      end

    %{single: single, list: list} = View.primaries(views)

    {:ok,
     dsl
     |> Spark.Dsl.Transformer.persist(:views_by_action_and_type, views_by_action_and_type)
     |> Spark.Dsl.Transformer.persist(:views, Enum.filter(views, &match?(%View{}, &1)))
     |> Spark.Dsl.Transformer.persist(:__primary_single_view__, single)
     |> Spark.Dsl.Transformer.persist(:__primary_list_view__, list)}
  end
end
