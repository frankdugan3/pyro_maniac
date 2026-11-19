defmodule PyroManiac.Form.Row do
  @moduledoc """
  Layout only: the children stay on one line when the container has
  sufficient space. In a narrow container, they wrap as a unit. A row has no
  semantics and no label.

      row do
        field :city
        field :state
        field :zip
      end
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type

  use PyroManiac.Dsl.Entity,
    name: :row,
    args: [],
    describe: "Inputs that stay on one line when there is space.",
    imports: [Ash.Expr],
    entities: [
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input,
        PyroManiac.Form.Compound
      ]
    ],
    schema: [
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
