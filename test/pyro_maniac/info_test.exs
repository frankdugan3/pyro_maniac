defmodule PyroManiac.InfoTest do
  @moduledoc false
  use ExUnit.Case, async: true

  doctest PyroManiac.Info, import: true

  defmodule StaffPage do
    @moduledoc false

    use PyroManiac, resource: Brewery.Staff

    views do
      view [:read, :list] do
        type :data_table
        default_sort "email"
        ensure_loaded([:name_email])
        exclude([:id, :name_email])
        column(:name)
        column(:email)
        column(:role)
        column(:active)
      end
    end

    forms do
      exclude([:deactivate])

      action [:create, :update] do
        class "max-w-md justify-self-center"

        field_group "Identity" do
          class "md:grid-cols-2"

          field :name do
            description "Full name"
            autofocus(true)
          end

          field :email
        end

        field_group "Role & Status" do
          class "md:grid-cols-2"

          field :role do
            label("Role")
          end

          field :active do
            label("Active")
          end
        end
      end
    end
  end

  defmodule RecipePage do
    @moduledoc false

    use PyroManiac, resource: Brewery.Recipe

    forms do
      exclude([:create, :update, :activate, :retire])
    end

    views do
      view :read do
        type :data_table
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
