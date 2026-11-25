defmodule PyroManiac.KanBan.Lane do
  @moduledoc """
  The `lane` of a `PyroManiac.KanBan` board: the field that groups the cards.

  An attribute gives static lanes (its values). A `belongs_to` gives dynamic
  lanes (the records of its destination). The actions of dynamic lanes are
  resolved at compile time: an explicit name, else the primary action of
  that type on the destination (for `move_action`, the move action of the
  ordered destination). `read_action` gives the lanes; `create_action`,
  `update_action`, and `destroy_action` manage them; `move_action` orders
  them. A management or move action without a default is not available
  (`nil`); `false` turns one off.
  """

  @type t :: %__MODULE__{
          name: atom(),
          read_action: atom() | nil,
          create_action: atom() | false | nil,
          update_action: atom() | false | nil,
          destroy_action: atom() | false | nil,
          destroy_confirm: String.t() | false | nil,
          move_action: atom() | false | nil,
          sort: String.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :read_action,
    :create_action,
    :update_action,
    :destroy_action,
    :destroy_confirm,
    :move_action,
    :sort,
    :__spark_metadata__
  ]

  @doc false
  def __entity__ do
    %Spark.Dsl.Entity{
      name: :lane,
      describe: """
      The lanes of the board. An attribute (static lanes): an Ash enum type or
      an atom/string with `one_of` constraints. Or a `belongs_to` (dynamic
      lanes): the records of its destination are the lanes.
      """,
      examples: [
        "lane :status",
        """
        lane :stage do
          read_action :read
          create_action :create
          destroy_action false
          move_action :reorder
          sort "position"
        end
        """
      ],
      target: __MODULE__,
      args: [:name],
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: "An attribute (static lanes) or a `belongs_to` (dynamic lanes)."
        ],
        read_action: [
          type: :atom,
          doc:
            "Dynamic lanes: the read action of the lane resource that gives the lanes. Defaults to its primary read action."
        ],
        create_action: [
          type: :atom,
          doc:
            "Dynamic lanes: the create action that adds a lane. Defaults to the primary create action of the lane resource; `false` or no primary action: the board does not add lanes."
        ],
        update_action: [
          type: :atom,
          doc:
            "Dynamic lanes: the update action that edits a lane (its name, decoration). Defaults to the primary update action of the lane resource; `false` or no primary action: the board does not edit lanes."
        ],
        move_action: [
          type: :atom,
          doc:
            "Dynamic lanes: the update action that moves a lane in the order of the lanes. Defaults to the move action of the lane resource when it is ordered (`PyroManiac.Ordering` or `PyroManiac.KanBan.Lanes`); `false` or an unordered lane resource: the board does not move lanes."
        ],
        destroy_action: [
          type: :atom,
          doc:
            "Dynamic lanes: the destroy action that deletes a lane. Defaults to the primary destroy action of the lane resource; `false` or no primary action: the board does not delete lanes."
        ],
        destroy_confirm: [
          type: {:or, [:string, {:literal, false}]},
          doc:
            "Dynamic lanes: the confirmation of the delete of a lane, a message or `false` (no confirmation). Required when the board deletes lanes: a renderer never adds a confirmation."
        ],
        sort: [
          type: :string,
          doc:
            "Dynamic lanes: the order of the lanes, an Ash sort input (`\"position\"`). Defaults to the rank of the lane resource when it is ordered (`PyroManiac.KanBan.Lanes` or `PyroManiac.Ordering`)."
        ]
      ]
    }
  end
end
