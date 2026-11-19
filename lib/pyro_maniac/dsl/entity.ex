defmodule PyroManiac.Dsl.Entity do
  @moduledoc false

  # Builds a Spark entity and its target struct from one declaration.
  #
  # Options (in addition to the `Spark.Dsl.Entity` keys):
  #
  # - `:schema` (required): the options that an author can set.
  # - `:entities`: the nested entities, as `[key: [Module, ...]]`.
  # - `:private_fields`: the fields that a transformer sets. Same format as a
  #   schema (`type`, `default`, `doc`). They are struct fields, but not
  #   options: Spark makes no option macro for them, so the DSL refuses an
  #   author value, and they are not in the cheat sheet. By convention, their
  #   names are `__name__`.

  defmacro __using__(opts) do
    opts[:schema] || raise "Need to specify entity schema"

    quote do
      @pyro_entity_opts unquote(opts)
      @pyro_entity_schema Keyword.fetch!(@pyro_entity_opts, :schema)
      @pyro_entity_entities Keyword.get(@pyro_entity_opts, :entities, [])
      @pyro_entity_private Keyword.get(@pyro_entity_opts, :private_fields, [])

      PyroManiac.Dsl.Entity.__validate_private_fields__!(
        __MODULE__,
        @pyro_entity_schema,
        @pyro_entity_private
      )

      @moduledoc @moduledoc &&
                   @moduledoc <>
                     Spark.Options.docs(@pyro_entity_schema) <>
                     PyroManiac.Dsl.Entity.__private_docs__(@pyro_entity_private)

      defstruct [
        :__spark_metadata__
        # A nested entity key is `[]`, as Spark sets it, also for an
        # entity that `Spark.Dsl.Transformer.build_entity!/4` builds.
        | Keyword.keys(@pyro_entity_schema) ++
            Enum.map(@pyro_entity_entities, fn {key, _mods} -> {key, []} end) ++
            Enum.map(@pyro_entity_private, fn {key, config} ->
              {key, Keyword.get(config, :default)}
            end)
      ]

      @entities @pyro_entity_entities
                |> Enum.map(fn {key, mods} ->
                  {key, Enum.map(mods, & &1.__entity__())}
                end)

      @entity_opts @pyro_entity_opts
                   |> Keyword.delete(:private_fields)
                   |> Keyword.put(:entities, @entities)
                   |> Keyword.put(:target, __MODULE__)
                   |> Keyword.update(:auto_set_fields, [__spark_metadata__: nil], fn fields ->
                     Keyword.put(fields, :__spark_metadata__, nil)
                   end)

      @entity struct!(Spark.Dsl.Entity, @entity_opts)

      @before_compile PyroManiac.Dsl.Entity

      @doc false
      defdelegate fetch(term, key), to: Map
      @doc false
      defdelegate get(term, key, default), to: Map
      @doc false
      defdelegate get_and_update(term, key, fun), to: Map
      @doc false
      def __entity__, do: @entity
      @doc false
      def __private_fields__, do: @pyro_entity_private
    end
  end

  @doc false
  def __validate_private_fields__!(module, schema, private_fields) do
    case Enum.filter(Keyword.keys(private_fields), &Keyword.has_key?(schema, &1)) do
      [] ->
        :ok

      keys ->
        raise ArgumentError,
              "#{inspect(module)}: #{inspect(keys)} are in `schema` and in `private_fields`. " <>
                "A private field is set by a transformer, so it cannot be an option."
    end
  end

  @doc false
  def __private_docs__([]), do: ""

  def __private_docs__(private_fields) do
    items =
      Enum.map_join(private_fields, "\n", fn {key, config} ->
        "* `#{key}` - #{Keyword.get(config, :doc, "")}"
      end)

    "\n\n## Set by the transformer\n\nThese fields are not options. A transformer sets them.\n\n" <>
      items <> "\n"
  end

  defmacro __before_compile__(env) do
    schema = Module.get_attribute(env.module, :pyro_entity_schema)
    entities = Module.get_attribute(env.module, :pyro_entity_entities)
    private = Module.get_attribute(env.module, :pyro_entity_private)
    schema_fields = Spark.Options.Docs.schema_specs(schema)

    private_fields =
      private
      |> Enum.map(fn {key, config} -> {key, Keyword.delete(config, :default)} end)
      |> Spark.Options.Docs.schema_specs()

    entity_fields = Enum.map(entities, &entity_field_typespec/1)

    fields = [
      {:__spark_metadata__, quote(do: Spark.Dsl.Entity.spark_meta())}
      | schema_fields ++ entity_fields ++ private_fields
    ]

    quote do
      @type t :: %__MODULE__{unquote_splicing(fields)}
    end
  end

  defp entity_field_typespec({key, mods}) do
    inner = entity_inner_type(Enum.map(mods, fn mod -> quote(do: unquote(mod).t()) end))
    {key, quote(do: [unquote(inner)])}
  end

  defp entity_inner_type([]), do: quote(do: term())
  defp entity_inner_type([type]), do: type

  defp entity_inner_type([first | rest]) do
    Enum.reduce(rest, first, fn t, acc -> quote(do: unquote(acc) | unquote(t)) end)
  end
end
