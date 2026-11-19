defmodule PyroManiac.Form.Group do
  @moduledoc """
  A group of form inputs, with a label. With `path`, the inputs are in the
  nested form of a relationship.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type

  use PyroManiac.Dsl.Entity,
    name: :group,
    args: [:label],
    describe: "A group of form inputs.",
    recursive_as: :fields,
    imports: [Ash.Expr],
    entities: [
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input,
        PyroManiac.Form.Row,
        PyroManiac.Form.Compound
      ]
    ],
    schema: [
      label: [
        doc: "The label of this group (defaults to the capitalized last path segment).",
        type: :string
      ],
      description: [
        doc: "Text below the label.",
        type: :string
      ],
      path: [
        default: [],
        doc: "A relative path of relationships. The inputs are in the nested form of that path.",
        type: {:list, :atom}
      ],
      density: [
        default: :normal,
        doc: "`:dense` uses narrower tracks. Use it for lists of short inputs.",
        type: Type.density()
      ],
      max_columns: [
        doc: "The maximum number of columns. `nil`: no limit from the DSL.",
        type: :pos_integer
      ],
      collapsible?: [
        default: false,
        doc: "The user can close and open the group.",
        type: :boolean
      ],
      collapsed?: [
        default: false,
        doc: "The group starts closed. Requires `collapsible? true`.",
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
