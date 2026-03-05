defmodule PyroManiac.Search.Field do
  @moduledoc """
  A search field within a `PyroManiac.Search.Search` tab.

  Each field maps user input to one or more resource fields/paths,
  applying the configured operator to build filter predicates.
  """

  use PyroManiac.Dsl.Entity,
    name: :field,
    args: [:name],
    describe: "Declare a field in the search form.",
    schema: [
      label: [
        doc: "Input label (defaults to humanized name).",
        type: :string
      ],
      name: [
        doc: "Field identifier.",
        required: true,
        type: :atom
      ],
      operator: [
        default: :contains,
        doc: "Operator for predicates.",
        type: :atom
      ],
      source: [
        doc: "Source fields/paths to search across (defaults to [name]). Values are OR'd.",
        type: {:list, {:or, [:atom, {:list, :atom}]}}
      ],
      value: [
        doc: "Default value to pre-fill the field.",
        type: :any
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  alias PyroManiac.Dsl.Transformers

  @doc false
  def __set_defaults__(field) do
    {:ok,
     field
     |> Map.update!(:source, fn
       nil -> [field.name]
       source -> source
     end)
     |> Map.update!(:label, fn
       nil -> Transformers.default_label(field.name)
       label -> label
     end)}
  end
end
