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
      description: [
        doc:
          "Help text for the input (defaults to the description of the attribute or argument).",
        type: Type.inheritable(:string)
      ],
      autofocus: [
        default: false,
        doc: "Focus this input when the form opens. Exactly one input of an action has it.",
        type: :boolean
      ],
      path: [
        default: [],
        doc:
          "A relative path of relationships. The input is in the nested form of that path, with no group.",
        type: {:list, :atom}
      ],
      size: [
        default: :auto,
        doc:
          "The content role: `:code`, `:term`, `:name`, `:phrase`, or `:prose`. `:auto` is resolved from the type and the constraints.",
        type: Type.size()
      ],
      visible?: [
        doc:
          "Conditional visibility: an Ash expression (`expr(...)`). It can refer to the attributes at the path of the input, `^arg(:name)`, and `^actor(...)`.",
        type: Type.expression()
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
      ]
    ]
  end
end
