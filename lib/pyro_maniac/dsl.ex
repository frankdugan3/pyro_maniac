defmodule PyroManiac.Dsl do
  @moduledoc """
  Declarative configuration of user interfaces for Ash resources.
  """

  use Spark.Dsl.Extension,
    sections: [
      %Spark.Dsl.Section{
        describe: "Configure the appearance of data tables in the `PyroManiac.Dsl` extension.",
        # quokka:sort
        entities: [
          PyroManiac.DataTable.Action.__entity__(),
          PyroManiac.DataTable.ActionType.__entity__()
        ],
        name: :data_table,
        # quokka:sort
        schema: [
          class: [
            doc: "The default class for the data table.",
            type: __MODULE__.Type.css_class()
          ],
          description: [
            doc: "The default description for data tables.",
            type: __MODULE__.Type.inheritable(:string)
          ],
          exclude: [
            default: [],
            doc: "The actions to exclude from data tables.",
            type: {:list, :atom}
          ]
        ]
      },
      %Spark.Dsl.Section{
        describe: "Configure the appearance of forms in the `PyroManiac.Dsl` extension.",
        # quokka:sort
        entities: [
          PyroManiac.Form.Action.__entity__(),
          PyroManiac.Form.ActionType.__entity__()
        ],
        name: :form,
        # quokka:sort
        schema: [
          class: [
            doc: "The default class for the form.",
            type: __MODULE__.Type.css_class()
          ],
          description: [
            doc: "The default description for forms.",
            type: __MODULE__.Type.inheritable(:string)
          ],
          exclude: [
            default: [],
            doc: "The actions to exclude from forms.",
            type: {:list, :atom}
          ]
        ]
      }
    ],
    # quokka:sort
    transformers: [
      __MODULE__.Transformers.MergeDataTableActions,
      __MODULE__.Transformers.MergeFormActions
    ],
    # quokka:sort
    verifiers: [
      __MODULE__.Verifiers.DataTable.AllColumnsValid,
      __MODULE__.Verifiers.DataTable.AllPublicIncluded,
      __MODULE__.Verifiers.DataTable.DefaultDisplaysValid,
      __MODULE__.Verifiers.DataTable.DefaultSortsValid,
      __MODULE__.Verifiers.DataTable.NoDuplicateActions,
      __MODULE__.Verifiers.DataTable.NoDuplicateColumnLabels,
      __MODULE__.Verifiers.Form.AllAcceptedIncluded,
      __MODULE__.Verifiers.Form.AllArgumentsIncluded,
      __MODULE__.Verifiers.Form.AllFieldsInAction,
      __MODULE__.Verifiers.Form.ExactlyOneAutofocus,
      __MODULE__.Verifiers.Form.NoDuplicateActions,
      __MODULE__.Verifiers.Form.NoDuplicateFieldLabels,
      __MODULE__.Verifiers.Form.NoDuplicateFields
    ],
    # quokka:sort
    persisters: [
      __MODULE__.Persisters.DataTable
    ]
end
