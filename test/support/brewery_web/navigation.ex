defmodule BreweryWeb.Navigation do
  @moduledoc false

  use PyroManiac.Navigation

  nav do
    item :home do
      path "/"
      module BreweryWeb.HomeLive
      image "/images/logo.svg"
      image_alt "Acme Brewery"
    end

    group :brewery do
      label "Brewery"
      icon :beer

      item :recipes do
        path "/recipes"
        page BreweryWeb.RecipeLive
        icon :recipe
      end

      item :batches do
        path "/batches"
        page BreweryWeb.BatchLive
        icon :batch
      end

      item :quality_tests do
        path "/quality-tests"
        page BreweryWeb.QualityTestLive
        icon :check
      end
    end

    group :inventory do
      label "Inventory"
      icon :grain

      item :ingredients do
        path "/ingredients"
        module BreweryWeb.IngredientLive
      end

      item :suppliers do
        path "/suppliers"
        module BreweryWeb.SupplierLive
      end
    end

    group :team do
      label "Team"
      icon :users

      item :staff do
        path "/staff"
        module BreweryWeb.StaffLive
      end
    end

    item :docs do
      href "https://docs.example.com"
      label "Docs"
      icon :book
    end
  end
end
