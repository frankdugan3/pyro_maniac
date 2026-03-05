defmodule PyroManiac.Search.Search do
  @moduledoc """
  A search tab configuration in `PyroManiac`.

  Search tabs provide simple text-input forms that map user input to filter
  predicates across one or more resource fields. They appear as preconfigured,
  non-removable tabs in the tabbed filter UI.
  """

  use PyroManiac.Dsl.Entity,
    name: :search,
    args: [:name],
    describe: "Declare a search tab for the tabbed filter UI.",
    entities: [
      fields: [PyroManiac.Search.Field]
    ],
    schema: [
      interactive?: [
        default: true,
        doc: "When false, all inputs are rendered disabled (read-only search tab).",
        type: :boolean
      ],
      label: [
        doc: "Tab label (defaults to humanized name).",
        type: :string
      ],
      name: [
        doc: "Search identifier.",
        required: true,
        type: :atom
      ],
      operator: [
        default: :and,
        doc: "How field predicates combine (:and or :or).",
        type: {:one_of, [:and, :or]}
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  alias PyroManiac.Dsl.Transformers

  @doc false
  def __set_defaults__(search) do
    {:ok,
     Map.update!(search, :label, fn
       nil -> Transformers.default_label(search.name)
       label -> label
     end)}
  end
end
