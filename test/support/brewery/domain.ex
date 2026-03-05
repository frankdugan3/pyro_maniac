defmodule Brewery.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Brewery.Staff
    resource Brewery.Supplier
    resource Brewery.Ingredient
    resource Brewery.Recipe
    resource Brewery.RecipeIngredient
    resource Brewery.Batch
    resource Brewery.QualityTest
    resource Brewery.StorageBlob
    resource Brewery.StorageAttachment
  end
end
