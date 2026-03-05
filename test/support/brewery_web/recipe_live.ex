defmodule BreweryWeb.RecipeLive do
  @moduledoc false

  use PyroManiac, resource: Brewery.Recipe

  views do
    view :read do
      type :data_table
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
  end

  forms do
    exclude [:create, :update, :activate, :retire]
  end
end
