defmodule PyroManiac.View.Section do
  @moduledoc """
  A view section configuration in `PyroManiac`.

  Sections group fields and relationships into logical areas within `:grid` views.
  Sections can be collapsible for progressive disclosure of detail.
  """

  use PyroManiac.Dsl.Entity,
    name: :section,
    args: [:name],
    describe: "Declare a section grouping fields and relationships within a grid view.",
    entities: [
      fields: [PyroManiac.View.Field],
      relationships: [PyroManiac.View.Relationship]
    ],
    schema: [
      class: [
        doc: "CSS classes for this section.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
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
          "Custom render function for the entire section. Receives assigns with `:record` and `:section`.",
        type: PyroManiac.Dsl.Type.render_fn()
      ]
    ]
end
