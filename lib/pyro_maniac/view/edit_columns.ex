defmodule PyroManiac.View.EditColumns do
  @moduledoc """
  The cells of some columns of a row, edited together with one action. The
  block is the form of the action.

      edit_columns :update, [:target_og, :target_fg], :discard do
        field :target_og, autofocus: true
        field :target_fg
      end

  The named cells of a row switch to the inputs at the same time, with one
  save. A column in `edit_columns` has no `action` of its own.
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :edit_columns,
    args: [:action, :columns, {:optional, :state}],
    describe: "The cells of some columns of a row, edited together with one action.",
    imports: [Ash.Expr],
    entities: [
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input,
        PyroManiac.Form.Compound
      ]
    ],
    schema: [
      action: [
        doc: "The update action of the resource.",
        required: true,
        type: :atom
      ],
      columns: [
        doc: "The columns of the view whose cells the action edits.",
        required: true,
        type: {:list, :atom}
      ],
      state: [
        doc:
          "What happens to the unsaved inputs: `:guard`, `:recover`, or `:discard` (refer to `action`). Required: the optional third argument or an option in the block.",
        required: true,
        type: {:one_of, [:guard, :recover, :discard]}
      ]
    ]
end
