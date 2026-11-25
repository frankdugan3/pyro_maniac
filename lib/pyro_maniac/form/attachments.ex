defmodule PyroManiac.Form.Attachments do
  @moduledoc """
  The files of an `AshStorage` attachment of the record. View mode lists the
  files. Edit mode has the upload input (the `attach_*` and `detach_*`
  actions of AshStorage).

      attachments :photos
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type

  use PyroManiac.Dsl.Entity,
    name: :attachments,
    args: [:name],
    describe: "The files of an AshStorage attachment of the record.",
    imports: [Ash.Expr],
    entities: [description: [PyroManiac.Description]],
    schema: [
      name: [
        doc: "The attachment of the resource (`has_one_attached` or `has_many_attached`).",
        required: true,
        type: :atom
      ],
      label: [
        doc: "The heading (defaults to the capitalized name).",
        type: :string
      ],
      only: [
        doc:
          "The actions that show it: the read action of the view (view mode) and the actions of the tree. `nil`: all.",
        type: Type.only()
      ],
      visible?: [
        doc: "Conditional visibility: an Ash expression.",
        type: Type.expression()
      ]
    ],
    private_fields: [
      __depends_on__: [
        default: [],
        doc:
          "The attributes and arguments that `visible?` refers to, and `{:parent, name}` for `parent(name)`. Set by the transformer.",
        type: {:list, :any}
      ],
      __full_path__: [
        default: [],
        doc: "The full path from the form resource. Set by the transformer.",
        type: {:list, :atom}
      ]
    ]
end
