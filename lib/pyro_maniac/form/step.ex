defmodule PyroManiac.Form.Step do
  @moduledoc """
  A step for wizard forms.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type

  use PyroManiac.Dsl.Entity,
    name: :step,
    args: [:name],
    describe: "Configure a form step in the `PyroManiac` extension.",
    imports: [Ash.Expr],
    entities: [
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input,
        PyroManiac.Form.Group,
        PyroManiac.Form.Row,
        PyroManiac.Form.Compound
      ]
    ],
    schema: [
      label: [
        doc: "The label of this step (defaults to capitalized name).",
        type: :string
      ],
      name: [
        doc: "The name of the step.",
        required: true,
        type: :atom
      ],
      path: [
        default: [],
        doc:
          "Base path for all inputs in this step. When set, inputs are rendered within the nested form of this path.",
        type: {:list, :atom}
      ],
      render: [
        doc:
          "A render module that replaces the rendering of the step. The renderer requires its render behaviour.",
        type: Type.render_module()
      ],
      review?: [
        default: false,
        doc: "When true, auto-generates a read-only summary of previous steps.",
        type: :boolean
      ],
      density: [
        default: :normal,
        doc: "`:dense` uses narrower tracks.",
        type: Type.density()
      ],
      max_columns: [
        doc: "The maximum number of columns.",
        type: :pos_integer
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
