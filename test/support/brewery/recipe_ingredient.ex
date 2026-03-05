defmodule Brewery.RecipeIngredient do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "brewery_recipe_ingredients"
    repo(Brewery.Repo)
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal,
      allow_nil?: false,
      public?: true,
      description: "Amount of ingredient required."

    attribute :notes, :string,
      public?: true,
      description: "Usage notes (e.g. when to add during brew)."
  end

  relationships do
    belongs_to :recipe, Brewery.Recipe, allow_nil?: false, public?: true
    belongs_to :ingredient, Brewery.Ingredient, allow_nil?: false, public?: true
  end

  actions do
    default_accept :*
    defaults [:read, :destroy]

    create :create do
      primary? true
      argument :recipe_id, :uuid, allow_nil?: false
      argument :ingredient_id, :uuid, allow_nil?: false
      change manage_relationship(:recipe_id, :recipe, type: :append_and_remove)
      change manage_relationship(:ingredient_id, :ingredient, type: :append_and_remove)
    end

    update :update do
      primary? true
      require_atomic? false
    end
  end
end
