Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.SurfaceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import PyroManiac.Test.DslError

  doctest PyroManiac.Surface
  doctest PyroManiac.Realtime
  doctest PyroManiac.Domain.Typescript

  defmodule Thing do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      extensions: [PyroManiac.Resource]

    pyro_maniac do
      default_label :name

      expose :read do
        loads [:name, :code, owner: [:name]]
        filter [:name, owner: [:name]]
        sort [:name]
      end

      expose [:create, :update]
    end

    attributes do
      uuid_primary_key :id, public?: true
      attribute :name, :string, public?: true
      attribute :code, :string, public?: true
      attribute :note, :string, public?: true
      attribute :secret, :string
    end

    relationships do
      belongs_to :owner, Brewery.Staff, public?: true
    end

    actions do
      default_accept [:name, :code]
      defaults [:read, :create, :update, :destroy]
    end
  end

  describe ":*" do
    defmodule StarThing do
      @moduledoc false
      use Ash.Resource,
        domain: nil,
        data_layer: Ash.DataLayer.Ets,
        extensions: [PyroManiac.Resource]

      pyro_maniac do
        default_label :name

        expose :read

        expose :list do
          sort [:name]
        end

        expose :search do
          filter []
          sort []
        end

        expose :with_owner do
          loads [:*, :owner]
          filter [:name, owner: [:*]]
          sort owner: [:name]
        end

        expose [:create, :update]
      end

      attributes do
        uuid_primary_key :id, public?: true
        attribute :name, :string, public?: true
        attribute :secret, :string
      end

      relationships do
        belongs_to :owner, Brewery.Staff, public?: true
      end

      calculations do
        calculate :name_length, :integer, expr(string_length(name)), public?: true
      end

      actions do
        defaults [:read, create: [:name], update: [:name]]
        read :list
        read :search
        read :with_owner
      end
    end

    @fields [:id, :name, :owner_id, :name_length]

    test "each option defaults to :*" do
      assert %{loads: @fields, filter: @fields, sort: @fields} =
               PyroManiac.Resource.Info.exposed(StarThing, :read)
    end

    test "an option that is set stays, the others are :*" do
      assert %{loads: @fields, filter: @fields, sort: [:name]} =
               PyroManiac.Resource.Info.exposed(StarThing, :list)
    end

    test ":* in a list, and a relationship atom is the relationship with :* of its resource" do
      staff = PyroManiac.Resource.Info.public_fields(Brewery.Staff)
      staff_filter = PyroManiac.Resource.Info.public_fields(Brewery.Staff, :filter)

      assert %{
               loads: [:id, :name, :owner_id, :name_length, owner: ^staff],
               filter: [:name, owner: ^staff_filter],
               sort: [owner: [:name]]
             } = PyroManiac.Resource.Info.exposed(StarThing, :with_owner)
    end

    test "in filter and sort, :* keeps the sensitive fields" do
      assert :email in PyroManiac.Resource.Info.public_fields(Brewery.Staff, :filter)
      assert :email in PyroManiac.Resource.Info.public_fields(Brewery.Staff, :sort)
    end

    defmodule PinThing do
      @moduledoc false
      use Ash.Resource,
        domain: nil,
        data_layer: Ash.DataLayer.Ets,
        extensions: [PyroManiac.Resource]

      pyro_maniac do
        default_label :name
        expose :read
      end

      attributes do
        uuid_primary_key :id, public?: true
        attribute :name, :string, public?: true
        attribute :pin, :string, public?: true, filterable?: false, sortable?: false
      end

      actions do
        defaults [:read]
      end
    end

    test "in filter and sort, :* has no field that Ash cannot filter or sort" do
      assert %{loads: loads, filter: filter, sort: sort} =
               PyroManiac.Resource.Info.exposed(PinThing, :read)

      assert :pin in loads
      refute :pin in filter
      refute :pin in sort
    end

    test "an explicit field that Ash cannot filter" do
      output =
        capture_io(:stderr, fn ->
          defmodule FilterPin do
            use Ash.Resource,
              domain: nil,
              data_layer: :embedded,
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label :name

              expose :read do
                filter [:name, :pin]
              end
            end

            attributes do
              attribute :name, :string, public?: true
              attribute :pin, :string, public?: true, filterable?: false
            end

            actions do
              defaults [:read]
            end
          end
        end)

      assert output =~ ":filter has pin: :pin is not filterable"
    end

    test ":* is the fields of the resource, not its relationships" do
      %{loads: loads} = PyroManiac.Resource.Info.exposed(StarThing, :read)
      refute Enum.any?(loads, &match?({:owner, _}, &1))
      refute :owner in loads
    end

    test "[] opts out" do
      assert %{loads: @fields, filter: [], sort: []} =
               PyroManiac.Resource.Info.exposed(StarThing, :search)
    end

    test "filter and sort are only for read actions" do
      for action <- [:create, :update] do
        assert %{loads: @fields, filter: [], sort: []} =
                 PyroManiac.Resource.Info.exposed(StarThing, action)
      end
    end
  end

  describe "PyroManiac.Resource.Info" do
    test "exposed/1 gives one entity for each action" do
      assert [:read, :create, :update] =
               Thing |> PyroManiac.Resource.Info.exposed() |> Enum.map(& &1.name)
    end

    test "exposed/2 gives the entity of an action, or nil" do
      assert %{loads: [:name, :code, owner: [:name]]} =
               PyroManiac.Resource.Info.exposed(Thing, :read)

      assert PyroManiac.Resource.Info.exposed(Thing, :destroy) == nil
      refute PyroManiac.Resource.Info.realtime?(Thing)
    end
  end

  describe "restrict_filter/3" do
    test "keeps only the exposed filter fields, at each level" do
      filter = %{
        "name" => %{"contains" => "a"},
        "code" => %{"eq" => "x"},
        "owner" => %{"name" => %{"eq" => "b"}, "email" => %{"eq" => "c"}},
        "or" => [%{"code" => %{"eq" => "y"}}, %{"name" => %{"eq" => "z"}}]
      }

      assert PyroManiac.Surface.restrict_filter(Thing, :read, filter) == %{
               "name" => %{"contains" => "a"},
               "owner" => %{"name" => %{"eq" => "b"}},
               "or" => [%{}, %{"name" => %{"eq" => "z"}}]
             }
    end

    test "gives nil for nil" do
      assert PyroManiac.Surface.restrict_filter(Thing, :read, nil) == nil
    end
  end

  describe "restrict_sort_input/3" do
    test "keeps only the exposed sort fields" do
      assert PyroManiac.Surface.restrict_sort_input(Thing, :read, "-name,code,owner.name") ==
               "-name"
    end

    test "gives nil when no field stays" do
      assert PyroManiac.Surface.restrict_sort_input(Thing, :read, "code") == nil
    end
  end

  describe "the page" do
    test "an action that is not exposed" do
      assert_dsl_error ~r/action :destroy of PyroManiac.SurfaceTest.Thing is used here, but it is not exposed/ do
        defmodule DestroyPage do
          use PyroManiac, resource: PyroManiac.SurfaceTest.Thing

          page do
            title "Things"
          end

          forms do
            exclude [:create, :update]
            bulk_action :destroy
          end
        end
      end
    end

    test "a load that is not exposed" do
      assert_dsl_error ~r/\[:note\] is used here, but it is not in `loads` of `expose :read`/ do
        defmodule NotePage do
          use PyroManiac, resource: PyroManiac.SurfaceTest.Thing

          page do
            title "Things"
          end

          views do
            view :read do
              type :grid

              section "Main" do
                field :name
                field :note
              end
            end
          end
        end
      end
    end

    test "a field exclude that is not exposed" do
      assert_dsl_error ~r/`exclude` has :id, which is not an exposed field/ do
        defmodule ExcludePage do
          use PyroManiac, resource: PyroManiac.SurfaceTest.Thing

          page do
            title "Things"
          end

          views do
            view :read do
              type :data_table
              exclude [:id, :owner, :code]
              column :name
            end
          end
        end
      end
    end

    test "an action exclude that is not exposed" do
      assert_dsl_error ~r/`exclude` has :destroy, which is not an exposed :create or :update action/ do
        defmodule FormExcludePage do
          use PyroManiac, resource: PyroManiac.SurfaceTest.Thing

          page do
            title "Things"
          end

          forms do
            exclude [:destroy, :update]

            action :create do
              field :name, autofocus: true
              field :code
            end
          end
        end
      end
    end
  end

  describe "the resource verifiers" do
    test "an action that does not exist" do
      output =
        capture_io(:stderr, fn ->
          defmodule UnknownAction do
            use Ash.Resource,
              domain: nil,
              data_layer: :embedded,
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label :name
              expose :reed
            end

            attributes do
              attribute :name, :string, public?: true
            end

            actions do
              defaults [:read]
            end
          end
        end)

      assert output =~ "action :reed does not exist"
    end

    test "a field that is not public" do
      output =
        capture_io(:stderr, fn ->
          defmodule PrivateField do
            use Ash.Resource,
              domain: nil,
              data_layer: :embedded,
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label :name

              expose :read do
                loads [:secret]
              end
            end

            attributes do
              attribute :name, :string, public?: true
              attribute :secret, :string
            end

            actions do
              defaults [:read]
            end
          end
        end)

      assert output =~ ":loads has secret: :secret is not public"
    end

    test "filter on an action that is not a read" do
      output =
        capture_io(:stderr, fn ->
          defmodule FilterOnCreate do
            use Ash.Resource,
              domain: nil,
              data_layer: :embedded,
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label :name

              expose :create do
                filter [:name]
              end
            end

            attributes do
              attribute :name, :string, public?: true
            end

            actions do
              defaults [:read, create: [:name]]
            end
          end
        end)

      assert output =~ "`filter` and `sort` are only for read actions"
    end

    test "an action that is exposed twice" do
      output =
        capture_io(:stderr, fn ->
          defmodule ExposedTwice do
            use Ash.Resource,
              domain: nil,
              data_layer: :embedded,
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label :name
              expose :read
              expose [:read]
            end

            attributes do
              attribute :name, :string, public?: true
            end

            actions do
              defaults [:read]
            end
          end
        end)

      assert output =~ "action :read is exposed more than once"
    end

    test "realtime :validate without Ash.Notifier.PubSub" do
      output =
        capture_io(:stderr, fn ->
          defmodule ValidateWithoutNotifier do
            use Ash.Resource,
              domain: nil,
              data_layer: Ash.DataLayer.Ets,
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label :name

              realtime do
                mode :validate
              end
            end

            attributes do
              uuid_primary_key :id
              attribute :name, :string, public?: true
            end

            actions do
              defaults [:read]
            end
          end
        end)

      assert output =~ "it does not use `Ash.Notifier.PubSub`"
    end

    test "realtime: an exposed action that sends no notification" do
      output =
        capture_io(:stderr, fn ->
          defmodule Uncovered do
            use Ash.Resource,
              domain: nil,
              data_layer: Ash.DataLayer.Ets,
              notifiers: [Ash.Notifier.PubSub],
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label :name
              expose [:create, :update]

              realtime do
                mode :validate
              end
            end

            pub_sub do
              module PyroManiac.SurfaceTest
              prefix "uncovered"
              publish_all :create, ["*"]
            end

            attributes do
              uuid_primary_key :id
              attribute :name, :string, public?: true
            end

            actions do
              defaults [:read, create: [:name], update: [:name]]
            end
          end
        end)

      assert output =~ "action :update is exposed, but no publication with a static topic"
    end
  end

  describe "realtime :auto" do
    defmodule AutoRealtime do
      @moduledoc false
      use Ash.Resource,
        domain: nil,
        data_layer: Ash.DataLayer.Ets,
        extensions: [PyroManiac.Resource]

      pyro_maniac do
        default_label :name
        expose [:create, :update, :punch]

        realtime do
          mode :auto
          module PyroManiac.SurfaceTest
          except [:punch]
        end
      end

      attributes do
        uuid_primary_key :id
        attribute :name, :string, public?: true
      end

      actions do
        defaults [:read, :destroy, create: [:name], update: [:name]]

        create :punch do
          accept [:name]
        end
      end
    end

    test "adds the notifier, the options, and the publications" do
      assert Ash.Notifier.PubSub in Ash.Resource.Info.notifiers(AutoRealtime)
      assert Ash.Notifier.PubSub.Info.module(AutoRealtime) == PyroManiac.SurfaceTest
      assert Ash.Notifier.PubSub.Info.prefix(AutoRealtime) == "surface_test_auto_realtime"
      assert Ash.Notifier.PubSub.Info.broadcast_type(AutoRealtime) == :notification

      assert [
               {:create, ["*"], [:punch]},
               {:update, ["*"], [:punch]},
               {:destroy, ["*"], [:punch]},
               {:update, ["updated", [:id, nil]], [:punch]},
               {:destroy, ["destroyed", [:id, nil]], [:punch]}
             ] =
               AutoRealtime
               |> Ash.Notifier.PubSub.Info.publications()
               |> Enum.map(&{&1.type, &1.topic, &1.except})
    end

    test "the topics for the subscriptions and for app code" do
      assert PyroManiac.Realtime.topic(AutoRealtime, "*") == "surface_test_auto_realtime:*"

      assert PyroManiac.SubscriptionManager.publication_topics(AutoRealtime) == [
               "surface_test_auto_realtime:*"
             ]

      assert PyroManiac.Resource.Info.realtime_mode(AutoRealtime) == :auto
    end
  end

  describe "PyroManiac.Domain.Typescript :auto" do
    defmodule TsOwner do
      @moduledoc false
      use Ash.Resource,
        domain: nil,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshTypescript.Resource]

      typescript do
        type_name("SurfaceTestTsOwner")
      end

      attributes do
        uuid_primary_key :id, public?: true
        attribute :name, :string, public?: true
      end

      actions do
        defaults [:read]
      end
    end

    defmodule TsThing do
      @moduledoc false
      use Ash.Resource,
        domain: nil,
        data_layer: Ash.DataLayer.Ets,
        extensions: [PyroManiac.Resource, AshTypescript.Resource]

      typescript do
        type_name("SurfaceTestTsThing")
      end

      pyro_maniac do
        default_label :name

        expose :read do
          loads [:name, :name_length, owner: [:name]]
          filter [:name]
          sort []
        end

        expose [:create, :archive]
      end

      attributes do
        uuid_primary_key :id, public?: true
        attribute :name, :string, public?: true
      end

      relationships do
        belongs_to :owner, PyroManiac.SurfaceTest.TsOwner, public?: true
      end

      calculations do
        calculate :name_length, :integer, expr(string_length(name)), public?: true
      end

      actions do
        defaults [:read, create: [:name]]

        update :archive do
          accept []
        end
      end
    end

    defmodule TsDomain do
      @moduledoc false
      use Ash.Domain,
        extensions: [PyroManiac.Domain.Typescript],
        validate_config_inclusion?: false

      pyro_maniac_typescript do
        mode :auto
      end

      typescript_rpc do
        resource PyroManiac.SurfaceTest.TsThing do
          rpc_action(:make_ts_thing, :create, description: "Written.")
        end
      end

      resources do
        resource PyroManiac.SurfaceTest.TsThing
        resource PyroManiac.SurfaceTest.TsOwner
      end
    end

    test "lists each resource with AshTypescript.Resource, also with no exposed action" do
      assert %{rpc_actions: []} =
               TsDomain
               |> AshTypescript.Rpc.Info.typescript_rpc()
               |> Enum.find(&(&1.resource == TsOwner))
    end

    test "a load that reaches a resource with no TypeScript types" do
      output =
        capture_io(:stderr, fn ->
          defmodule BareOwner do
            use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets

            attributes do
              uuid_primary_key :id, public?: true
              attribute :name, :string, public?: true
            end

            actions do
              defaults [:read]
            end
          end

          defmodule OwnedThing do
            use Ash.Resource,
              domain: nil,
              data_layer: Ash.DataLayer.Ets,
              extensions: [PyroManiac.Resource, AshTypescript.Resource]

            typescript do
              type_name("SurfaceTestOwnedThing")
            end

            pyro_maniac do
              default_label :id

              expose :read do
                loads [:id, owner: [:name]]
              end
            end

            attributes do
              uuid_primary_key :id, public?: true
            end

            relationships do
              belongs_to :owner, PyroManiac.SurfaceTest.BareOwner, public?: true
            end

            actions do
              defaults [:read]
            end
          end

          defmodule OwnedDomain do
            use Ash.Domain,
              extensions: [PyroManiac.Domain.Typescript],
              validate_config_inclusion?: false

            pyro_maniac_typescript do
              mode :auto
            end

            resources do
              resource PyroManiac.SurfaceTest.OwnedThing
              resource PyroManiac.SurfaceTest.BareOwner
            end
          end
        end)

      assert output =~
               "reaches PyroManiac.SurfaceTest.BareOwner (owner), which has no TypeScript types"
    end

    test "adds an rpc action for each exposed action without a written one" do
      rpc_actions =
        TsDomain
        |> AshTypescript.Rpc.Info.typescript_rpc()
        |> Enum.flat_map(& &1.rpc_actions)
        |> Map.new(&{&1.name, &1})

      assert Map.keys(rpc_actions) |> Enum.sort() ==
               [:list_surface_test_ts_things, :make_ts_thing, :surface_test_ts_thing_archive]

      list = rpc_actions[:list_surface_test_ts_things]
      assert list.action == :read
      assert list.allowed_loads == [:name_length, :owner]
      assert list.enable_filter?
      refute list.enable_sort?

      assert rpc_actions[:make_ts_thing].description == "Written."
    end

    test "rpc_name/3 gives the written or the generated name" do
      assert PyroManiac.Domain.Typescript.Info.rpc_name(TsThing, :create, TsDomain) ==
               :make_ts_thing

      assert PyroManiac.Domain.Typescript.Info.rpc_name(TsThing, :archive, TsDomain) ==
               :surface_test_ts_thing_archive
    end
  end
end
