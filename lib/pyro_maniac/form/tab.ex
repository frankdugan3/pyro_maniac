defmodule PyroManiac.Form.Tab do
  @moduledoc """
  One tab of `tabs`. The name is the value of the tab in the URL.

      tab :batches do
        count :batch_count
        related :batches do
          delegate_to BreweryWeb.BatchLive
        end
      end
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type

  use PyroManiac.Dsl.Entity,
    name: :tab,
    args: [:name],
    describe: "One tab of `tabs`.",
    imports: [Ash.Expr],
    entities: [
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input,
        PyroManiac.Form.Section,
        PyroManiac.Form.Row,
        PyroManiac.Form.Compound,
        PyroManiac.Form.Related,
        PyroManiac.Form.Attachments,
        PyroManiac.Form.Workflow
      ],
      render: [PyroManiac.Render]
    ],
    schema: [
      name: [
        doc: "The name of the tab, also its value in the URL.",
        required: true,
        type: :atom
      ],
      label: [
        doc: "The label of the tab (defaults to the capitalized name).",
        type: :string
      ],
      count: [
        doc: "An aggregate or a calculation of the resource: the count in the label.",
        type: :atom
      ],
      only: [
        doc:
          "The actions that show it: the read action of the view (view mode) and the actions of the tree. `nil`: all.",
        type: Type.only()
      ]
    ],
    private_fields: [
      __full_path__: [
        default: [],
        doc: "The full path from the form resource. Set by the transformer.",
        type: {:list, :atom}
      ]
    ]
end
