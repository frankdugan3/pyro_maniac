defmodule PyroManiac.KanBanLanesTest do
  @moduledoc false
  # Static lanes (an attribute) and dynamic lanes (a `belongs_to`, with the
  # lane storage `PyroManiac.KanBan.Lanes`).
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  alias PyroManiac.KanBan.Info

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defmodule Stage do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.KanBanLanesTest.Domain,
      data_layer: AshPostgres.DataLayer,
      extensions: [PyroManiac.KanBan.Lanes]

    postgres do
      table "pyro_test_stages"
      repo(Brewery.Repo)
    end

    kan_ban_lanes do
      scope(:project_id)
    end

    attributes do
      attribute :project_id, :uuid, public?: true
    end
  end

  defmodule Task do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.KanBanLanesTest.Domain,
      data_layer: AshPostgres.DataLayer,
      extensions: [PyroManiac.KanBan]

    postgres do
      table "pyro_test_tasks"
      repo(Brewery.Repo)
    end

    attributes do
      uuid_primary_key :id
      attribute :title, :string, public?: true
    end

    relationships do
      belongs_to :stage, PyroManiac.KanBanLanesTest.Stage, public?: true
    end

    actions do
      defaults [:read]
    end

    kan_ban do
      lane :stage do
        destroy_confirm(false)
      end

      priority :rank
      move_action(:move_card)
      read_action :kanban_read
    end
  end

  defmodule Phase do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.KanBanLanesTest.Domain,
      data_layer: AshPostgres.DataLayer

    postgres do
      table "pyro_test_phases"
      repo(Brewery.Repo)
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      read :all, primary?: true
      read :active
      create :add, accept: [:name]
      update :rename, accept: [:name]
      update :reorder, accept: [:name]
    end
  end

  defmodule Job do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.KanBanLanesTest.Domain,
      data_layer: AshPostgres.DataLayer,
      extensions: [PyroManiac.KanBan]

    postgres do
      table "pyro_test_jobs"
      repo(Brewery.Repo)
    end

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :phase, PyroManiac.KanBanLanesTest.Phase, public?: true
    end

    actions do
      defaults [:read]
    end

    kan_ban do
      lane :phase do
        read_action :active
        create_action(false)
        update_action(:rename)
        move_action(:reorder)
        sort "name"
      end

      priority :rank
      move_action(:move_card)
      read_action :kanban_read
    end
  end

  # A board on an unordered lane resource, and a board that turns off the
  # lane move.
  defmodule Gig do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.KanBanLanesTest.Domain,
      data_layer: AshPostgres.DataLayer,
      extensions: [PyroManiac.KanBan]

    postgres do
      table "pyro_test_gigs"
      repo(Brewery.Repo)
    end

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :phase, PyroManiac.KanBanLanesTest.Phase, public?: true
    end

    actions do
      defaults [:read]
    end

    kan_ban do
      lane(:phase)
      priority :rank
      move_action(:move_card)
      read_action :kanban_read
    end
  end

  defmodule Chore do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.KanBanLanesTest.Domain,
      data_layer: AshPostgres.DataLayer,
      extensions: [PyroManiac.KanBan]

    postgres do
      table "pyro_test_chores"
      repo(Brewery.Repo)
    end

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :stage, PyroManiac.KanBanLanesTest.Stage, public?: true
    end

    actions do
      defaults [:read]
    end

    kan_ban do
      lane :stage do
        destroy_confirm(false)
        move_action(false)
      end

      priority :rank
      move_action(:move_card)
      read_action :kanban_read
    end
  end

  describe "dynamic lanes" do
    test "`move_action false` turns off the lane move" do
      assert Info.lane_action(Chore, :move) == nil
      assert Info.lane_action(Chore, :update) == :update
    end

    test "a belongs_to lane orders the cards by its foreign key" do
      assert Info.dynamic_lanes?(Task)
      assert Info.lane_attribute!(Task) == :stage_id
      assert Info.lane_resource(Task) == Stage
      assert Info.lane_read_action(Task) == :read
      assert Info.manage_lanes?(Task)

      assert %{scope: :stage_id, attribute: :rank, move_action: :move_card} =
               PyroManiac.Ordering.Info.ordering(Task)

      assert :stage_id in Ash.Resource.Info.action(Task, :move_card).accept
    end

    test "the lanes are ordered by the rank of the lane resource" do
      assert Info.lane_sort(Task) == "position"
    end

    test "the lane actions default to the primary actions of the lane resource" do
      assert Info.lane_action(Task, :create) == :create
      assert Info.lane_action(Task, :update) == :update
      assert Info.lane_action(Task, :destroy) == :destroy
    end

    test "the lanes move with the move action of the ordered lane resource" do
      assert Info.lane_action(Task, :move) == :move
      assert Info.lane_action(Job, :move) == :reorder
      assert Info.lane_action(Gig, :move) == nil
      assert Info.lane_action(Brewery.Batch, :move) == nil
    end

    test "the move actions take the target and the placement as public arguments" do
      # A client that runs the action (for example over RPC) gives them as
      # inputs; the context of a changeset is not an input.
      for {resource, action} <- [{Task, :move_card}, {Stage, :move}] do
        arguments = Ash.Resource.Info.action(resource, action).arguments
        target = Enum.find(arguments, &(&1.name == :target_id))
        placement = Enum.find(arguments, &(&1.name == :placement))

        assert %{type: Ash.Type.UUID, public?: true, allow_nil?: true} = target
        assert %{public?: true, default: :last} = placement
        assert placement.constraints[:one_of] == [:before, :after, :last]
      end

      target = Ash.UUID.generate()
      card = struct(Task, id: Ash.UUID.generate(), stage_id: Ash.UUID.generate())

      changeset =
        Ash.Changeset.for_update(card, :move_card, %{target_id: target, placement: "before"},
          authorize?: false
        )

      assert changeset.valid?
      assert inspect(changeset.atomics[:rank]) =~ ~s("#{target}")
      assert inspect(changeset.atomics[:rank]) =~ ~s("before")

      last = Ash.Changeset.for_update(card, :move_card, %{}, authorize?: false)
      assert inspect(last.atomics[:rank]) =~ ~s("last")
    end

    test "the lane move is not the card move" do
      assert Info.move_action!(Task) == :move_card
      assert Info.lane_action(Task, :move) == :move
    end

    test "the delete of a lane says if it asks first" do
      assert Info.lane(Task).destroy_confirm == false

      assert_dsl_error ~r/the board deletes lanes \(`destroy`\), and the lane does not say/ do
        defmodule NoDestroyConfirm do
          use Ash.Resource,
            domain: PyroManiac.KanBanLanesTest.Domain,
            data_layer: AshPostgres.DataLayer,
            extensions: [PyroManiac.KanBan]

          postgres do
            table "pyro_test_no_destroy_confirm"
            repo(Brewery.Repo)
          end

          attributes do
            uuid_primary_key :id
          end

          relationships do
            belongs_to :stage, PyroManiac.KanBanLanesTest.Stage, public?: true
          end

          actions do
            defaults [:read]
          end

          kan_ban do
            lane(:stage)
            priority :rank
            move_action(:move_card)
            read_action :kanban_read
          end
        end
      end
    end

    test "an action of another type for the lane move" do
      assert_dsl_error ~r/`move_action :all` is an action of type `:read`/ do
        defmodule WrongMove do
          use Ash.Resource,
            domain: PyroManiac.KanBanLanesTest.Domain,
            data_layer: AshPostgres.DataLayer,
            extensions: [PyroManiac.KanBan]

          postgres do
            table "pyro_test_wrong_move"
            repo(Brewery.Repo)
          end

          attributes do
            uuid_primary_key :id
          end

          relationships do
            belongs_to :phase, PyroManiac.KanBanLanesTest.Phase, public?: true
          end

          kan_ban do
            lane :phase do
              move_action(:all)
            end

            priority :rank
            move_action(:move_card)
            read_action :kanban_read
          end
        end
      end
    end

    test "explicit lane actions, `false`, and no primary action" do
      assert Info.lane_read_action(Job) == :active
      assert Info.lane_action(Job, :create) == nil
      assert Info.lane_action(Job, :update) == :rename
      assert Info.lane_action(Job, :destroy) == nil
      assert Info.lane_sort(Job) == "name"
      assert Info.manage_lanes?(Job)
    end

    test "an action that the lane resource does not have" do
      assert_dsl_error ~r/`create_action :nope` is not an action of/ do
        defmodule MissingAction do
          use Ash.Resource,
            domain: PyroManiac.KanBanLanesTest.Domain,
            data_layer: AshPostgres.DataLayer,
            extensions: [PyroManiac.KanBan]

          postgres do
            table "pyro_test_missing_action"
            repo(Brewery.Repo)
          end

          attributes do
            uuid_primary_key :id
          end

          relationships do
            belongs_to :stage, PyroManiac.KanBanLanesTest.Stage, public?: true
          end

          kan_ban do
            lane :stage do
              create_action(:nope)
            end

            priority :rank
            move_action(:move_card)
            read_action :kanban_read
          end
        end
      end
    end

    test "an action of another type" do
      assert_dsl_error ~r/`update_action :read` is an action of type `:read`.*but `update_action` is an action of type `:update`/s do
        defmodule WrongType do
          use Ash.Resource,
            domain: PyroManiac.KanBanLanesTest.Domain,
            data_layer: AshPostgres.DataLayer,
            extensions: [PyroManiac.KanBan]

          postgres do
            table "pyro_test_wrong_type"
            repo(Brewery.Repo)
          end

          attributes do
            uuid_primary_key :id
          end

          relationships do
            belongs_to :stage, PyroManiac.KanBanLanesTest.Stage, public?: true
          end

          kan_ban do
            lane :stage do
              update_action(:read)
            end

            priority :rank
            move_action(:move_card)
            read_action :kanban_read
          end
        end
      end
    end

    test "a lane resource without a read action" do
      defmodule Unread do
        @moduledoc false
        use Ash.Resource,
          domain: PyroManiac.KanBanLanesTest.Domain,
          data_layer: AshPostgres.DataLayer

        postgres do
          table "pyro_test_unread"
          repo(Brewery.Repo)
        end

        attributes do
          uuid_primary_key :id
        end

        actions do
          create :add
        end
      end

      assert_dsl_error ~r/it has no primary read action/ do
        defmodule NoRead do
          use Ash.Resource,
            domain: PyroManiac.KanBanLanesTest.Domain,
            data_layer: AshPostgres.DataLayer,
            extensions: [PyroManiac.KanBan]

          postgres do
            table "pyro_test_no_read"
            repo(Brewery.Repo)
          end

          attributes do
            uuid_primary_key :id
          end

          relationships do
            belongs_to :unread, PyroManiac.KanBanLanesTest.Unread, public?: true
          end

          kan_ban do
            lane(:unread)
            priority :rank
            move_action(:move_card)
            read_action :kanban_read
          end
        end
      end
    end

    test "the lane resource" do
      assert PyroManiac.KanBan.Lanes.lanes?(Stage)

      for name <- [:id, :name, :decoration, :position, :project_id],
          do: assert(Ash.Resource.Info.attribute(Stage, name), "no #{name}")

      for name <- [:read, :create, :update, :destroy, :move],
          do: assert(Ash.Resource.Info.action(Stage, name), "no #{name}")

      assert Ash.Resource.Info.action(Stage, :create).accept == [:name, :decoration, :project_id]

      assert %{attribute: :position, scope: :project_id, move_action: :move} =
               PyroManiac.Ordering.Info.ordering(Stage)
    end
  end

  describe "static lanes" do
    test "the values of the attribute" do
      refute Info.dynamic_lanes?(Brewery.Batch)
      assert Info.lane_attribute!(Brewery.Batch) == :status
      assert Info.lane_resource(Brewery.Batch) == nil
      assert Info.lane_sort(Brewery.Batch) == nil

      assert {:ok, [%{value: _value, label: label, record: nil} | _]} = Info.lanes(Brewery.Batch)
      assert is_binary(label)
    end

    test "the options of dynamic lanes are errors" do
      assert_dsl_error ~r/`create_action` is for dynamic lanes/ do
        defmodule StaticManaged do
          use Ash.Resource,
            domain: PyroManiac.KanBanLanesTest.Domain,
            data_layer: AshPostgres.DataLayer,
            extensions: [PyroManiac.KanBan]

          postgres do
            table "pyro_test_static"
            repo(Brewery.Repo)
          end

          attributes do
            uuid_primary_key :id
            attribute :status, :atom, constraints: [one_of: [:open, :done]], public?: true
          end

          kan_ban do
            lane :status do
              create_action(:create)
            end

            priority :rank
            move_action(:move_card)
            read_action :kanban_read
          end
        end
      end
    end

    test "a lane that is neither an attribute nor a belongs_to" do
      assert_dsl_error ~r/neither an attribute nor a `belongs_to`/ do
        defmodule NoLane do
          use Ash.Resource,
            domain: PyroManiac.KanBanLanesTest.Domain,
            data_layer: AshPostgres.DataLayer,
            extensions: [PyroManiac.KanBan]

          postgres do
            table "pyro_test_no_lane"
            repo(Brewery.Repo)
          end

          attributes do
            uuid_primary_key :id
          end

          kan_ban do
            lane(:nope)
            priority :rank
            move_action(:move_card)
            read_action :kanban_read
          end
        end
      end
    end
  end
end
