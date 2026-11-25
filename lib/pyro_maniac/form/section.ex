defmodule PyroManiac.Form.Section do
  @moduledoc """
  A titled block of the record tree, with its own grid. With `path`, the
  block repeats for each record of a relationship (a nested form in edit
  mode).

  In view mode a section shows the values of its leaves. In edit mode it
  shows their inputs. A section can be in a `row`, to put sections side by
  side.

      section :lines do
        path [:lines]
        field :description
        field :quantity
      end
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :section,
    args: [:name],
    describe:
      "A titled block of the record tree. A `section` can contain other sections, also inside a `row`.",
    recursive_as: :fields,
    imports: [Ash.Expr],
    entities: [
      description: [PyroManiac.Description],
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input,
        PyroManiac.Form.Row,
        PyroManiac.Form.Compound,
        PyroManiac.Form.Related,
        PyroManiac.Form.Attachments,
        PyroManiac.Form.Workflow
      ],
      render: [PyroManiac.Render]
    ],
    schema: PyroManiac.LayoutSchema.section(),
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
