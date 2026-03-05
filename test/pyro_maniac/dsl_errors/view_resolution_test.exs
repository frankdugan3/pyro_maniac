Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DslErrors.ViewResolutionTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  describe "relationship resolution" do
    test "unknown relationship in nested view (with did-you-mean)" do
      expected = """
      [PyroManiac.DslErrors.ViewResolutionTest.UnknownRelationship]
      views -> view -> read defined in <FILE:LINE>:
        relationship :recipe_ingrdients does not exist on Brewery.Recipe

        Did you mean:
          * :recipe_ingredients
      │
      <LINE> │                 relationship :recipe_ingrdients
      │                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule UnknownRelationship do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
              default_sort "name"
              exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
              column :name
              column :style
              column :description
              column :status
              column :target_abv
              column :target_og
              column :target_fg
              column :gravity_spread
              column :ingredient_count
              column :batch_count

              view :read do
                relationship :recipe_ingrdients
                type :data_table
              end
            end
          end
        end
      end
    end
  end

  describe "cross-resource view requires sets" do
    test "explicit resource without `set` entities" do
      expected = """
      [PyroManiac.DslErrors.ViewResolutionTest.NoSets]
      views -> view -> read defined in <FILE:LINE>:
        view targeting Brewery.Supplier without a relationship requires at least one `set` to map parent fields to the read action

        Fix: add a `set :foo, ...` entity inside the view, or remove `resource:` and use `relationship:` instead
      │
      <LINE> │               view :read do
      │               ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule NoSets do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
              default_sort "name"
              exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
              column :name
              column :style
              column :description
              column :status
              column :target_abv
              column :target_og
              column :target_fg
              column :gravity_spread
              column :ingredient_count
              column :batch_count

              view :read do
                resource Brewery.Supplier
                type :data_table
              end
            end
          end
        end
      end
    end
  end
end
