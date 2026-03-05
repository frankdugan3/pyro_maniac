defmodule PyroManiac.Dsl.Verifiers do
  @moduledoc false

  defmacro __using__(_env) do
    quote do
      use Spark.Dsl.Verifier

      import PyroManiac.Dsl.Transformers
      import unquote(__MODULE__)

      alias Spark.Dsl.Entity
      alias Spark.Dsl.Verifier
      alias Spark.Error.DslError
    end
  end
end
