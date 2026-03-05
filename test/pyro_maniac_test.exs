defmodule PyroManiacTest do
  @moduledoc false
  use ExUnit.Case, async: true

  doctest PyroManiac, import: true

  defmodule RecipePage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    forms do
      exclude([:activate, :retire])

      action [:create, :update] do
        field :name, autofocus: true
        field :style
        field :description
        field :target_abv
        field :target_og
        field :target_fg
        field :status
        field :photos, type: :attachment
      end
    end

    views do
      view [:read, :list] do
        type :data_table
        description :inherit
        default_sort "name"
        exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
        column(:name, description: :inherit)
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
             |> PyroManiac.Info.form_for(:create)
             |> Map.get(:fields)
             |> Enum.map(& &1.label)
  end
end
