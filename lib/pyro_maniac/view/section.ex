defmodule PyroManiac.View.Section do
  @moduledoc """
  A view section configuration in `PyroManiac`.

  Sections group fields and relationships into logical areas within `:grid` views.
  Sections can be collapsible for progressive disclosure of detail.
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :section,
    args: [:name],
    describe: "Declare a section grouping fields and relationships within a grid view.",
    entities: [
      fields: [PyroManiac.View.Field],
      relationships: [PyroManiac.View.Relationship]
    ],
    schema: [
      collapsed?: [
        default: false,
        doc: "Whether the section starts collapsed (only relevant when collapsible? is true).",
        type: :boolean
      ],
      collapsible?: [
        default: false,
        doc: "Whether the section can be collapsed/expanded by the user.",
        type: :boolean
      ],
      name: [
        doc: "The name (heading) of this section.",
        required: true,
        type: :string
      ],
      render: [
        doc:
          "A render module for the entire section. The renderer requires its render behaviour.",
        type: PyroManiac.Dsl.Type.render_module()
      ]
    ]
end
