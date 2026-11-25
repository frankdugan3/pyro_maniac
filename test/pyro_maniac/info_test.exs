defmodule PyroManiac.InfoTest do
  @moduledoc false
  use ExUnit.Case, async: true

  doctest PyroManiac.Info, import: true

  defmodule StaffPage do
    @moduledoc false

    use PyroManiac, resource: Brewery.Staff

    view [:read, :list] do
      type :data_table
      primary? true
      default_sort "email"
      ensure_loaded([:name_email])
      exclude([:id, :name_email])
      column(:name)
      column(:email)
      column(:role)
      column(:active)
    end

    view :read do
      type :card

      primary? true

      action [:create, :update], :guard

      section :identity do
        field :name do
          description "Full name"
          autofocus(true)
        end

        field :email
      end

      section :role_status do
        label "Role & Status"

        select :role do
          label "Role"
        end

        field :active do
          label "Active"
        end
      end
    end

    page do
      route "/test"
      exclude [:deactivate, :destroy, :autocomplete]
    end
  end

  defmodule RecipePage do
    @moduledoc false

    use PyroManiac, resource: Brewery.Recipe

    page do
      route "/test"
      exclude [:create, :update, :activate, :retire, :destroy, :list]
    end

    view :read do
      type :data_table
      primary? true
      default_sort "name"
      ensure_loaded(recipe_ingredients: [:ingredient])
      exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
      column(:name)
      column(:style)
      column(:description)
      column(:status)
      column(:target_abv)
      column(:target_og)
      column(:target_fg)
      column(:gravity_spread)
      column(:ingredient_count)
      column(:batch_count)
    end

    view :read do
      type :card

      primary? true

      section :main do
        field :name
      end
    end
  end

  describe "views/1" do
    # The list views of a page are its tabs, in the order of the DSL. The
    # views were the values of a map, in the order of its keys.
    test "gives the views in the order of the DSL" do
      assert Enum.map(PyroManiac.Info.views(BreweryWeb.RecipeLive), & &1.type) == [
               :data_table,
               :card
             ]
    end

    # A transformer reordered the views of a page with a kanban view: each
    # pass that rewrote them prepended them one by one, so it reversed them.
    test "keeps the order of the DSL with a kanban view" do
      defmodule KanbanOrderPage do
        @moduledoc false
        use PyroManiac, resource: Brewery.Batch

        view :read do
          type :data_table
          primary? true
          exclude [:id, :recipe_id, :brewer_id, :recipe, :brewer, :kanban_priority]
          column :batch_number
          column :status
          column :brew_date
          column :package_date
          column :actual_og
          column :actual_fg
          column :actual_abv
          column :volume_liters
          column :notes
          column :test_count
          column :passed_test_count
          column :pass_rate
        end

        view :read do
          type :card
          primary? true

          section :batch do
            field :batch_number
          end
        end

        view :kanban_read do
          type :kanban
          field :batch_number
        end

        view :read do
          type :timeline
          date_field :brew_date
          field :batch_number
        end
      end

      assert Enum.map(PyroManiac.Info.views(KanbanOrderPage), & &1.type) == [
               :data_table,
               :card,
               :kanban,
               :timeline
             ]
    end

    test "gives a view with many names once" do
      assert [%{name: [:read, :list]}, %{type: :card}] = PyroManiac.Info.views(StaffPage)
    end
  end

  describe "build_loads_from_view/2" do
    test "merges ensure_loaded into the view's inferred loads" do
      view = PyroManiac.Info.view_for(StaffPage, :read, :data_table)
      loads = PyroManiac.Info.build_loads_from_view(view, Brewery.Staff)

      assert :name_email in loads
    end

    test "merges nested keyword ensure_loaded statements" do
      view = PyroManiac.Info.view_for(RecipePage, :read, :data_table)
      loads = PyroManiac.Info.build_loads_from_view(view, Brewery.Recipe)

      assert {:recipe_ingredients, [:ingredient]} in loads
    end
  end
end
