defmodule PyroManiac.Dsl.Entity do
  @moduledoc false

  defmacro __using__(opts) do
    schema = opts[:schema] || raise "Need to specify entity schema"
    entities = opts[:entities] || []
    struct_fields = [:__spark_metadata__] ++ Keyword.keys(opts[:schema]) ++ Keyword.keys(entities)

    quote do
      @moduledoc @moduledoc <> Spark.Options.docs(unquote(schema))

      @type t :: %__MODULE__{}
      # @type t :: [unquote(Spark.Options.option_typespec(schema))]
      defstruct unquote(struct_fields)

      @entities unquote(entities)
                |> Enum.map(fn {key, entities} ->
                  {key, Enum.map(entities, & &1.__entity__())}
                end)

      @entity_opts unquote(opts)
                   |> Keyword.put(:entities, @entities)
                   |> Keyword.put(:target, __MODULE__)
                   |> Keyword.update(:auto_set_fields, [__spark_metadata__: nil], fn fields ->
                     Keyword.put(fields, :__spark_metadata__, nil)
                   end)

      @entity struct!(Spark.Dsl.Entity, @entity_opts)

      @doc false
      defdelegate fetch(term, key), to: Map
      @doc false
      defdelegate get(term, key, default), to: Map
      @doc false
      defdelegate get_and_update(term, key, fun), to: Map
      @doc false
      def __entity__, do: @entity
    end
  end
end
