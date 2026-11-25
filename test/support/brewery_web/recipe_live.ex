defmodule BreweryWeb.RecipeLive do
  @moduledoc false

  use PyroManiac, resource: Brewery.Recipe

  view :read do
    type :data_table
    primary? true
    default_sort "name"

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

    section :main do
      field :name
    end
  end

  page do
    route "/recipes"
    exclude [:create, :update, :activate, :retire, :destroy, :list]
  end
end
