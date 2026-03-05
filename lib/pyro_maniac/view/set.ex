defmodule PyroManiac.View.Set do
  @moduledoc """
  Maps a field from the parent record into the nested cross-resource view's read action.

  Used when a view has an explicit `resource` option but no `relationship`.
  The `set` declares which values from the parent record should be passed
  as arguments/filters to the nested resource's read action.
  """

  use PyroManiac.Dsl.Entity,
    name: :set,
    args: [:name, :source],
    describe:
      "Map a value from the parent record into a cross-resource view. The `name` is the target field on the read action, and `source` is the field to read from the parent record.",
    schema: [
      name: [
        doc: "The target field (argument or filter) on the nested resource's read action.",
        required: true,
        type: :atom
      ],
      source: [
        doc: "The field to read from the parent record.",
        required: true,
        type: :atom
      ]
    ]
end
