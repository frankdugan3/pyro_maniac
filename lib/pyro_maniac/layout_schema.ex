defmodule PyroManiac.LayoutSchema do
  @moduledoc false

  # The options of the layout nodes (`section`, `compound`, `row`), the same
  # in a form, a card, and a grid.

  alias PyroManiac.Dsl.Type

  @visibility [
    only: [
      doc:
        "The actions that show it: the read action of the view (view mode) and the actions of the tree. `nil`: all.",
      type: Type.only()
    ],
    visible?: [
      doc: "Conditional visibility: an Ash expression.",
      type: Type.expression()
    ]
  ]

  @doc false
  def section do
    [
      name: [
        doc: "The identifier of the section.",
        required: true,
        type: :atom
      ],
      label: [
        doc: "The heading of the section (defaults to the capitalized name).",
        type: :string
      ],
      path: [
        default: [],
        doc:
          "A relative path of relationships. The block repeats for each record at the path, and its nodes are of that record (in edit mode, the nested form of that path).",
        type: {:list, :atom}
      ],
      density: [
        default: :normal,
        doc: "`:dense` uses narrower tracks. Use it for lists of short values.",
        type: Type.density()
      ],
      max_columns: [
        doc: "The maximum number of columns. `nil`: no limit from the DSL.",
        type: :pos_integer
      ],
      collapsible?: [
        default: false,
        doc: "The user can close and open the section.",
        type: :boolean
      ],
      collapsed?: [
        default: false,
        doc: "The section starts closed. Requires `collapsible? true`.",
        type: :boolean
      ]
    ] ++ @visibility
  end

  @doc false
  def compound do
    [
      name: [
        doc: "The identifier of the value.",
        required: true,
        type: :atom
      ],
      label: [
        doc: "The name of the value (defaults to the capitalized name).",
        type: :string
      ],
      separator: [
        default: " ",
        doc: "The text between the parts in view mode.",
        type: :string
      ],
      show_labels?: [
        default: false,
        doc:
          "Show the labels of the parts in edit mode. If `false`, they are only for assistive technology.",
        type: :boolean
      ]
    ] ++ @visibility
  end

  @doc false
  def row, do: @visibility

  @doc false
  def set_label(%{label: nil, name: name} = node),
    do: {:ok, %{node | label: PyroManiac.Dsl.Transformers.default_label(name)}}

  def set_label(node), do: {:ok, node}
end
