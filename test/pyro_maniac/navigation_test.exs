defmodule PyroManiac.NavigationTest do
  use ExUnit.Case, async: true

  alias PyroManiac.Navigation.{Group, Info, Item}

  describe "nav_tree/1" do
    test "returns the full tree" do
      tree = Info.nav_tree(BreweryWeb.Navigation)
      assert length(tree) == 5

      assert %Item{image: "/images/logo.svg", name: :home, path: "/"} = Enum.at(tree, 0)

      assert %Group{icon: :beer, label: "Brewery", name: :brewery} =
               Enum.at(tree, 1)

      assert %Group{icon: :grain, label: "Inventory", name: :inventory} =
               Enum.at(tree, 2)

      assert %Group{icon: :users, label: "Team", name: :team} = Enum.at(tree, 3)

      assert %Item{href: "https://docs.example.com", name: :docs} = Enum.at(tree, 4)
    end

    test "brewery group contains items" do
      [_, %Group{items: items}, _, _, _] = Info.nav_tree(BreweryWeb.Navigation)
      assert length(items) == 3

      assert %Item{icon: :recipe, name: :recipes, path: "/recipes"} =
               Enum.at(items, 0)

      assert %Item{icon: :batch, name: :batches, path: "/batches"} =
               Enum.at(items, 1)

      assert %Item{icon: :check, name: :quality_tests, path: "/quality-tests"} =
               Enum.at(items, 2)
    end

    test "inventory group contains items" do
      [_, _, %Group{items: items}, _, _] = Info.nav_tree(BreweryWeb.Navigation)
      assert length(items) == 2

      assert %Item{name: :ingredients, path: "/ingredients"} = Enum.at(items, 0)
      assert %Item{name: :suppliers, path: "/suppliers"} = Enum.at(items, 1)
    end

    test "team group contains items" do
      [_, _, _, %Group{items: items}, _] = Info.nav_tree(BreweryWeb.Navigation)
      assert length(items) == 1

      assert %Item{name: :staff, path: "/staff"} = Enum.at(items, 0)
    end
  end

  describe "route_manifest/1" do
    test "returns flat list of {path, module} tuples" do
      manifest = Info.route_manifest(BreweryWeb.Navigation)
      assert {"/", BreweryWeb.HomeLive} in manifest
      assert {"/recipes", BreweryWeb.RecipeLive} in manifest
      assert {"/batches", BreweryWeb.BatchLive} in manifest
      assert {"/quality-tests", BreweryWeb.QualityTestLive} in manifest
      assert {"/ingredients", BreweryWeb.IngredientLive} in manifest
      assert {"/suppliers", BreweryWeb.SupplierLive} in manifest
      assert {"/staff", BreweryWeb.StaffLive} in manifest
      refute Enum.any?(manifest, fn {path, _} -> path == "https://docs.example.com" end)
    end
  end

  describe "flat_items/1" do
    test "flattens all items" do
      items = Info.flat_items(BreweryWeb.Navigation)
      names = Enum.map(items, & &1.name)
      assert :home in names
      assert :recipes in names
      assert :batches in names
      assert :quality_tests in names
      assert :ingredients in names
      assert :suppliers in names
      assert :staff in names
      assert :docs in names
    end
  end

  describe "path_for_page/2" do
    test "returns path for a page module" do
      assert "/recipes" =
               Info.path_for_page(
                 BreweryWeb.Navigation,
                 BreweryWeb.RecipeLive
               )
    end

    test "returns nil for unknown module" do
      assert nil == Info.path_for_page(BreweryWeb.Navigation, SomeUnknownModule)
    end
  end

  describe "item_for_page/2" do
    test "returns the item for a page module" do
      item =
        Info.item_for_page(
          BreweryWeb.Navigation,
          BreweryWeb.BatchLive
        )

      assert %Item{name: :batches, path: "/batches"} = item
    end
  end

  describe "label auto-derivation" do
    test "item labels are derived from names" do
      items = Info.flat_items(BreweryWeb.Navigation)
      recipes = Enum.find(items, &(&1.name == :recipes))
      assert recipes.label == "Recipes"
    end

    test "explicit labels are preserved" do
      items = Info.flat_items(BreweryWeb.Navigation)
      docs = Enum.find(items, &(&1.name == :docs))
      assert docs.label == "Docs"
    end
  end

  describe "validation" do
    test "allows page item without explicit path (auto-resolved from page route config)" do
      defmodule V.Nav.NoPath do
        use PyroManiac.Navigation

        nav do
          item :no_path do
            page SomeModule
          end
        end
      end
    end
  end
end
