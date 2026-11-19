defmodule PyroManiac.Form.Field do
  @moduledoc """
  A form input for an attribute or an argument of the action.

  The input type is inferred from the Ash type, or set with `type`. A field
  cannot be the foreign key of a `belongs_to` (use `combobox`) or have a
  closed set of values (use `select`), except as a `:checkbox` group.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Form.CommonInput

  use PyroManiac.Dsl.Entity,
    name: :field,
    args: [:name],
    describe: "A form input for an attribute or an argument of the action.",
    imports: [Ash.Expr],
    schema:
      CommonInput.schema() ++
        [
          type: [
            default: :default,
            doc:
              "The input type. `:default` is inferred from the Ash type. For example `:textarea`, `:checkbox`, `:toggle`, `:password`, `:email`, `:attachment`.",
            type: :atom
          ]
        ],
    private_fields:
      CommonInput.private_fields() ++
        [
          __enum_options__: [
            default: [],
            doc:
              "The options of a `:checkbox` group, as `%{value:, label:, description:}`. Set by the transformer.",
            type: {:list, :map}
          ],
          "__multiple?__": [
            default: false,
            doc: "Whether the field has more than one value (an array). Set by the transformer.",
            type: :boolean
          ]
        ]
end
