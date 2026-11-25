defmodule PyroManiac.Dsl.Verifiers.VerifyFilterStorage do
  @moduledoc false

  # `filter_storage` names `:client`, or a resource with the
  # `PyroManiac.FilterPresets` extension. A verifier, so the resource is not
  # a compile-time dependency of the page.

  use PyroManiac.Dsl.Verifiers

  alias PyroManiac.Dsl.Error

  @impl true
  def verify(dsl) do
    case Verifier.get_option(dsl, [:page], :filter_storage) do
      nil ->
        :ok

      :client ->
        :ok

      storage ->
        if PyroManiac.FilterPresets.storage?(storage),
          do: :ok,
          else:
            {:error,
             Error.build(
               module: Verifier.get_persisted(dsl, :module),
               location: Spark.Dsl.Transformer.get_opt_anno(dsl, [:page], :filter_storage),
               path: [:page, :filter_storage],
               why:
                 "#{inspect(storage)} is not a resource with the `PyroManiac.FilterPresets` " <>
                   "extension",
               fix: "add `extensions: [PyroManiac.FilterPresets]` to it, or use `:client`"
             )}
    end
  end
end
