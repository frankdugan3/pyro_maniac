defmodule PyroManiac.FilterPresets do
  @moduledoc """
  An Ash resource extension that stores the filter presets of the users: a
  page with `filter_storage MyApp.FilterPreset` saves the filters that a
  user builds (`custom_filters? true`) as records of this resource.

      defmodule Brewery.FilterPreset do
        use Ash.Resource,
          domain: Brewery.Domain,
          data_layer: AshPostgres.DataLayer,
          extensions: [PyroManiac.FilterPresets],
          authorizers: [Ash.Policy.Authorizer]

        filter_presets do
          owner Brewery.Staff
        end

        policies do
          # who reads and writes the presets: for example the owner, and
          # every user for a shared preset
        end
      end

  The extension adds (unless the resource has them):

  - the attributes `id`, `name`, `page` (the page key), `view` (the view
    key, or `nil` for each list view of the page), `filter` (the filter
    input of the view, a map), `sort` (the sort input), `search` (the name
    of a `search` of the page), `inputs` (the values of the fields of the
    search), `interactive?` (the user changes the values of the inputs when
    the preset is applied; else the preset is static), `shared?` (other
    users see it), and the timestamps;
  - with `owner`, a `belongs_to :owner`, set to the actor on create;
  - the actions `read` (primary), `create`, `update`, and `destroy`, and
    `for_page` (the presets of a page, with the argument `page`).

  The policies of the resource control who reads and writes the presets, so
  sharing a preset is a normal authorization of its records.

  The values have one encoding for every renderer: `PyroManiac.ListState`
  gives the page and view keys (`page_key/1`, `view_key/1`), and converts a
  list state to the attributes of a preset and back (`to_preset/1`,
  `from_preset/1`).
  """
  @moduledoc group: "PyroManiac.Resource"

  @filter_presets %Spark.Dsl.Section{
    name: :filter_presets,
    describe: "Store the filter presets of the users in this resource.",
    schema: [
      owner: [
        type: :atom,
        doc:
          "The resource of the users (an actor). Adds `belongs_to :owner`, set to the actor on create."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@filter_presets],
    transformers: [
      PyroManiac.FilterPresets.Transformers.Setup,
      PyroManiac.Resource.Transformers.TypescriptFieldNames
    ]

  @doc "Whether a module is a resource with the `PyroManiac.FilterPresets` extension."
  @spec storage?(module()) :: boolean()
  def storage?(module) do
    Code.ensure_loaded?(module) and Ash.Resource.Info.resource?(module) and
      __MODULE__ in Spark.extensions(module)
  end
end
