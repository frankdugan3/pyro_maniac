defmodule PyroManiac.View.Field do
  @moduledoc """
  A view field configuration in `PyroManiac`.

  Fields display individual values from a record within non-table view types
  (`:grid`, `:list`, `:kanban`, `:calendar`, `:gantt`). Unlike columns, fields
  are pre-laid-out by the developer and not interactively managed by the user.
  """

  use PyroManiac.Dsl.Entity,
    name: :field,
    args: [:name],
    describe: "Declare a field to display within a view.",
    schema: [
      class: [
        doc: "CSS classes for this field.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      empty_text: [
        default: "\u2014",
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
      render: [
        doc: "Custom render function. Receives assigns with `:record`, `:field`, and `:value`.",
        type: PyroManiac.Dsl.Type.render_fn()
      ],
      source: [
        doc: "Source path for data (defaults to [name]). Use for relationship traversal.",
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
