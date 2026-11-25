defmodule PyroManiac.Form.CommonInput do
  @moduledoc """
  The options and the private fields that all form input entities have:
  `field`, `combobox`, `select`, and `input`.

  This module is not an entity. Each input entity merges `schema/0` into its
  own schema and `private_fields/0` into its own private fields.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type

  @doc "The common options of an input."
  def schema do
    [
      name: [
        doc: "The attribute or argument of the action.",
        required: true,
        type: :atom
      ],
      label: [
        doc: "The label of the input (defaults to the capitalized name).",
        type: :string
      ],
      autofocus: [
        default: false,
        doc: "Focus this input when the form opens. Exactly one input of an action has it.",
        type: :boolean
      ],
      path: [
        default: [],
        doc:
          "A relative path of relationships. The input is in the nested form of that path, with no section.",
        type: {:list, :atom}
      ],
      size: [
        default: :auto,
        doc:
          "The content role: `:code`, `:term`, `:name`, `:phrase`, or `:prose`. `:auto` is resolved from the type and the constraints.",
        type: Type.size()
      ],
      only: [
        doc:
          "The actions that show it: the read action of the view (view mode) and the actions of the tree. `nil`: all.",
        type: Type.only()
      ],
      visible?: [
        doc:
          "Conditional visibility: an Ash expression (`expr(...)`). It can refer to the attributes at the path of the input, `^arg(:name)`, and `^actor(...)`.",
        type: Type.expression()
      ],
      decoration: [
        doc:
          "The meaning of the value in view mode: a decoration, or an Ash expression that gives a decoration or `nil`.",
        type: :any
      ],
      empty_text: [
        default: "—",
        doc: "The text in view mode when the value is `nil`.",
        type: :string
      ]
    ]
  end

  @doc "The common private fields of an input."
  def private_fields do
    [
      __full_path__: [
        default: [],
        doc: "The full path from the form resource. Set by the transformer.",
        type: {:list, :atom}
      ],
      "__allow_nil?__": [
        default: true,
        doc: "Whether the attribute or argument allows `nil`. Set by the transformer.",
        type: :boolean
      ],
      __depends_on__: [
        default: [],
        doc:
          "The attributes and arguments that `visible?` refers to, and `{:parent, name}` for `parent(name)`. Set by the transformer.",
        type: {:list, :any}
      ],
      __decoration_refs__: [
        default: [],
        doc: "The fields that the `decoration` expression needs. Set by the transformer.",
        type: {:list, :atom}
      ],
      "__read_only?__": [
        default: false,
        doc:
          "The node is not an input of the action (a calculation, an aggregate, an attribute that the action does not accept, or a relationship): it shows its value in both modes. Set by the transformer.",
        type: :boolean
      ]
    ]
  end
end
