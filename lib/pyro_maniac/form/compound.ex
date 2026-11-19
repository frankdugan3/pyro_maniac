defmodule PyroManiac.Form.Compound do
  @moduledoc """
  One value that the user enters in two or more tiny inputs, for example a
  length and its unit. Each part is a separate attribute or argument.

  The label is the name of the value (a `<fieldset>` legend in HTML). The
  labels of the parts are for assistive technology only, unless
  `show_labels?` is `true`. The errors of the parts show together.

      compound "Temperature" do
        field :temperature, label: "Value"
        field :temperature_unit, label: "Unit"
      end
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type

  use PyroManiac.Dsl.Entity,
    name: :compound,
    args: [:label],
    describe: "One value made of two or more tiny inputs.",
    imports: [Ash.Expr],
    entities: [
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input
      ]
    ],
    schema: [
      label: [
        doc: "The name of the value.",
        required: true,
        type: :string
      ],
      description: [
        doc: "Help text for the value.",
        type: :string
      ],
      show_labels?: [
        default: false,
        doc: "Show the labels of the parts. If `false`, they are only for assistive technology.",
        type: :boolean
      ],
      visible?: [
        doc: "Conditional visibility: an Ash expression.",
        type: Type.expression()
      ]
    ],
    private_fields: [
      __full_path__: [
        default: [],
        doc: "The full path from the form resource. Set by the transformer.",
        type: {:list, :atom}
      ],
      __depends_on__: [
        default: [],
        doc:
          "The attributes and arguments that `visible?` refers to, and `{:parent, name}` for `parent(name)`. Set by the transformer.",
        type: {:list, :any}
      ]
    ]
end
