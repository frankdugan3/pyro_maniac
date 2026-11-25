defmodule PyroManiac.RecordLayoutTest do
  @moduledoc false
  # The record layout: one record tree for the card view and the form, the
  # links between the pages, the card URL param, and the filter chips.
  use ExUnit.Case, async: false

  alias PyroManiac.{Card, FilterChips, Info, Link}
  alias PyroManiac.Form.{Attachments, Compound, Field, Related, Row, Section, Tab, Tabs, Tree}
  alias PyroManiac.Surface.Requirement
  alias PyroManiac.View.View

  doctest PyroManiac.Link

  defmodule RecipePage do
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
        :batch_count,
        :status
      ]

      column :name
      column :style
    end

    view :read do
      type :card
      primary? true
      action [:update], :guard

      section :recipe do
        field :name, autofocus: true
        select :style
        field :gravity_spread
        field :batch_count, only: [:read]
      end

      tabs do
        tab :details do
          section :targets do
            row do
              field :target_abv
              field :target_og
              field :target_fg
            end

            field :description, type: :textarea
            select :status
          end
        end

        tab :batches do
          count :batch_count

          related :batches do
            delegate_to PyroManiac.RecordLayoutTest.BatchPage
            count :batch_count
          end
        end

        tab :ingredients do
          count :ingredient_count

          related :recipe_ingredients do
            type :data_table
            field :quantity
          end
        end

        tab :photos do
          attachments :photos
        end
      end

      presentation :drawer
    end

    page do
      route "/test"
      exclude [:create, :activate, :retire, :destroy, :list]
    end
  end

  defmodule BatchPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Batch

    view :read do
      type :data_table
      primary? true
      default_sort "-batch_number"
      exclude [:id, :brewer_id, :brewer, :kanban_priority, :recipe_id]

      column :batch_number

      column :recipe do
        link_to PyroManiac.RecordLayoutTest.RecipePage
      end

      column :status
      column :brew_date
      column :package_date
      column :actual_og
      column :actual_fg
      column :actual_abv
      column :volume_liters
      column :notes
      column :test_count
      column :passed_test_count
      column :pass_rate
    end

    view :read do
      type :card
      primary? true
      action [:update], :guard

      row do
        section :batch do
          field :batch_number, autofocus: true

          combobox :recipe_id do
            link_to PyroManiac.RecordLayoutTest.RecipePage
          end

          combobox :brewer_id
          select :status
          field :pass_rate
        end

        section :production do
          collapsible? true

          row do
            field :brew_date
            field :package_date
          end

          compound :gravity do
            field :actual_og
            field :actual_fg
          end

          field :actual_abv
          field :volume_liters
          field :notes, type: :textarea, only: [:update]
          field :kanban_priority, only: [:update]
        end
      end
    end

    page do
      route "/test"

      exclude [
        :create,
        :start_brewing,
        :advance_status,
        :complete,
        :move_card,
        :destroy,
        :list,
        :kanban_read
      ]
    end
  end

  defmodule RecipeGridPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    view :read do
      type :grid
      primary? true

      section :recipe do
        density :dense
        max_columns 2
        field :name

        compound :gravity do
          separator " → "
          field :target_og
          field :target_fg
        end

        row do
          field :style
          field :status
        end
      end

      section :ingredients do
        path [:recipe_ingredients]
        field :quantity

        field :ingredient do
          link_to PyroManiac.RecordLayoutTest.IngredientPage
        end
      end
    end

    view :list do
      type :card
      primary? true

      section :recipe do
        field :name
        field :style
      end
    end

    page do
      route "/test"
      exclude [:create, :update, :activate, :retire, :destroy]
    end
  end

  defmodule IngredientPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Ingredient

    view :read do
      type :card
      primary? true

      section :ingredient do
        field :name
        field :supplier
      end
    end

    page do
      route "/test"
      exclude [:create, :update, :destroy]
    end
  end

  describe "the record tree" do
    setup do
      %{tree: Info.action_for(RecipePage, :update).fields}
    end

    test "a field that is not an input of the action is read-only", %{tree: tree} do
      fields = Map.new(Tree.values(tree), &{&1.name, &1})
      view_fields = Map.new(Tree.values(Card.tree(RecipePage)), &{&1.name, &1})

      assert Tree.read_only?(fields.gravity_spread)
      assert Tree.read_only?(view_fields.batch_count)
      refute Tree.read_only?(fields.name)
      refute Tree.input?(fields.gravity_spread)
    end

    test "the inputs are the edit mode inputs, without the read-only fields", %{tree: tree} do
      assert Enum.map(Tree.inputs(tree), & &1.name) ==
               [:name, :style, :target_abv, :target_og, :target_fg, :description, :status]
    end

    test "only names the actions of a node: the read action is view mode" do
      view_names = BatchPage |> Card.tree() |> Tree.values() |> Enum.map(& &1.name)

      edit_names =
        BatchPage
        |> Info.action_for(:update)
        |> Map.fetch!(:fields)
        |> Tree.values()
        |> Enum.map(& &1.name)

      refute :notes in view_names
      assert :notes in edit_names
      assert :kanban_priority in edit_names
    end

    test "the tabs, the related records, and the files", %{tree: tree} do
      assert %Tabs{fields: [%Tab{name: :details, label: "Details"} | _]} = Tree.tabs(tree)

      assert [
               %Related{name: :batches, __destination__: Brewery.Batch, label: "Batches"},
               %Related{name: :recipe_ingredients, type: :data_table},
               %Attachments{name: :photos}
             ] = Enum.reject(Tree.leaves(tree), &Tree.value?/1)
    end

    test "a section of the tree is a Section" do
      assert [%Section{label: "Recipe"}, %Tabs{}] = Info.action_for(RecipePage, :update).fields
    end

    test "a combobox in select mode knows its relationship" do
      combobox =
        BatchPage
        |> Info.action_for(:update)
        |> Map.fetch!(:fields)
        |> Tree.values()
        |> Enum.find(&(&1.name == :recipe_id))

      assert combobox.__relationship__ == :recipe
      assert [%PyroManiac.LinkTo{page: RecipePage, single_view: nil}] = combobox.link_to
    end

    test "the layout map has the new nodes" do
      layout = Info.form_layout(Info.action_for(RecipePage, :update))
      [section, tabs] = layout.children

      assert %{kind: :section, label: "Recipe"} = section

      assert %{kind: :field, name: :gravity_spread, read_only?: true} =
               Enum.at(section.children, 2)

      refute Enum.any?(section.children, &(&1[:name] == :batch_count))
      assert %{kind: :tabs, children: [_, batches, ingredients, photos]} = tabs
      assert %{kind: :tab, name: :batches, count: :batch_count} = batches

      assert %{kind: :related, delegate_to: PyroManiac.RecordLayoutTest.BatchPage} =
               hd(batches.children)

      assert %{kind: :related, fields: [%{name: :quantity}]} = hd(ingredients.children)
      assert %{kind: :attachments, name: :photos} = hd(photos.children)
    end
  end

  describe "sections side by side" do
    test "a row of sections" do
      assert [
               %PyroManiac.Form.Row{
                 fields: [%Section{label: "Batch"}, %Section{label: "Production"}]
               }
             ] =
               Info.action_for(BatchPage, :update).fields

      assert :brew_date in Enum.map(
               Tree.inputs(Info.action_for(BatchPage, :update).fields),
               & &1.name
             )
    end
  end

  describe "the card" do
    test "a card shows its tree in view mode, and names its write actions" do
      assert %View{
               type: :card,
               presentation: :drawer,
               "__editable?__": true,
               __actions__: [:update]
             } =
               card = Info.primary_single_view(RecipePage)

      view_names = card |> Card.tree() |> Tree.values() |> Enum.map(& &1.name)

      form_names =
        RecipePage
        |> Info.action_for(:update)
        |> Map.fetch!(:fields)
        |> Tree.values()
        |> Enum.map(& &1.name)

      assert :batch_count in view_names
      refute :batch_count in form_names
      assert [%{name: :update, __view__: {:read, :card}}] = Card.actions(RecipePage)
    end

    test "a card without a write action shows values only" do
      assert %View{type: :card, presentation: :modal, "__editable?__": false} =
               card = Info.primary_single_view(RecipeGridPage)

      assert [%Section{name: :recipe, label: "Recipe"}] = Card.tree(card)
      assert Card.actions(RecipeGridPage) == []
      assert card |> Card.tree() |> Tree.values() |> Enum.all?(&Tree.read_only?/1)
    end

    test "the tabs of a card, in all modes" do
      assert Card.tabs(RecipePage) == [
               %{name: :details, label: "Details", count: nil},
               %{name: :batches, label: "Batches", count: :batch_count},
               %{name: :ingredients, label: "Ingredients", count: :ingredient_count},
               %{name: :photos, label: "Photos", count: nil}
             ]

      assert Card.tabs(Info.action_for(RecipePage, :update).fields) == Card.tabs(RecipePage)
      assert Card.tabs(BatchPage) == []
    end

    test "the paths of a card: the values, the counts, the labels, and the files" do
      paths = Card.paths(Info.primary_single_view(RecipePage), Brewery.Recipe)

      for path <- [
            [:name],
            [:gravity_spread],
            [:batch_count],
            [:ingredient_count],
            [:photos],
            [:recipe_ingredients, :quantity]
          ] do
        assert path in paths
      end

      # A delegated viewer loads its own records.
      refute [:batches] in paths
    end

    test "a combobox shows the label of its record" do
      paths = Card.paths(Info.primary_single_view(BatchPage), Brewery.Batch)

      assert [:recipe, :name] in paths
      assert [:brewer, :name] in paths
      assert [:pass_rate] in paths
      refute [:notes] in paths
    end

    test "the loads of a card" do
      loads = Info.build_loads_from_view(Info.primary_single_view(RecipePage), Brewery.Recipe)

      assert :gravity_spread in loads
      assert :batch_count in loads
      assert :photos in loads
      assert {:recipe_ingredients, :quantity} in loads
    end

    test "the surface requirement of a card" do
      requirement =
        Brewery.Recipe
        |> Requirement.requirements(Info.views(RecipePage), Info.actions(RecipePage), [])
        |> Enum.find(&(&1.origin == [:views, :view, :read] and [:gravity_spread] in &1.loads))

      assert requirement.action == :read
      assert [:photos] in requirement.loads
    end

    test "show all fields: the exposed fields that the tree does not show" do
      extra = Card.extra_fields(RecipePage)

      assert :id in extra
      refute :name in extra
      refute :batches in extra
    end

    test "the sections of a card or a grid have compounds, rows, and paths" do
      [grid] = Info.views_of_type(RecipeGridPage, :grid)
      [recipe, ingredients] = Card.tree(grid)

      assert %Section{density: :dense, max_columns: 2} = recipe
      assert [_, %Compound{label: "Gravity", separator: " → "}, %Row{}] = recipe.fields

      assert Enum.map(Tree.values(recipe), & &1.name) ==
               [:name, :target_og, :target_fg, :style, :status]

      assert Enum.map(Tree.values(ingredients), &(&1.__full_path__ ++ [&1.name])) == [
               [:recipe_ingredients, :quantity],
               [:recipe_ingredients, :ingredient]
             ]

      loads = Info.build_loads_from_view(grid, Brewery.Recipe)
      assert {:recipe_ingredients, :ingredient} in loads

      assert {:recipe_ingredients, [{:ingredient, :name}]} in loads or
               Enum.any?(loads, &match?({:recipe_ingredients, _}, &1))
    end
  end

  describe "links" do
    test "the record of a link is the relationship of the source" do
      assert Link.record_path(Brewery.Batch, [:recipe, :name]) == [:recipe]

      assert Link.record_path(Brewery.RecipeIngredient, [:ingredient, :supplier, :name]) ==
               [:ingredient, :supplier]

      assert Link.record_path(Brewery.Batch, [:notes]) == nil
    end

    test "a link column loads the label of its record" do
      view = Info.view_for(BatchPage, :read, :data_table)

      assert Info.link_paths(view, Brewery.Batch) == [[:recipe], [:recipe, :name]]
      assert :recipe in Info.build_loads_from_view(view, Brewery.Batch)
    end

    test "the links of a page" do
      links = Card.links(RecipePage)

      assert %{page: BatchPage, destination: Brewery.Batch, record_path: [:batches]} =
               Enum.find(links, &(&1.kind == :delegate))

      assert %{link: %PyroManiac.LinkTo{page: IngredientPage}} =
               RecipeGridPage
               |> Card.links()
               |> Enum.find(&(&1.destination == Brewery.Ingredient))
    end

    test "resolve: the view of a link, with the defaults" do
      assert {:ok, %{page: RecipePage, view: %View{type: :card}}} =
               Link.resolve(%PyroManiac.LinkTo{page: RecipePage}, :single)

      assert {:ok, %{view: %View{type: :data_table}}} =
               Link.resolve(%PyroManiac.LinkTo{page: RecipePage}, :list)

      assert {:error, message} =
               Link.resolve(%PyroManiac.LinkTo{page: RecipePage, list_view: :list}, :list)

      assert message =~ "RecipePage has no list view :list"

      assert {:error, message} = Link.resolve(%PyroManiac.LinkTo{page: String}, :single)
      assert message =~ "is not a PyroManiac page"
    end

    test "the link of a node is its link_to" do
      own = %PyroManiac.LinkTo{page: RecipePage}
      assert Link.link([own]) == own
      assert Link.link([]) == nil
      assert Link.link(nil) == nil
    end

    test "the filter of a list link" do
      assert Link.list_filter(Brewery.Recipe, [:batches], %{id: "r1"}) ==
               %{"recipe_id" => %{"eq" => "r1"}}

      assert Link.list_filter(Brewery.Batch, [:recipe], %{recipe_id: "r1"}) ==
               %{"id" => %{"eq" => "r1"}}
    end
  end

  describe "the card param" do
    test "param and parse_param: the primary card of the page" do
      card = Info.primary_single_view(BatchPage)

      assert Card.param(BatchPage, card, "b1") == "b1"
      assert Card.parse_param(BatchPage, "b1") == {:ok, card, "b1"}
      assert Card.parse_param(BatchPage, "read:b1") == {:ok, card, "b1"}
      assert Card.parse_param(BatchPage, "recipe:r1") == :error
      assert Card.parse_param(BatchPage, "read:") == :error
      assert Card.parse_param(BatchPage, "") == :error
    end
  end

  describe "filter chips" do
    setup do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Brewery.Repo, shared: true)
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
      # The recipes publish their changes.
      start_supervised!({Phoenix.PubSub, name: PyroManiac.PubSub})
      %{view: Info.view_for(BatchPage, :read, :data_table)}
    end

    test "each predicate of the conjunction is a chip", %{view: view} do
      filter = %{
        "status" => %{"in" => ["planned", "brewing"]},
        "and" => [%{"notes" => %{"ilike" => "%hop%"}}],
        "or" => [%{"batch_number" => "B-1"}, %{"batch_number" => "B-2"}]
      }

      chips = FilterChips.chips(view, Brewery.Batch, filter)

      assert [
               %{id: 0, kind: :predicate, path: [:notes], operator: :ilike, label: "Notes"},
               %{id: 1, kind: :group, label: "Custom filter"},
               %{id: 2, path: [:status], operator: :in, value: ["planned", "brewing"]}
             ] = chips

      assert FilterChips.remove(chips, 1) == %{
               "and" => [
                 %{"notes" => %{"ilike" => "%hop%"}},
                 %{"status" => %{"in" => ["planned", "brewing"]}}
               ]
             }

      assert FilterChips.remove(Enum.take(chips, 1), 0) == %{}

      assert FilterChips.remove(Enum.take(chips, 2), 0) ==
               chips |> Enum.at(1) |> Map.fetch!(:filter)
    end

    test "a relationship chip shows the label of its record and links to it", %{view: view} do
      recipe =
        Ash.create!(Brewery.Recipe, %{name: "Hazy IPA", style: :ipa}, authorize?: false)

      chips = FilterChips.chips(view, Brewery.Batch, %{"recipe_id" => %{"eq" => recipe.id}})

      assert [
               %{
                 path: [:recipe_id],
                 label: "Recipe",
                 record: {Brewery.Recipe, [id]},
                 link_to: %PyroManiac.LinkTo{page: PyroManiac.RecordLayoutTest.RecipePage}
               }
             ] = chips

      assert id == recipe.id

      assert [%{value_label: "Hazy IPA"}] = FilterChips.load_labels(chips, authorize?: false)
    end

    test "a filter through a relationship keeps its keys", %{view: view} do
      recipe =
        Ash.create!(Brewery.Recipe, %{name: "Dry Stout", style: :stout}, authorize?: false)

      filter = %{recipe: %{id: %{in: [recipe.id]}, name: %{eq: "Dry Stout"}}}
      chips = FilterChips.chips(view, Brewery.Batch, filter)

      assert [%{path: [:recipe, :id], record: {Brewery.Recipe, _}} = by_id, by_name] =
               Enum.sort_by(chips, &List.last(&1.path))

      assert by_id.filter == %{recipe: %{id: %{in: [recipe.id]}}}
      assert by_name.filter == %{recipe: %{name: %{eq: "Dry Stout"}}}
      assert by_name.record == nil

      assert [%{value_label: "Dry Stout"}, _] =
               chips
               |> FilterChips.load_labels(authorize?: false)
               |> Enum.sort_by(&List.last(&1.path))
    end

    test "an unknown record keeps its ID as the label", %{view: view} do
      id = Ash.UUID.generate()
      chips = FilterChips.chips(view, Brewery.Batch, %{"recipe_id" => id})

      assert [%{operator: :eq, value_label: ^id}] =
               FilterChips.load_labels(chips, authorize?: false)
    end

    test "an unknown field is a group chip" do
      assert [%{kind: :group, filter: %{"nope_xyz" => 1}}] =
               FilterChips.chips(nil, Brewery.Batch, %{"nope_xyz" => 1})

      assert FilterChips.chips(nil, Brewery.Batch, nil) == []
    end
  end

  test "a card with its own sections" do
    assert [%Section{name: :main}] = Card.tree(BreweryWeb.RecipeLive)
    assert Card.tabs(BreweryWeb.RecipeLive) == []
    assert %Field{} = hd(Tree.values(Info.action_for(BatchPage, :update).fields))
  end
end
