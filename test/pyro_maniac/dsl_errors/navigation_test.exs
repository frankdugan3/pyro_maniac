Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DslErrors.NavigationTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  test "item with no target" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.NoTarget]
    nav -> item -> orphan defined in <FILE:LINE>:
      item :orphan must have exactly one of `page`, `module`, or `href`

      Fix: set one of `page BreweryWeb.RecipeLive`, `module BreweryWeb.HomeLive`, or `href "/url"`
    │
    <LINE> │           item :orphan do
    │           ~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule NoTarget do
        use PyroManiac.Navigation

        nav do
          item :orphan do
            path "/orphan"
          end
        end
      end
    end
  end

  test "item with multiple targets" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.MultiTarget]
    nav -> item -> both defined in <FILE:LINE>:
      item :both has multiple targets — use only one of `page`, `module`, or `href`

      Fix: remove all but one of `page`, `module`, or `href`
    │
    <LINE> │           item :both do
    │           ~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule MultiTarget do
        use PyroManiac.Navigation

        nav do
          item :both do
            path "/both"
            page SomeModule
            module AnotherModule
          end
        end
      end
    end
  end

  test "module item without path" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.NoPath]
    nav -> item -> no_path defined in <FILE:LINE>:
      item :no_path with `module` requires a `path`

      Fix: add `path "/some-path"` to the item, or use a `page` reference instead
    │
    <LINE> │           item :no_path do
    │           ~~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule NoPath do
        use PyroManiac.Navigation

        nav do
          item :no_path do
            module SomeModule
          end
        end
      end
    end
  end

  test "path not starting with /" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.BadPath]
    nav -> item -> bad -> path defined in <FILE:LINE>:
      item :bad path must start with `/`, got: "no-slash"

      Fix: prefix the path with `/`, e.g. `path "/no-slash"`
    │
    <LINE> │             path "no-slash"
    │             ~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule BadPath do
        use PyroManiac.Navigation

        nav do
          item :bad do
            path "no-slash"
            module SomeModule
          end
        end
      end
    end
  end

  test "duplicate paths" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.DupPath]
    nav -> item -> two defined in <FILE:LINE>:
      duplicate route "/same": items :one and :two

      Fix: give each item a route that no other route matches
    │
    <LINE> │             path "/same"
    │             ~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule DupPath do
        use PyroManiac.Navigation

        nav do
          item :one do
            path "/same"
            module ModuleA
          end

          item :two do
            path "/same"
            module ModuleB
          end
        end
      end
    end
  end

  test "overlapping routes, in different groups" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.OverlapPath]
    nav -> item -> new_recipe defined in <FILE:LINE>:
      the route "/recipes/new" of item :new_recipe overlaps the route "/recipes/:id" of item :recipe: one URL matches both

      Fix: give each item a route that no other route matches
    │
    <LINE> │               path "/recipes/new"
    │               ~~~~~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule OverlapPath do
        use PyroManiac.Navigation

        nav do
          group :one do
            item :recipe do
              path "/recipes/:id"
              module ModuleA
            end
          end

          group :two do
            item :new_recipe do
              path "/recipes/new"
              module ModuleB
            end
          end
        end
      end
    end
  end

  test "a page item has no path: it opens the route of the page" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.PagePath]
    nav -> item -> recipes -> path defined in <FILE:LINE>:
      item :recipes opens the page BreweryWeb.RecipeLive, so its path is the `route` of the page; the navigation does not set it

      Fix: remove `path`, and set `page do route "/recipes" end` in BreweryWeb.RecipeLive
    │
    <LINE> │             path "/recipes"
    │             ~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule PagePath do
        use PyroManiac.Navigation

        nav do
          item :recipes do
            path "/recipes"
            page BreweryWeb.RecipeLive
          end
        end
      end
    end
  end

  test "a page item's route overlaps the path of a module item" do
    assert_dsl_error ~r/the route "\/recipes" of item :recipes overlaps the route "\/:section" of item :section/ do
      defmodule PageOverlap do
        use PyroManiac.Navigation

        nav do
          item :section do
            path "/:section"
            module ModuleA
          end

          item :recipes do
            page BreweryWeb.RecipeLive
          end
        end
      end
    end
  end

  test "a page item opens a PyroManiac module" do
    assert_dsl_error ~r/`page SomeModule` is not a PyroManiac module/ do
      defmodule NotPyroManiac do
        use PyroManiac.Navigation

        nav do
          item :some do
            page SomeModule
          end
        end
      end
    end
  end

  test "a page item opens a module with a page section" do
    defmodule ReusedRecipeViews do
      use PyroManiac, resource: Brewery.Recipe

      view :read do
        type :card
        primary? true

        section :main do
          field :name
        end
      end
    end

    expected = ~r/ReusedRecipeViews has no `page` section, so it is not a page and has no route/

    assert_dsl_error expected do
      defmodule NotAPage do
        use PyroManiac.Navigation

        nav do
          item :recipes do
            page PyroManiac.DslErrors.NavigationTest.ReusedRecipeViews
          end
        end
      end
    end
  end

  test "a page item opens a route without parameters" do
    defmodule RecipePage do
      use PyroManiac, resource: Brewery.Recipe

      page do
        route "/recipes/:id"
        exclude [:create, :update, :destroy, :activate, :retire, :list]
      end

      view :read do
        type :card
        primary? true

        section :main do
          field :name
        end
      end
    end

    assert_dsl_error ~r/the route "\/recipes\/:id" of .*RecipePage has parameters/ do
      defmodule ParamRoute do
        use PyroManiac.Navigation

        nav do
          item :recipe do
            page PyroManiac.DslErrors.NavigationTest.RecipePage
          end
        end
      end
    end
  end

  test "the path of a page command starts with the route of the page" do
    assert_dsl_error ~r/command :new_recipe opens BreweryWeb.RecipeLive, so its `path` starts with the route "\/recipes" of the page, got: "\/batches\?new"/ do
      defmodule CommandPath do
        use PyroManiac.Navigation

        nav do
          item :recipes do
            page BreweryWeb.RecipeLive
          end
        end

        command_palette do
          command :new_recipe do
            page BreweryWeb.RecipeLive
            path "/batches?new"
          end
        end
      end
    end
  end

  test "duplicate names at same level" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.DupName]
    nav -> item -> foo defined in <FILE:LINE>:
      duplicate name :foo at the same level
    │
    <LINE> │           item :foo do
    │           ~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule DupName do
        use PyroManiac.Navigation

        nav do
          item :foo do
            path "/a"
            module ModuleA
          end

          item :foo do
            path "/b"
            module ModuleB
          end
        end
      end
    end
  end

  test "icon and image both set" do
    expected = """
    [PyroManiac.DslErrors.NavigationTest.IconAndImage]
    nav -> item -> both_visual defined in <FILE:LINE>:
      :both_visual cannot have both `icon` and `image` — choose one

      Fix: remove either `icon` or `image`
    │
    <LINE> │           item :both_visual do
    │           ~~~~~~~~~~~~~~~~~~~~
    │
    └─ <FILE:LINE>: (file)\
    """

    assert_dsl_error expected do
      defmodule IconAndImage do
        use PyroManiac.Navigation

        nav do
          item :both_visual do
            path "/x"
            module SomeModule
            icon :some_icon
            image "/logo.png"
          end
        end
      end
    end
  end
end
