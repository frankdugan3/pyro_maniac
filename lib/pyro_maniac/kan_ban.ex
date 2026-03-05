defmodule PyroManiac.KanBan do
  @moduledoc """
  Ash resource extension for kanban board support.

  Adds a `kan_ban` DSL section to configure priority-based card ordering
  and lane grouping. The transformer automatically creates the priority
  attribute (if missing), a dedicated update action for card moves, and
  a read action for per-lane loading.

  ## Usage

      defmodule MyApp.Task do
        use Ash.Resource,
          extensions: [PyroManiac.KanBan]

        kan_ban do
          lane :status
          priority :kanban_priority
          move_action :move_card
          read_action :kanban_read
          per_lane 20
        end
      end
  """

  @kan_ban %Spark.Dsl.Section{
    describe: "Configure kanban board support for this resource.",
    name: :kan_ban,
    schema: [
      lane: [
        type: :atom,
        required: true,
        doc:
          "The attribute used to group records into swimlanes. Must be an Ash enum type or an atom/string with `one_of` constraints."
      ],
      priority: [
        type: :atom,
        required: true,
        doc:
          "The integer attribute used for card ordering within lanes. Created automatically if it doesn't exist on the resource."
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
          "The name of the read action created for per-lane kanban loading. Accepts a `lane_value` argument and limits results to `per_lane`."
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
