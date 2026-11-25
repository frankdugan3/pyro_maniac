defmodule PyroManiac.KanBan do
  @moduledoc """
  Ash resource extension for kanban board support.

  Adds a `kan_ban` DSL section to configure priority-based card ordering
  and lane grouping. The transformer automatically creates the priority
  attribute (if missing), a dedicated update action for card moves, and
  a read action for per-lane loading.

  The priority is a string: a fractional index (`PyroManiac.KanBan.FractionalIndex`).
  A card gets a key between its two neighbors, so a move changes only the
  moved card. The column uses `COLLATE "C"`, so the database sorts the keys
  by byte, as the index needs.

  The transformer also adds these changes:

  - `PyroManiac.KanBan.AssignRank` on each create: a card without a priority
    goes to the end of its lane.
  - `PyroManiac.KanBan.RerankOnLaneChange` on each update except the move
    action: an update that changes the lane but not the priority (for
    example, a form) puts the card at the end of its new lane. Without it,
    the card keeps a priority that can already be in use in the new lane.

  The move action and the database functions need
  `PyroManiac.KanBan.PostgresExtension` in the `installed_extensions` of
  the repo.

  ## Usage

      defmodule Brewery.Batch do
        use Ash.Resource,
          domain: Brewery.Domain,
          extensions: [PyroManiac.Resource, PyroManiac.KanBan]

        kan_ban do
          lane :status
          priority :kanban_priority
          move_action :move_card
          read_action :kanban_read
          per_lane 20
        end
      end

  ## Dynamic lanes

  A `lane` that is a `belongs_to` gives dynamic lanes: the records of the
  destination are the lanes, so the users can add them. The cards are
  ordered in each lane by the foreign key. The destination is an existing
  resource (for example the stages of a project), or a lane resource with
  `PyroManiac.KanBan.Lanes`:

      defmodule Brewery.Task do
        use Ash.Resource,
          extensions: [PyroManiac.Resource, PyroManiac.KanBan]

        relationships do
          belongs_to :stage, Brewery.Stage
        end

        kan_ban do
          lane :stage do
            destroy_action false
          end

          priority :rank
          move_action :move_card
          read_action :kanban_read
        end
      end

  The board reads the lanes with `read_action`; adds, edits, and deletes
  them with `create_action`, `update_action`, and `destroy_action`; and
  moves them with `move_action`. Each one defaults to the primary action of
  that type on the lane resource (`move_action`: the move action of the
  lane resource when it is ordered, `PyroManiac.Ordering.Info.ordering/1`);
  they are resolved at compile time. An action that is set but missing, or
  of another type, is a compile error, and so is a lane resource without a
  read action. Another action without a default is not available, and
  `false` turns one off (`PyroManiac.KanBan.Info.lane_action/2`). The
  `move_action` of the `kan_ban` section moves the cards; the
  `move_action` of the `lane` moves the lanes.

  `PyroManiac.KanBan.Info.lanes/2` reads the lanes of a board. A card
  without a lane (the foreign key is `nil`, when the relationship allows
  it) is in the lane "No lane".
  """

  @kan_ban %Spark.Dsl.Section{
    describe: "Configure kanban board support for this resource.",
    name: :kan_ban,
    entities: [PyroManiac.KanBan.Lane.__entity__()],
    schema: [
      priority: [
        type: :atom,
        required: true,
        doc:
          "The string attribute used for card ordering within lanes (a fractional index). Created automatically if it doesn't exist on the resource."
      ],
      move_action: [
        type: :atom,
        required: true,
        doc:
          "The name of the update action created for kanban card moves. Accepts the lane and priority fields, and shifts other card priorities atomically."
      ],
      read_action: [
        type: :atom,
        required: true,
        doc:
          "The name of the read action created for per-lane kanban loading. Accepts an optional `lane_value` argument that filters to one lane, sorts by the priority, and limits results to `per_lane`."
      ],
      per_lane: [
        type: :pos_integer,
        default: 20,
        doc:
          "Maximum number of cards to load per lane. Cards beyond this limit can be loaded with 'Load more'."
      ],
      count?: [
        type: :boolean,
        default: false,
        doc:
          "When true, display the total count of cards in each lane header. Uses a count query per lane."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@kan_ban],
    transformers: [PyroManiac.KanBan.Transformers.Setup]
end
