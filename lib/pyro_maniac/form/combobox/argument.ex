defmodule PyroManiac.Form.Combobox.Argument do
  @moduledoc """
  An input for one argument of the `read_action` of a `combobox`.

  The value is a literal, or a template: `search()` (the typed text),
  `input(:name)` (an input of the same form level), `actor(:field)`, or
  `arg(:name)`. As in `set_attribute(:status, arg(:status))` of Ash, a
  template has no `^`, because the value is not in an `expr/1`. In `filter`,
  which is an expression, the same templates have a `^`.

      combobox :supplier_id do
        read_action :by_prefix
        argument :prefix, search()
        search false
      end
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :argument,
    args: [:name, :value],
    describe: "An input for one argument of the `read_action` of a combobox.",
    imports: [Ash.Expr, PyroManiac.Form.Templates],
    identifier: :name,
    schema: [
      name: [
        doc: "The name of the argument of `read_action`.",
        required: true,
        type: :atom
      ],
      value: [
        doc:
          "A literal, or a template: `search()`, `input(:name)`, `actor(:field)`, or `arg(:name)` (no `^`).",
        required: true,
        type: :any
      ]
    ],
    private_fields: [
      __identifier__: [
        doc: "The unique name of the argument (Spark `identifier`). Set by Spark.",
        type: :atom
      ]
    ]
end
