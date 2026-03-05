defmodule PyroManiac.Resource.Verifiers.ValidateDefaultLabel do
  @moduledoc false
  use Spark.Dsl.Verifier

  alias PyroManiac.Dsl.Error

  @impl true
  def verify(dsl) do
    module = Spark.Dsl.Verifier.get_persisted(dsl, :module)
    default_label = Spark.Dsl.Extension.get_opt(dsl, [:pyro_maniac], :default_label, nil)

    if default_label do
      field = Ash.Resource.Info.field(dsl, default_label)

      if field do
        :ok
      else
        {:error,
         Error.build(
           module: module,
           location: Spark.Dsl.Extension.get_opt_anno(dsl, [:pyro_maniac], :default_label),
           path: [:pyro_maniac, :default_label],
           why:
             "default_label #{inspect(default_label)} does not exist as an attribute, " <>
               "calculation, or aggregate on this resource",
           suggestions: field_suggestions(default_label, dsl)
         )}
      end
    else
      :ok
    end
  end

  defp field_suggestions(name, dsl) do
    attrs = Enum.map(Ash.Resource.Info.attributes(dsl), & &1.name)
    calcs = Enum.map(Ash.Resource.Info.calculations(dsl), & &1.name)
    aggs = Enum.map(Ash.Resource.Info.aggregates(dsl), & &1.name)
    Error.did_you_mean(name, attrs ++ calcs ++ aggs)
  end
end
