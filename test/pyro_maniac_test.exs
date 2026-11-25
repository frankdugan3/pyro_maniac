defmodule PyroManiacTest do
  @moduledoc false
  use ExUnit.Case, async: true

  doctest PyroManiac, import: true

  defmodule RecipePage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    page do
      route "/test"
      exclude [:activate, :retire, :destroy]
    end

    view [:read, :list] do
      type :data_table
      primary? true
      description :inherit
      default_sort "name"
      exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])

      column :name do
        description :inherit
      end

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

      action [:create, :update], :guard

      field :name, autofocus: true
      select :style
      field :description
      field :target_abv
      field :target_og
      field :target_fg
      select :status
      field :photos, type: :attachment
    end
  end

  test "works" do
    assert Brewery.Recipe = RecipePage.persisted(:resource, nil)

    assert [
             "Name",
             "Style",
             "Description",
             "Target Abv",
             "Target Og",
             "Target Fg",
             "Status",
             "Photos"
           ] =
             RecipePage
             |> PyroManiac.Info.action_for(:create)
             |> Map.get(:fields)
             |> Enum.map(& &1.label)
  end
end
