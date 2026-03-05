defmodule PyroManiac.Resource do
  @moduledoc """
  Spark DSL extension for Ash resources that exposes PyroManiac configuration.

  Adds a `pyro_maniac` section where the `default_label` field is configured.
  Renderers consume this field via `PyroManiac.Info.default_label/1` to display
  human-readable record names.

  ## Usage

      defmodule MyApp.Brewery.Recipe do
        use Ash.Resource,
          extensions: [PyroManiac.Resource]

        pyro_maniac do
          default_label :name
        end
      end
  """

  use Spark.Dsl.Extension,
    sections: [
      %Spark.Dsl.Section{
        describe: "Configure PyroManiac options for this resource.",
        name: :pyro_maniac,
        schema: [
          default_label: [
            type: :atom,
            required: true,
            doc:
              "The field (attribute, calculation, or aggregate) to use as the display label for records."
          ]
        ]
      }
    ],
    verifiers: [
      PyroManiac.Resource.Verifiers.ValidateDefaultLabel
    ]
end
