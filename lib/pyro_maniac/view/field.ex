defmodule PyroManiac.View.Field do
  @moduledoc """
  A column of the records of a `related` (`type :data_table`, `:list`, or
  `:grid`): one value of each related record, with `source` for a path.

      related :recipe_ingredients do
        type :data_table
        field :quantity
        field :notes
      end

  The `field` of a view (its record tree, also at the top of a `:list`,
  `:kanban`, `:calendar`, or `:gantt` view) is `PyroManiac.Form.Field`,
  with `path` for a related value.
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :field,
    args: [:name],
    describe: "A value of each related record: a column of a `related`.",
    imports: [Ash.Expr],
    entities: [link_to: [PyroManiac.LinkTo], render: [PyroManiac.Render]],
    schema: [
      empty_text: [
        default: "—",
        doc: "Text to display when the value is nil or not loaded.",
        type: :string
      ],
      label: [
        doc: "The label for this field (defaults to capitalized name).",
        type: :string
      ],
      name: [
        doc: "The name of the field (attribute, calculation, or aggregate).",
        required: true,
        type: :atom
      ],
      size: [
        default: :auto,
        doc:
          "The content role: `:code`, `:term`, `:name`, `:phrase`, or `:prose`. `:auto` is resolved from the type.",
        type: PyroManiac.Dsl.Type.size()
      ],
      source: [
        doc: "Source path for data (defaults to [name]). Use for relationship traversal.",
        type: {:list, :atom}
      ],
      decoration: [
        doc:
          "The meaning of the value: a decoration, or an Ash expression that gives a decoration or `nil`.",
        type: :any
      ]
    ],
    private_fields: [
      __decoration_refs__: [
        default: [],
        doc: "The fields that the `decoration` expression needs. Set by the transformer.",
        type: {:list, :atom}
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  alias PyroManiac.Dsl.Transformers

  @doc false
  def __set_defaults__(field) do
    {:ok,
     field
     |> Map.update!(:source, fn
       nil -> List.wrap(field.name)
       source -> source
     end)
     |> Map.update!(:label, fn
       nil -> Transformers.default_label(field.name)
       label -> label
     end)}
  end
end
