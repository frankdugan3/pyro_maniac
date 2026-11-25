defmodule PyroManiac.ListStateTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias PyroManiac.ListState

  doctest PyroManiac.ListState

  defmodule RecipePage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    page do
      route "/test"
      exclude [:create, :update, :destroy, :activate, :retire, :list]
    end

    view :read do
      type :card
      primary? true

      field :name
    end

    search :by_name do
      field :name
    end

    search :by_text do
      operator :or

      field :style do
        operator :eq
      end

      field :anything do
        negated? true
        source [:name, [:recipe_ingredients, :ingredient, :name]]
      end
    end
  end

  describe "encode and decode" do
    test "a full state survives a round trip" do
      state = %ListState{
        filter: %{"status" => %{"eq" => "active"}},
        sort: "-inserted_at,name",
        search: "by_name",
        inputs: %{"name" => "pale"},
        after: "g3QAAAAB",
        limit: 10
      }

      assert state |> ListState.encode() |> ListState.decode() == state
    end

    test "atom keys and values are strings" do
      state = ListState.put(%ListState{}, :filter, %{status: %{eq: :active}})

      assert state.filter == %{"status" => %{"eq" => "active"}}
      assert state |> ListState.encode() |> ListState.decode() == state
    end

    test "an empty filter is no filter" do
      assert ListState.put(%ListState{}, :filter, %{}).filter == nil
      assert ListState.encode(%ListState{filter: %{}, inputs: %{}}) == %{}
    end

    test "invalid values are left out" do
      assert ListState.decode(%{"p" => "0", "ps" => "-1", "qi" => "[1]", "s" => ""}) ==
               %ListState{}

      assert ListState.decode(nil) == %ListState{}
    end
  end

  describe "toggle_sort" do
    test "multi-sort flips and removes a field in place" do
      state = %ListState{sort: "name,-style"}

      assert ListState.toggle_sort(state, :name, multi?: true).sort == "-name,-style"
      assert ListState.toggle_sort(state, :style, multi?: true).sort == "name"
    end

    test "goes back to the first page" do
      assert ListState.toggle_sort(%ListState{page: 4}, :name).page == nil
    end
  end

  describe "search_filter" do
    test "a blank search is no filter, a value is a predicate" do
      search = Enum.find(PyroManiac.Info.searches(RecipePage), &(&1.name == :by_name))

      assert ListState.search_filter(search, Brewery.Recipe, %{"name" => " "}) == nil

      assert ListState.search_filter(search, Brewery.Recipe, %{"name" => "pale"}) ==
               %{"name" => %{"contains" => "pale"}}
    end

    test "sources are joined with or, negated, and fields with the operator of the search" do
      search = Enum.find(PyroManiac.Info.searches(RecipePage), &(&1.name == :by_text))

      assert ListState.search_filter(search, Brewery.Recipe, %{
               "style" => "ipa",
               "anything" => "x"
             }) ==
               %{
                 "or" => [
                   %{"style" => %{"eq" => "ipa"}},
                   %{
                     "not" => %{
                       "or" => [
                         %{"name" => %{"contains" => "x"}},
                         %{
                           "recipe_ingredients" => %{
                             "ingredient" => %{"name" => %{"contains" => "x"}}
                           }
                         }
                       ]
                     }
                   }
                 ]
               }
    end
  end

  describe "query" do
    test "applies the filter, the search, and the sort" do
      state = %ListState{
        filter: %{"status" => %{"eq" => "active"}},
        search: "by_name",
        inputs: %{"name" => "pale"},
        sort: "-name"
      }

      query =
        Brewery.Recipe
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> ListState.query(state, page: RecipePage)

      assert query.errors == []
      assert [name: :desc] = query.sort
      assert inspect(query.filter) =~ ~s(status == "active")
      assert inspect(query.filter) =~ "contains(name"
    end

    test "drops the fields that the action does not expose" do
      state = %ListState{filter: %{"nope" => %{"eq" => 1}}, sort: "nope,name"}

      query =
        Brewery.Recipe
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> ListState.query(state)

      assert query.filter == nil
      assert [name: :asc] = query.sort
    end
  end

  describe "validate" do
    test "a valid state" do
      assert :ok =
               ListState.validate(
                 %ListState{filter: %{"status" => %{"eq" => "active"}}, sort: "-name"},
                 Brewery.Recipe,
                 :read
               )
    end

    test "an unknown field and an unknown operator" do
      assert {:error, [filter: filter, sort: sort]} =
               ListState.validate(
                 %ListState{filter: %{"nope" => %{"eq" => 1}}, sort: "nope"},
                 Brewery.Recipe,
                 :read
               )

      assert filter =~ "does not expose"
      assert sort =~ "does not expose"

      assert {:error, [filter: _message]} =
               ListState.validate(
                 %ListState{filter: %{"status" => %{"no_such_operator" => "active"}}},
                 Brewery.Recipe,
                 :read
               )
    end
  end

  describe "presets" do
    test "a state survives a preset, without the page position" do
      state = %ListState{
        filter: %{"status" => %{"eq" => "active"}},
        sort: "name",
        search: "by_name",
        inputs: %{"name" => "pale"},
        page: 3
      }

      assert state |> ListState.to_preset() |> ListState.from_preset() == %{state | page: nil}
    end

    test "the keys of a view" do
      view = PyroManiac.Info.primary_single_view(RecipePage)

      assert ListState.view_key(view) == "read:card"

      assert ListState.storage_key(RecipePage, view) ==
               "pyro_maniac:filters:PyroManiac.ListStateTest.RecipePage:read:card"
    end
  end
end
