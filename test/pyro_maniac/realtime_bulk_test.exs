defmodule PyroManiac.RealtimeBulkTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import PyroManiac.Test.DslError

  alias PyroManiac.Realtime.Bulk

  defmodule PubSub do
    @moduledoc false
    def broadcast(topic, event, payload) do
      send(PyroManiac.RealtimeBulkTest, {:broadcast, topic, event, payload})
      :ok
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defmodule Widget do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.RealtimeBulkTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [PyroManiac.Resource]

    pyro_maniac do
      default_label(:name)
      expose([:read, :create, :update, :import, :clear])

      realtime do
        mode(:auto)
        module PyroManiac.RealtimeBulkTest.PubSub
        bulk([:import, :clear, :truncate])
      end
    end

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read, create: [:name], update: [:name]]

      create :import do
        accept [:name]
      end

      destroy :clear
    end
  end

  setup do
    Process.register(self(), __MODULE__)
    :ok
  end

  defp create!(action, name) do
    Widget
    |> Ash.Changeset.for_create(action, %{name: name})
    |> Ash.create!(authorize?: false)
  end

  # The bulk messages come after the window of `BulkCoalescer` (50 ms).
  defp messages do
    receive do
      {:broadcast, topic, event, payload} -> [{topic, event, payload} | messages()]
    after
      200 -> []
    end
  end

  describe ":auto mode with bulk" do
    test "adds the bulk notifier and the record filter" do
      assert PyroManiac.Realtime.BulkNotifier in Ash.Resource.Info.notifiers(Widget)

      for publication <- Ash.Notifier.PubSub.Info.publications(Widget) do
        assert publication.filter == (&PyroManiac.Realtime.record_notification?/1)
      end
    end

    test "subscribes to the bulk topic" do
      assert PyroManiac.Realtime.bulk_topic(Widget) == "realtime_bulk_test_widget:bulk"

      assert "realtime_bulk_test_widget:bulk" in PyroManiac.SubscriptionManager.publication_topics(
               Widget
             )
    end

    test "a bulk operation of a bulk action sends one message and no record notifications" do
      %Ash.BulkResult{status: :success} =
        Ash.bulk_create([%{name: "a"}, %{name: "b"}, %{name: "c"}], Widget, :import,
          notify?: true,
          authorize?: false
        )

      assert [
               {"realtime_bulk_test_widget:bulk", "bulk",
                %Bulk{resource: Widget, event: :import, type: :create}}
             ] = messages()
    end

    test "two bulk operations inside the window give one message" do
      Ash.bulk_create([%{name: "a"}], Widget, :import, notify?: true, authorize?: false)
      Ash.bulk_create([%{name: "b"}], Widget, :import, notify?: true, authorize?: false)

      assert [{_, "bulk", %Bulk{}}] = messages()
    end

    test "bulk operations after the window give a message each" do
      Ash.bulk_create([%{name: "a"}], Widget, :import, notify?: true, authorize?: false)
      assert [{_, "bulk", %Bulk{}}] = messages()

      Ash.bulk_create([%{name: "b"}], Widget, :import, notify?: true, authorize?: false)
      assert [{_, "bulk", %Bulk{}}] = messages()
    end

    test "a bulk operation with batches gives one message" do
      Ash.bulk_create(Enum.map(1..25, &%{name: "w#{&1}"}), Widget, :import,
        notify?: true,
        authorize?: false,
        batch_size: 10,
        return_stream?: true
      )
      |> Stream.run()

      assert [{_, "bulk", %Bulk{event: :import}}] = messages()
    end

    test "a bulk destroy sends one message" do
      create!(:create, "a")
      create!(:create, "b")
      messages()

      %Ash.BulkResult{status: :success} =
        Ash.bulk_destroy(Widget, :clear, %{},
          notify?: true,
          authorize?: false,
          strategy: [:stream]
        )

      assert [{_, "bulk", %Bulk{event: :clear, type: :destroy}}] = messages()
    end

    test "a call of a bulk action for one record sends its record notification" do
      create!(:import, "a")

      assert [{"realtime_bulk_test_widget:*", "import", %Ash.Notifier.Notification{}}] =
               messages()
    end

    test "a bulk operation of an action that is not in bulk sends the record notifications" do
      Ash.bulk_create([%{name: "a"}, %{name: "b"}], Widget, :create,
        notify?: true,
        authorize?: false
      )

      assert [
               {_, "create", %Ash.Notifier.Notification{}},
               {_, "create", %Ash.Notifier.Notification{}}
             ] = messages()
    end

    test "broadcast_bulk/3 sends an event of bulk" do
      PyroManiac.Realtime.broadcast_bulk(Widget, :truncate)

      assert [{"realtime_bulk_test_widget:bulk", "bulk", %Bulk{event: :truncate, type: nil}}] =
               messages()
    end

    test "broadcast_bulk/3 refuses an event that is not in bulk" do
      assert_raise ArgumentError, ~r/:purge is not in `bulk`/, fn ->
        PyroManiac.Realtime.broadcast_bulk(Widget, :purge)
      end
    end
  end

  describe "SubscriptionManager.handle_notification/2 with a bulk message" do
    test "obeys on_bulk" do
      bulk = %Bulk{resource: Widget, event: :import}
      handle = &PyroManiac.SubscriptionManager.handle_notification/2

      assert handle.(bulk, %{on_bulk: :reload}) == :reload
      assert handle.(%{payload: bulk}, %{on_bulk: :notify}) == {:notify, :bulk}
      assert handle.(bulk, %{on_bulk: :none}) == :ignore
      assert handle.(bulk, %{}) == :ignore
    end
  end

  describe "the resource verifier" do
    test "an action in bulk and in except" do
      output =
        capture_io(:stderr, fn ->
          defmodule BulkAndExcept do
            use Ash.Resource,
              domain: nil,
              data_layer: Ash.DataLayer.Ets,
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label(:name)

              realtime do
                mode(:auto)
                module PyroManiac.RealtimeBulkTest.PubSub
                except [:import]
                bulk([:import])
              end
            end

            attributes do
              uuid_primary_key :id
              attribute :name, :string, public?: true
            end

            actions do
              defaults [:read]
              create :import
            end
          end
        end)

      assert output =~ ":import is in `bulk` and in `except`"
    end

    test "a bulk action in :validate mode without the bulk notifier" do
      output =
        capture_io(:stderr, fn ->
          defmodule BulkWithoutNotifier do
            use Ash.Resource,
              domain: nil,
              data_layer: Ash.DataLayer.Ets,
              notifiers: [Ash.Notifier.PubSub],
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label(:name)

              realtime do
                bulk([:import])
              end
            end

            pub_sub do
              module PyroManiac.RealtimeBulkTest.PubSub
              prefix "bulk_without_notifier"
              publish_all :create, ["*"], filter: &PyroManiac.Realtime.record_notification?/1
            end

            attributes do
              uuid_primary_key :id
              attribute :name, :string, public?: true
            end

            actions do
              defaults [:read]
              create :import
            end
          end
        end)

      assert output =~ "does not use `PyroManiac.Realtime.BulkNotifier`"
    end

    test "a publication of a bulk action in :validate mode without the record filter" do
      output =
        capture_io(:stderr, fn ->
          defmodule BulkWithoutFilter do
            use Ash.Resource,
              domain: nil,
              data_layer: Ash.DataLayer.Ets,
              notifiers: [Ash.Notifier.PubSub, PyroManiac.Realtime.BulkNotifier],
              extensions: [PyroManiac.Resource]

            pyro_maniac do
              default_label(:name)

              realtime do
                bulk([:import])
              end
            end

            pub_sub do
              module PyroManiac.RealtimeBulkTest.PubSub
              prefix "bulk_without_filter"
              publish_all :create, ["*"]
            end

            attributes do
              uuid_primary_key :id
              attribute :name, :string, public?: true
            end

            actions do
              defaults [:read]
              create :import
            end
          end
        end)

      assert output =~ "a publication of :import (in `bulk`) has no filter"
    end
  end

  defmodule Partial do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      notifiers: [Ash.Notifier.PubSub],
      extensions: [PyroManiac.Resource]

    pyro_maniac do
      default_label(:name)
      expose([:read, :create])

      realtime do
        except [:create]
      end
    end

    pub_sub do
      module PyroManiac.RealtimeBulkTest.PubSub
      prefix "partial"
      publish_all :update, ["*"]
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read, :destroy, create: [:name], update: [:name]]
      update :rename, accept: [:name]
    end
  end

  defmodule Unpublished do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      notifiers: [Ash.Notifier.PubSub],
      extensions: [PyroManiac.Resource]

    pyro_maniac do
      default_label(:name)
      expose([:read, :update])

      realtime do
        mode(:validate)
      end
    end

    pub_sub do
      module PyroManiac.RealtimeBulkTest.PubSub
      prefix "unpublished"
      publish :rename, ["*"]
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read, update: [:name]]
      update :rename, accept: [:name]
    end
  end

  describe "the page" do
    test "an exposed action of the type that is not published" do
      assert_dsl_error ~r/`on_update :replace` misses the changes of the exposed action :update/ do
        defmodule UnpublishedPage do
          use PyroManiac, resource: PyroManiac.RealtimeBulkTest.Unpublished

          view :read do
            type :data_table
            primary? true
            on_update :replace
            exclude [:id]
            column :name
          end

          view :read do
            type :card

            primary? true

            section :main do
              field :name
            end
          end

          page do
            route "/test"
            exclude [:update]
          end
        end
      end
    end

    test "no action of the type is published" do
      assert_dsl_error ~r/`on_destroy :remove` has no effect: no destroy action/ do
        defmodule NoDestroyPage do
          use PyroManiac, resource: PyroManiac.RealtimeBulkTest.Partial

          view :read do
            type :data_table
            primary? true
            on_destroy :remove
            exclude [:id]
            column :name
          end

          view :read do
            type :card

            primary? true

            section :main do
              field :name
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "an exposed action in except is not an error" do
      defmodule ExceptPage do
        use PyroManiac, resource: PyroManiac.RealtimeBulkTest.Partial

        view :read do
          type :data_table
          primary? true
          on_update :replace
          exclude [:id]
          column :name
        end

        view :read do
          type :card

          primary? true

          section :main do
            field :name
          end
        end

        page do
          route "/test"
          exclude [:create]
        end
      end

      assert %{on_update: :replace, on_bulk: :none} =
               PyroManiac.Info.primary_list_view(ExceptPage)
    end

    test "on_bulk without bulk" do
      assert_dsl_error ~r/`on_bulk :reload` has no effect: .* has no `bulk`/ do
        defmodule NoBulkPage do
          use PyroManiac, resource: PyroManiac.RealtimeBulkTest.Partial

          view :read do
            type :data_table
            primary? true
            on_bulk(:reload)
            exclude [:id]
            column :name
          end

          view :read do
            type :card

            primary? true

            section :main do
              field :name
            end
          end

          page do
            route "/test"
            exclude [:create]
          end
        end
      end
    end

    test "on_bulk with bulk" do
      defmodule BulkPage do
        use PyroManiac, resource: PyroManiac.RealtimeBulkTest.Widget

        view :read do
          type :data_table
          primary? true
          on_bulk(:reload)
          on_create :reload
          exclude [:id]
          column :name
        end

        view :read do
          type :card

          primary? true

          section :main do
            field :name
          end
        end

        page do
          route "/test"
          exclude [:create, :update, :import, :clear]
        end
      end

      assert %{on_bulk: :reload} = PyroManiac.Info.primary_list_view(BulkPage)
      assert PyroManiac.SubscriptionManager.has_realtime?(BulkPage)
    end
  end
end
