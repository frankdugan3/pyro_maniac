defmodule PyroManiac.Ordering do
  @moduledoc """
  An Ash resource extension that keeps the records in a user-defined order:
  an attribute that holds the rank of each record, and an action that moves
  a record before or after another one. A view with `reorder? true` lets the
  user drag the records, when the list is sorted by the rank.

      defmodule Brewery.RecipeIngredient do
        use Ash.Resource,
          data_layer: AshPostgres.DataLayer,
          extensions: [PyroManiac.Ordering]

        ordering do
          attribute :position
          scope :recipe_id
        end
      end

  - `attribute`: the rank attribute. The extension adds it (a `:string`)
    when the resource does not have it.
  - `algorithm`: how the ranks are made. `:fractional_index` (the default):
    a move changes the rank of the moved record only.
  - `scope`: an attribute whose records have their own order (for example
    the ingredients of each recipe). Without it, one order for all the
    records.
  - `move_action`: the update action that moves a record (default
    `:move`). Its public arguments are `:target_id` (the record to move
    before or after) and `:placement` (`:before`, `:after`, or `:last`, the
    default). A client gives them as inputs, also over RPC.

  A new record goes to the end of its scope. The rank is computed in the
  database (AshPostgres, with `PyroManiac.KanBan.PostgresExtension` in the
  installed extensions of the repo); the other data layers are on the
  roadmap. `PyroManiac.KanBan` uses the same machinery for the cards of a
  lane.
  """
  @moduledoc group: "PyroManiac.Resource"

  @ordering %Spark.Dsl.Section{
    name: :ordering,
    describe: "Keep the records in a user-defined order.",
    schema: [
      attribute: [type: :atom, required: true, doc: "The rank attribute (a `:string`)."],
      algorithm: [
        type: {:one_of, [:fractional_index]},
        default: :fractional_index,
        doc: "How the ranks are made: `:fractional_index` (a move changes one record)."
      ],
      scope: [
        type: :atom,
        doc: "An attribute whose records have their own order. `nil`: one order."
      ],
      move_action: [
        type: :atom,
        default: :move,
        doc: "The update action that the extension adds to move a record."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@ordering],
    transformers: [PyroManiac.Ordering.Transformers.Setup]
end
