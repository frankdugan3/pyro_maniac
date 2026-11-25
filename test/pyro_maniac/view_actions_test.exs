defmodule PyroManiac.ViewActionsTest do
  @moduledoc false
  # The actions of the views: the tree of a card for its actions, the
  # actions of a list view (their own tree, `delegate_to`, a confirmation),
  # `only` with action names, bulk actions, and the actions of the page.
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  alias PyroManiac.{Card, Info}
  alias PyroManiac.Form.{Action, BulkAction, Tree}

  @recipe_fields [
    :id,
    :recipe_ingredients,
    :batches,
    :photos,
    :photos_urls,
    :description,
    :target_abv,
    :target_og,
    :target_fg,
    :gravity_spread,
    :ingredient_count,
    :batch_count
  ]

  defmodule RecipePage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    page do
      route "/test"
      exclude [:list]
    end

    view :read do
      type :data_table
      primary? true

      exclude [
        :id,
        :recipe_ingredients,
        :batches,
        :photos,
        :photos_urls,
        :description,
        :target_abv,
        :target_og,
        :target_fg,
        :gravity_spread,
        :ingredient_count,
        :batch_count
      ]

      column :name
      column :style
      column :status

      # The tree of the card of this page.
      action :create do
        state :guard
        delegate_to PyroManiac.ViewActionsTest.RecipePage
      end

      # No inputs: a confirmation, or `confirm false`.
      action :destroy, :guard do
        confirm "Delete the recipe?"
      end

      action :activate, :guard do
        confirm false
      end

      action :retire do
        state :guard
        presentation :drawer
        label "Retire recipe"
        confirm "Retire the recipe?"
      end

      bulk_action :update do
        state :guard
        select :status, autofocus: true
      end
    end

    view :read do
      type :card
      primary? true
      action [:create, :update], :guard

      section :recipe do
        field :name, autofocus: true
        select :style
        select :status
        field :gravity_spread
        field :batch_count, only: [:read]
      end

      section :targets do
        field :target_abv
        field :target_og
        field :target_fg
        field :description, type: :textarea, only: [:create, :update]
      end
    end
  end

  defp names(tree), do: tree |> Tree.values() |> Enum.map(& &1.name)

  describe "the actions of a page" do
    test "one entity for each action name and view" do
      keys = for %Action{} = a <- Info.actions(RecipePage), do: {a.name, a.__view__}

      assert {:create, {:read, :card}} in keys
      assert {:update, {:read, :card}} in keys
      assert {:create, {:read, :data_table}} in keys
      assert {:destroy, {:read, :data_table}} in keys
      assert {:activate, {:read, :data_table}} in keys
      assert {:retire, {:read, :data_table}} in keys
    end

    test "the actions of a card come first" do
      assert %Action{name: :create, __view__: {:read, :card}} =
               Info.action_for(RecipePage, :create)
    end

    test "the actions of a view, and whether it is editable" do
      table = Info.view_for(RecipePage, :read, :data_table)
      card = Info.primary_single_view(RecipePage)

      assert card."__editable?__"
      assert Enum.sort(card.__actions__) == [:create, :update]
      assert Enum.sort(table.__actions__) == [:activate, :create, :destroy, :retire, :update]

      assert Info.actions(RecipePage, card) |> Enum.map(& &1.name) |> Enum.sort() ==
               [:create, :update]
    end

    test "delegate_to this page uses the tree of the card" do
      list_create =
        Enum.find(
          Info.actions(RecipePage),
          &(&1.__view__ == {:read, :data_table} and &1.name == :create)
        )

      assert names(list_create.fields) == names(Info.action_for(RecipePage, :create).fields)
    end

    test "an action without inputs has no tree" do
      actions = Info.actions(RecipePage, Info.view_for(RecipePage, :read, :data_table))

      assert %Action{fields: []} = Enum.find(actions, &(&1.name == :destroy))

      assert %Action{fields: [], presentation: :drawer, label: "Retire recipe"} =
               Enum.find(actions, &(&1.name == :retire))
    end

    test "a bulk action of a list view" do
      assert [%BulkAction{name: :update, __view__: {:read, :data_table}}] =
               Info.bulk_actions(RecipePage)
    end

    test "the title defaults to the name of the resource" do
      assert Info.title(RecipePage) =~ "Recipe"
    end

    test "presence is off by default" do
      refute Info.track_presence?(RecipePage)
    end
  end

  describe "only" do
    test "the read action is view mode; the actions have their own nodes" do
      view = RecipePage |> Card.tree() |> names()
      update = RecipePage |> Info.action_for(:update) |> Map.fetch!(:fields) |> names()

      assert :batch_count in view
      refute :description in view
      refute :batch_count in update
      assert :description in update
    end

    test "only names an action of the tree" do
      assert_dsl_error ~r/`only` has :retire, which is not an action of this tree/ do
        defmodule OnlyUnknown do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :card
            primary? true
            action :update, :guard

            field :name, autofocus: true
            select :style
            select :status
            field :description
            field :target_abv
            field :target_og, only: [:retire]
            field :target_fg
          end
        end
      end
    end
  end

  describe "the transitions of a card" do
    defmodule TransitionCardPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      page do
        route "/test"
        exclude [:list, :destroy]
      end

      view :read do
        type :data_table
        primary? true

        exclude [
          :id,
          :recipe_ingredients,
          :batches,
          :photos,
          :photos_urls,
          :description,
          :target_abv,
          :target_og,
          :target_fg,
          :gravity_spread,
          :ingredient_count,
          :batch_count
        ]

        column :name
        column :style
        column :status
      end

      view :read do
        type :card
        primary? true
        action [:create, :update], :guard

        action :activate do
          state :discard
          confirm "Activate?"
        end

        action :retire do
          state :discard
          confirm false
        end

        section :recipe do
          field :name, autofocus: true
          select :style
          select :status
        end

        section :targets do
          field :target_abv
          field :target_og
          field :target_fg
          field :description, type: :textarea, only: [:create, :update]
        end
      end
    end

    test "a select on an attribute that the action does not accept is read-only" do
      actions = Map.new(Card.actions(TransitionCardPage), &{&1.name, &1})

      assert [] = Tree.inputs(actions[:activate].fields)
      assert [:name, :style, :status | _] = names(actions[:activate].fields)
      assert Enum.all?(Tree.values(actions[:activate].fields), &Tree.read_only?/1)

      assert [:name, :style, :status | _] =
               actions[:update].fields |> Tree.inputs() |> Enum.map(& &1.name)

      assert actions[:retire].confirm == false
    end

    test "an action of a card without an input sets `confirm`" do
      assert_dsl_error ~r/action of the card :activate has no input, so.*`confirm false`/s do
        defmodule TransitionNoConfirm do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:list, :destroy, :retire]
          end

          view :read do
            type :data_table
            primary? true
            exclude unquote(@recipe_fields)
            column :name
            column :style
            column :status
          end

          view :read do
            type :card
            primary? true
            action [:create, :update, :activate], :guard

            section :recipe do
              field :name, autofocus: true
              select :status
            end
          end
        end
      end
    end
  end

  describe "no confirmation by default" do
    test "an action of a list view without an input sets `confirm`" do
      assert_dsl_error ~r/action :activate has no input, so its button runs it at once/ do
        defmodule ListNoConfirm do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :retire, :destroy, :list]
          end

          view :read do
            type :data_table
            primary? true
            exclude unquote(@recipe_fields)
            column :name
            column :style
            column :status
            action :activate, :guard
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end

    test "a bulk action without an input sets `confirm`" do
      assert_dsl_error ~r/bulk action :destroy has no input/ do
        defmodule BulkNoConfirm do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :retire, :activate, :list]
          end

          view :read do
            type :data_table
            primary? true
            exclude unquote(@recipe_fields)
            column :name
            column :style
            column :status

            action :destroy, :guard do
              confirm "Delete?"
            end

            bulk_action :destroy, :guard
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end
  end

  describe "the checks of the actions" do
    test "an action with inputs in a list view has a tree or delegate_to" do
      assert_dsl_error ~r/`action :update` in a :data_table view has no form/ do
        defmodule ListActionNoTree do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :data_table
            primary? true
            exclude unquote(@recipe_fields)
            column :name
            column :style
            column :status
            action :update, :guard
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end

    test "a view without a write action has no inputs" do
      assert_dsl_error ~r/:style is an input, but the view names no write action/ do
        defmodule InputWithoutAction do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
              select :style
            end
          end
        end
      end
    end

    test "an exposed action is used by a view or excluded" do
      assert_dsl_error ~r/the exposed actions \[:destroy\] of Brewery.Recipe are not used/ do
        defmodule DestroyNotUsed do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :list]
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end
  end

  describe "the arguments of a read action" do
    # Regression: the inputs of the public arguments of a read action were
    # built at the removed `[:forms, :action]` path, so the page crashed.
    test "a view of a read action with a public argument" do
      defmodule KanbanPage do
        use PyroManiac, resource: Brewery.Batch

        page do
          route "/test"

          exclude [
            :create,
            :update,
            :start_brewing,
            :advance_status,
            :complete,
            :destroy,
            :list,
            :read
          ]
        end

        view :kanban_read do
          type :kanban
          primary? true
          field :batch_number
        end

        view :kanban_read do
          type :card
          primary? true

          section :main do
            field :batch_number
          end
        end
      end

      view = Info.primary_list_view(KanbanPage)
      assert [%{name: :lane_value, description: description}] = view.__arguments__
      # Regression: the description of an argument input was a string.
      assert [%PyroManiac.Description{kind: :text}] = description
    end
  end

  describe "regressions" do
    # A bulk action did not count as a use of its action (its entity has no
    # `resource`), so a bulk-only action was reported as unused.
    test "a bulk action uses its action" do
      defmodule BulkOnlyPage do
        use PyroManiac, resource: Brewery.Recipe

        page do
          route "/test"
          exclude [:create, :activate, :retire, :destroy, :list]
        end

        view :read do
          type :data_table
          primary? true
          exclude unquote(@recipe_fields)
          column :name
          column :style
          column :status

          bulk_action :update do
            state :guard
            select :status, autofocus: true
          end
        end

        view :read do
          type :card
          primary? true

          section :main do
            field :name
          end
        end
      end

      assert [%BulkAction{name: :update}] = Info.bulk_actions(BulkOnlyPage)
    end

    # The `action` of a column took the options and the nodes of a full
    # action; an inline edit has inputs only.
    test "the action of a column has inputs only" do
      assert_dsl_error ~r/an inline edit has inputs only: `section`/ do
        defmodule ColumnActionSection do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :data_table
            primary? true
            exclude unquote(@recipe_fields)
            column :name
            column :style

            column :status do
              action :update do
                state :guard

                section :status do
                  select :status, autofocus: true
                end
              end
            end
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end
  end
end
