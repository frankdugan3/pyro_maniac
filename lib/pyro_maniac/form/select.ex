defmodule PyroManiac.Form.Select do
  @moduledoc """
  A form input for a closed set of values.

  Without `options`, the options come from the type and the constraints:
  a `one_of` constraint, a `one_of` in the `items` of an array, an
  `Ash.Type.NewType`, or an `Ash.Type.Enum`.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Form.CommonInput

  use PyroManiac.Dsl.Entity,
    name: :select,
    args: [:name],
    describe: "A form input for a closed set of values.",
    imports: [Ash.Expr],
    entities: [description: [PyroManiac.Description], render: [PyroManiac.Render]],
    schema:
      CommonInput.schema() ++
        [
          prompt: [
            doc: "The text of the empty option.",
            type: :string
          ],
          options: [
            doc: "Explicit options: values, or `{label, value}` tuples.",
            type: {:list, :any}
          ]
        ],
    private_fields:
      CommonInput.private_fields() ++
        [
          __enum_options__: [
            default: [],
            doc: "The options, as `%{value:, label:, description:}`. Set by the transformer.",
            type: {:list, :map}
          ],
          "__multiple?__": [
            default: false,
            doc:
              "Whether more than one value can be selected (an array). Set by the transformer.",
            type: :boolean
          ]
        ]
end
