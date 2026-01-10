defmodule PyroManiac.Theme.Dsl.Verifiers.AllBaseClassesImplemented do
  @moduledoc """
  Ensure all base classes are implemented.
  """

  use PyroManiac.Dsl.Verifiers

  alias PyroManiac.Theme.BaseClass
  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl) do
    module = Verifier.get_persisted(dsl, :module, nil)
    to_implement = Verifier.get_option(dsl, [:theme], :base_class_names) |> MapSet.new()

    implemented =
      dsl
      |> Verifier.get_entities([:theme])
      |> Enum.reduce(MapSet.new(), fn
        %BaseClass{name: name}, acc -> MapSet.put(acc, name)
        _, acc -> acc
      end)

    missing = MapSet.difference(to_implement, implemented)

    if MapSet.size(missing) != 0 do
      raise DslError.exception(
              module: module,
              path: [:theme, :base_class],
              message: """
              The following base classes are not defined:

                #{Enum.map_join(missing, ", ", &inspect/1)}
              """
            )
    end

    :ok
  end
end
