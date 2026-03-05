defmodule PyroManiac.View.Relationship do
  @moduledoc """
  A view relationship configuration in `PyroManiac`.

  Relationships display related records within a grid view section.
  The `display` option controls how the related data is rendered.
  """

  use PyroManiac.Dsl.Entity,
    name: :relationship,
    args: [:name],
    describe: "Declare a relationship to display within a grid view section.",
    entities: [
      fields: [PyroManiac.View.Field]
    ],
    schema: [
      class: [
        doc: "CSS classes for this relationship display.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      display: [
        default: :list,
        doc:
          "How to render the related records. `:list` for a simple list, `:table` for a table, `:grid` for a card grid, `:count` for just a count, `:badge` for badge-style count.",
        type: {:one_of, [:list, :table, :grid, :count, :badge]}
      ],
      empty_text: [
        default: "None",
        doc: "Text to display when there are no related records.",
        type: :string
      ],
      label: [
        doc: "The label for this relationship (defaults to capitalized name).",
        type: :string
      ],
      limit: [
        doc: "Maximum number of related records to display.",
        type: :pos_integer
      ],
      link?: [
        default: true,
        doc: "Whether related records should be linked to their show page.",
        type: :boolean
      ],
      name: [
        doc: "The name of the relationship on the resource.",
        required: true,
        type: :atom
      ],
      render: [
        doc:
          "Custom render function. Receives assigns with `:record`, `:relationship`, and `:related`.",
        type: PyroManiac.Dsl.Type.render_fn()
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  alias PyroManiac.Dsl.Transformers

  @doc false
  def __set_defaults__(relationship) do
    {:ok,
     relationship
     |> Map.update!(:label, fn
       nil -> Transformers.default_label(relationship.name)
       label -> label
     end)}
  end
end
