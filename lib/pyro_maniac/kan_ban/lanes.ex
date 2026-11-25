defmodule PyroManiac.KanBan.Lanes do
  @moduledoc """
  An Ash resource extension for the dynamic lanes of a kanban board: the
  lanes are its records, and a card `belongs_to` its lane (`lane` in the
  `kan_ban` section of the cards; refer to `PyroManiac.KanBan`).

      defmodule Brewery.Stage do
        use Ash.Resource,
          domain: Brewery.Domain,
          data_layer: AshPostgres.DataLayer,
          extensions: [PyroManiac.KanBan.Lanes]

        postgres do
          table "stages"
          repo Brewery.Repo
        end

        kan_ban_lanes do
          scope :project_id
        end

        relationships do
          belongs_to :project, Brewery.Project
        end
      end

  The extension adds (unless the resource has them):

  - the attributes `id`, `name` (the label of the lane), and `decoration`
    (a decoration of `PyroManiac.Info.decorations/0`, or `nil`);
  - the order of the lanes: the rank attribute (`position`), in the
    `scope` when it is set (for example the lanes of each project), a new
    lane at the end, and the move action (`move`, as `PyroManiac.Ordering`);
  - the actions `read`, `create`, `update`, and `destroy` (primary). Create
    and update accept `name`, `decoration`, and the `scope`.

  A lane can also be a record of an existing resource: any `belongs_to`
  lane gives dynamic lanes. This extension is the storage for the lanes
  that are only lanes.
  """
  @moduledoc group: "PyroManiac.Resource"

  @kan_ban_lanes %Spark.Dsl.Section{
    name: :kan_ban_lanes,
    describe: "Store the dynamic lanes of a kanban board in this resource.",
    schema: [
      scope: [
        type: :atom,
        doc:
          "An attribute whose records have their own lanes (for example `:project_id`). `nil`: one set of lanes."
      ],
      position: [
        type: :atom,
        default: :position,
        doc: "The rank attribute of the order of the lanes."
      ],
      move_action: [
        type: :atom,
        default: :move,
        doc: "The update action that moves a lane."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@kan_ban_lanes],
    transformers: [
      PyroManiac.KanBan.Lanes.Transformers.Setup,
      PyroManiac.KanBan.Lanes.Transformers.SetupOrder
    ]

  @doc "Whether a resource has `PyroManiac.KanBan.Lanes`."
  @spec lanes?(Ash.Resource.t()) :: boolean()
  def lanes?(resource), do: __MODULE__ in Spark.extensions(resource)
end

defmodule PyroManiac.KanBan.Lanes.Transformers.Setup do
  @moduledoc false

  # The attributes and the actions of a lane resource. Before the primary
  # actions and the default accept of Ash.

  use Spark.Dsl.Transformer

  alias Ash.Resource.Builder
  alias Spark.Dsl.Transformer

  @impl true
  def before?(Ash.Resource.Transformers.DefaultAccept), do: true
  def before?(Ash.Resource.Transformers.SetPrimaryActions), do: true
  def before?(Ash.Resource.Transformers.BelongsToAttribute), do: true
  def before?(_), do: false

  @impl true
  def transform(dsl) do
    scope = Transformer.get_option(dsl, [:kan_ban_lanes], :scope)
    accept = [:name, :decoration] ++ List.wrap(scope)

    with {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :id, :uuid,
             primary_key?: true,
             allow_nil?: false,
             default: &Ash.UUID.generate/0,
             public?: true,
             writable?: false
           ),
         {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :name, :string, allow_nil?: false, public?: true),
         {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :decoration, :atom,
             constraints: [one_of: PyroManiac.Dsl.Type.decorations()],
             public?: true
           ),
         {:ok, dsl} <- Builder.add_new_action(dsl, :read, :read, primary?: true),
         {:ok, dsl} <-
           Builder.add_new_action(dsl, :create, :create, primary?: true, accept: accept),
         {:ok, dsl} <-
           Builder.add_new_action(dsl, :update, :update,
             primary?: true,
             accept: accept,
             require_atomic?: false
           ) do
      Builder.add_new_action(dsl, :destroy, :destroy, primary?: true)
    end
  end
end

defmodule PyroManiac.KanBan.Lanes.Transformers.SetupOrder do
  @moduledoc false

  # The order of the lanes: the machinery of `PyroManiac.Ordering`. After
  # the transformers of Ash, as `PyroManiac.Ordering`.

  use Spark.Dsl.Transformer

  alias PyroManiac.Ordering.Setup
  alias Spark.Dsl.Transformer

  @ash_resource_transformers Ash.Resource.Dsl.transformers()

  @impl true
  def after?(transformer) when transformer in @ash_resource_transformers, do: true
  def after?(PyroManiac.KanBan.Lanes.Transformers.Setup), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    scope = Transformer.get_option(dsl, [:kan_ban_lanes], :scope)
    position = Transformer.get_option(dsl, [:kan_ban_lanes], :position, :position)
    move = Transformer.get_option(dsl, [:kan_ban_lanes], :move_action, :move)

    dsl =
      dsl
      |> Setup.ensure_rank_attribute(position, module, [:kan_ban_lanes, :position])
      |> Setup.set_column_collation(position)
      |> Setup.ensure_unique_index(List.wrap(scope) ++ [position], "#{position}_lane_index")
      |> Setup.add_assign_rank(scope, position)
      |> Setup.add_move_action(
        move,
        List.wrap(scope),
        {PyroManiac.Ordering.MoveRank, scope: scope, attribute: position},
        module,
        [:kan_ban_lanes, :move_action]
      )

    {:ok, dsl}
  end
end
