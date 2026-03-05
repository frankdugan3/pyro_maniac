defmodule PyroManiac.Navigation.Dsl do
  @moduledoc false

  use Spark.Dsl.Extension,
    sections: [
      %Spark.Dsl.Section{
        describe: "Define the application navigation structure.",
        entities: [
          PyroManiac.Navigation.Item.__entity__(),
          PyroManiac.Navigation.Group.__entity__()
        ],
        name: :nav,
        schema: []
      }
    ],
    transformers: [
      PyroManiac.Navigation.Transformers.ValidateNav
    ],
    persisters: [
      PyroManiac.Navigation.Persisters.NavTree
    ]
end
