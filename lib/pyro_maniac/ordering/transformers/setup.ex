defmodule PyroManiac.Ordering.Transformers.Setup do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias PyroManiac.Ordering.Setup
  alias Spark.Dsl.Transformer

  @ash_resource_transformers Ash.Resource.Dsl.transformers()

  @impl true
  def after?(transformer) when transformer in @ash_resource_transformers, do: true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    attribute = Transformer.get_option(dsl, [:ordering], :attribute)
    scope = Transformer.get_option(dsl, [:ordering], :scope)
    move = Transformer.get_option(dsl, [:ordering], :move_action, :move)

    dsl =
      dsl
      |> Setup.ensure_rank_attribute(attribute, module, [:ordering, :attribute])
      |> Setup.set_column_collation(attribute)
      |> Setup.ensure_unique_index(List.wrap(scope) ++ [attribute], "#{attribute}_order_index")
      |> Setup.add_assign_rank(scope, attribute)
      |> Setup.add_move_action(
        move,
        List.wrap(scope),
        {PyroManiac.Ordering.MoveRank, scope: scope, attribute: attribute},
        module,
        [:ordering, :move_action]
      )

    {:ok, dsl}
  end
end
