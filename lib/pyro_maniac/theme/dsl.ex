defmodule PyroManiac.Theme.Dsl do
  @moduledoc """
  Declarative configuration of theme for user interfaces.
  """

  use Spark.Dsl.Extension,
    sections: [
      %Spark.Dsl.Section{
        describe: "Configure appearance of UI components.",
        entities: [
          PyroManiac.Theme.BaseClass.__entity__()
        ],
        name: :theme,
        schema: [
          base_class_names: [
            type: {:list, :atom},
            doc: "Custom list of required base classes."
          ],
          prefix: [
            doc: "A prefix for all base classes",
            type: :string,
            default: ""
          ]
        ]
      }
    ],
    # quokka:sort
    transformers: [
      __MODULE__.Transformers.ApplyPrefix,
      __MODULE__.Transformers.ApplyTheme
    ],
    # quokka:sort
    verifiers: [
      __MODULE__.Verifiers.AllBaseClassesImplemented
    ]
end
