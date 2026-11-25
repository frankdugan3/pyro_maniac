defmodule PyroManiac.Form.Set do
  @moduledoc """
  Maps a field from the parent record into the cross-resource form params.

  Used with the `resource` option on `action` to explicitly declare which
  values from the parent record should be passed to the target resource's action.

  With `overridable? true`, the value is set once, when the form opens: the
  user can change it in an input of the form. Without it, the value is set
  on submit, and the form has no input for it.
  """

  use PyroManiac.Dsl.Entity,
    name: :set,
    args: [:name, :source],
    describe:
      "Map a value from the parent record into the form. The `name` is the target field on the form resource, and `source` is the field to read from the parent record.",
    schema: [
      name: [
        doc: "The target field (argument or attribute) on the form resource.",
        required: true,
        type: :atom
      ],
      source: [
        doc: "The field to read from the parent record.",
        required: true,
        type: :atom
      ],
      overridable?: [
        default: false,
        doc:
          "The value is set when the form opens, and the user can change it (an input of the form shows it). By default the value is set on submit and the user cannot change it.",
        type: :boolean
      ]
    ]
end
