defmodule PyroManiac.Form.Compound do
  @moduledoc """
  One value that the user enters in two or more tiny inputs, for example the
  original and the final gravity of a batch. Each part is a separate attribute or argument.

  The label is the name of the value (a `<fieldset>` legend in HTML). The
  labels of the parts are for assistive technology only, unless
  `show_labels?` is `true`. The errors of the parts show together.

      compound :gravity do
        separator " → "
        field :actual_og, label: "OG"
        field :actual_fg, label: "FG"
      end
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :compound,
    args: [:name],
    describe: "One value made of two or more tiny inputs.",
    imports: [Ash.Expr],
    entities: [
      description: [PyroManiac.Description],
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input
      ],
      render: [PyroManiac.Render]
    ],
    schema: PyroManiac.LayoutSchema.compound(),
    transform: {PyroManiac.LayoutSchema, :set_label, []},
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
