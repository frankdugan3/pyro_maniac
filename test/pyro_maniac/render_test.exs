defmodule PyroManiac.RenderTest do
  @moduledoc false
  # The `render` entity: one implementation for each renderer of
  # a node, which the verifier of each renderer checks. And the options of a
  # section, the same in a form and a card.
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  alias PyroManiac.Form.Section
  alias PyroManiac.{Info, Render}

  defmodule RecipePage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    page do
      route "/test"
      exclude [:create, :update, :activate, :retire, :destroy, :list]
      title "Recipes"

      description "All the recipes"
      description(PyroManiac.LiveView, MyAppWeb.RecipesIntro)

      extra_action :export do
        label "Export"
        render PyroManiac.LiveView, MyAppWeb.ExportAction
      end
    end

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

      column :name do
        render PyroManiac.LiveView, MyAppWeb.Cells.Name
        render PyroManiac.Solid, "~/cells/Name"
      end

      column :style do
        render PyroManiac.LiveView, {MyAppWeb.Cells.Style, props: [size: :sm]}
      end
    end

    view :read do
      type :card
      primary? true

      section :recipe do
        label "The recipe"
        only [:read]
        collapsible? true
        render PyroManiac.LiveView, MyAppWeb.RecipeSection

        field :name
      end

      section :targets do
        field :target_abv
      end
    end
  end

  defp column(name),
    do: Enum.find(Info.view_for(RecipePage, :read, :data_table).columns, &(&1.name == name))

  describe "render" do
    test "the implementation of a renderer" do
      renders = column(:name).render

      assert Render.implementation(renders, PyroManiac.LiveView) == MyAppWeb.Cells.Name
      assert Render.implementation(renders, PyroManiac.Solid) == "~/cells/Name"
      assert Render.implementation(renders, Some.Renderer) == nil
      assert Render.implementation(nil, PyroManiac.LiveView) == nil
    end

    test "the implementation is any term" do
      assert Render.implementation(column(:style).render, PyroManiac.LiveView) ==
               {MyAppWeb.Cells.Style, props: [size: :sm]}
    end

    test "one render for the whole node, and the page description" do
      [action] = Info.page_extra_actions(RecipePage)
      assert Render.implementation(action.render, PyroManiac.LiveView) == MyAppWeb.ExportAction

      description = Info.description(RecipePage)

      assert PyroManiac.Content.resolve(description, PyroManiac.LiveView) ==
               {:impl, MyAppWeb.RecipesIntro}

      assert PyroManiac.Content.resolve(description, PyroManiac.Solid) ==
               {:text, "All the recipes"}

      assert PyroManiac.Content.text(description) == "All the recipes"
    end

    test "the page description is not an expression" do
      assert_dsl_error ~r/the page has no record, so its `description` is not an expression/ do
        defmodule DescriptionAndRender do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
            title "Recipes"
            description expr(name)
          end

          view :read do
            type :card
            primary? true

            section :recipe do
              field :name
            end
          end
        end
      end
    end

    test "the nodes of a page with a render" do
      nodes = Render.nodes(RecipePage)

      assert nodes |> Enum.map(&List.last(&1.origin)) |> Enum.sort() ==
               [:description, :export, :name, :recipe, :style]

      assert %{label: "the page description"} =
               Enum.find(nodes, &(&1.origin == [:page, :description]))

      assert Enum.find(nodes, &(&1.origin == [:page, :export]))
    end

    test "the verifier of a renderer: each render has its implementation" do
      assert :ok = Render.verify(RecipePage, PyroManiac.LiveView, fn _impl -> :ok end)

      assert {:error, error} = Render.verify(RecipePage, PyroManiac.Solid, fn _impl -> :ok end)
      assert Exception.message(error) =~ "but not for PyroManiac.Solid"
    end

    test "the verifier of a renderer validates the implementation" do
      validate = fn
        impl when is_atom(impl) -> :ok
        _impl -> {:error, "the implementation is a module"}
      end

      assert {:error, error} = Render.verify(RecipePage, PyroManiac.LiveView, validate)
      assert Exception.message(error) =~ "the implementation is a module"
    end

    test "a node has one render for each renderer" do
      assert_dsl_error ~r/has more than one `render` for PyroManiac.LiveView/ do
        defmodule TwoRenders do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true

            section :recipe do
              render PyroManiac.LiveView, MyAppWeb.A
              render PyroManiac.LiveView, MyAppWeb.B
              field :name
            end
          end

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end
        end
      end
    end
  end

  describe "sections" do
    test "a section has a name and a label" do
      [recipe, targets] = PyroManiac.Card.tree(Info.primary_single_view(RecipePage))

      assert %Section{name: :recipe, label: "The recipe", only: [:read], collapsible?: true} =
               recipe

      assert %Section{name: :targets, label: "Targets"} = targets
    end

    test "a compound has a name and a label" do
      assert {:ok, %PyroManiac.Form.Compound{label: "Tax Id"}} =
               PyroManiac.LayoutSchema.set_label(%PyroManiac.Form.Compound{name: :tax_id})
    end

    test "each input has a render" do
      for module <- [
            PyroManiac.Form.Field,
            PyroManiac.Form.Select,
            PyroManiac.Form.Combobox,
            PyroManiac.Form.Input,
            PyroManiac.Form.Compound,
            PyroManiac.View.Field
          ] do
        assert Keyword.has_key?(module.__entity__().entities, :render), inspect(module)
      end
    end

    test "steps have a description; tabs and tabs have a render; related and attachments have visible?" do
      assert Keyword.has_key?(PyroManiac.Form.Step.__entity__().entities, :description)

      for module <- [PyroManiac.Form.Tab, PyroManiac.Form.Tabs] do
        assert Keyword.has_key?(module.__entity__().entities, :render), inspect(module)
      end

      for module <- [PyroManiac.Form.Related, PyroManiac.Form.Attachments] do
        assert Keyword.has_key?(module.__entity__().schema, :visible?), inspect(module)
      end
    end

    test "a select has a decoration, and related a visible? condition" do
      defmodule ToneAndVisiblePage do
        use PyroManiac, resource: Brewery.Recipe

        view :read do
          type :card
          primary? true
          action [:update], :guard

          field :name, autofocus: true
          select :style
          select :status, decoration: expr(if status == :active, do: :success)
          field :description
          field :target_abv
          field :target_og
          field :target_fg

          related :batches do
            visible? expr(status == :active)
          end
        end

        page do
          route "/test"
          exclude [:create, :activate, :retire, :destroy, :list]
        end
      end

      fields = Info.action_for(ToneAndVisiblePage, :update).fields
      status = Enum.find(fields, &(&1.name == :status))
      batches = Enum.find(fields, &(&1.name == :batches))

      assert status.__decoration_refs__ == [:status]
      assert :status in batches.__depends_on__

      assert [:status] in PyroManiac.Card.paths(
               Info.primary_single_view(ToneAndVisiblePage),
               Brewery.Recipe
             )
    end
  end

  describe "content: a text or an expression for every renderer" do
    defmodule ContentPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      page do
        route "/test"
        exclude [:update, :activate, :retire, :destroy, :list]
        description "All the recipes"
      end

      view :read do
        type :data_table
        primary? true

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
          :ingredient_count,
          :batch_count,
          :name
        ]

        column :status do
          label "State"
          render expr(if gravity_spread > 0, do: "Brewing", else: "Idle")
          render PyroManiac.LiveView, BreweryWeb.Cells.Status
        end

        column :gravity_spread do
          description :inherit
        end

        column :style do
          label PyroManiac.LiveView, BreweryWeb.Labels.Style
        end

        description :inherit
      end

      view :read do
        type :card
        primary? true

        action :create do
          state :guard
          description :inherit
        end

        section :recipe do
          description expr(if batch_count > 0, do: "Brewed", else: "New")
          description PyroManiac.LiveView, BreweryWeb.Descriptions.Recipe
          field :name, autofocus: true
          select :style
          select :status
          field :description
          field :target_abv
          field :target_og
          field :target_fg
        end
      end
    end

    defp status_column,
      do: Enum.find(Info.view_for(ContentPage, :read, :data_table).columns, &(&1.name == :status))

    test "a text, an expression, and an implementation for one renderer" do
      column = status_column()

      assert PyroManiac.Content.text(column.label) == "State"
      assert {:impl, BreweryWeb.Cells.Status} = Render.resolve(column.render, PyroManiac.LiveView)
      assert {:expr, _expression} = Render.resolve(column.render, PyroManiac.Solid)
      assert PyroManiac.Content.refs(column) == [:gravity_spread]
    end

    test "a column without label has the capitalized name" do
      column =
        Enum.find(
          Info.view_for(ContentPage, :read, :data_table).columns,
          &(&1.name == :gravity_spread)
        )

      assert PyroManiac.Content.text(column.label) == "Gravity Spread"
    end

    test "the refs of an expression are loaded" do
      card = Info.primary_single_view(ContentPage)
      assert [:batch_count] in PyroManiac.Card.paths(card, Brewery.Recipe)

      table = Info.view_for(ContentPage, :read, :data_table)
      assert :gravity_spread in Info.build_loads_from_view(table, Brewery.Recipe)
    end

    test "description :inherit takes the description of the action" do
      assert [%{kind: :text, implementation: "Draft a new recipe."}] =
               Info.action_for(ContentPage, :create).description
    end

    # Regressions: `description :inherit` on a view or a column was not
    # resolved; a column with a label implementation only had no text; the
    # verifier of a renderer ignored `description` and `label`.
    test "description :inherit on a view and a column" do
      table = Info.view_for(ContentPage, :read, :data_table)
      column = Enum.find(table.columns, &(&1.name == :gravity_spread))

      assert PyroManiac.Content.text(column.description) == "Difference between target OG and FG."
      refute Enum.any?(table.description, &(&1.kind == :inherit))
    end

    test "a label with an implementation only keeps the capitalized name as its text" do
      column =
        Enum.find(Info.view_for(ContentPage, :read, :data_table).columns, &(&1.name == :style))

      assert PyroManiac.Content.text(column.label) == "Style"

      assert {:impl, BreweryWeb.Labels.Style} =
               PyroManiac.Content.resolve(column.label, PyroManiac.LiveView)
    end

    test "the verifier of a renderer checks descriptions and labels" do
      assert :ok = Render.verify(ContentPage, PyroManiac.LiveView, fn _impl -> :ok end)

      # The section description has a text-less implementation for LiveView
      # only, but an expression: every renderer is satisfied.
      assert :ok = Render.verify(ContentPage, PyroManiac.Solid, fn _impl -> :ok end)

      assert {:error, error} =
               Render.verify(ContentPage, PyroManiac.LiveView, fn
                 BreweryWeb.Descriptions.Recipe -> {:error, "not a component"}
                 _impl -> :ok
               end)

      assert Exception.message(error) =~ "not a component"
    end

    test "the value of a content expression for a record" do
      column = status_column()
      record = %Brewery.Recipe{gravity_spread: 0.01}

      assert PyroManiac.Content.value(column.render, PyroManiac.Solid, record) ==
               {:value, "Brewing"}

      assert PyroManiac.Content.value(column.render, PyroManiac.LiveView, record) ==
               {:impl, BreweryWeb.Cells.Status}

      assert PyroManiac.Content.value(column.label, PyroManiac.Solid, record) == {:value, "State"}
    end

    test "a node has one text or expression" do
      assert_dsl_error ~r/has more than one text or expression for `render`/ do
        defmodule TwoTexts do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true

            section :recipe do
              render "One"
              render "Two"
              field :name
            end
          end
        end
      end
    end

    test "an input takes an implementation only" do
      assert_dsl_error ~r/is an input: its `render` is an implementation for one renderer/ do
        defmodule InputText do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true
            action :update, :guard

            field :name do
              autofocus true
              render "Name"
            end

            select :style
            select :status
            field :description
            field :target_abv
            field :target_og
            field :target_fg
          end
        end
      end
    end

    test "a view has no record: no expression" do
      assert_dsl_error ~r/has no record, so its `description` is not an expression/ do
        defmodule ViewExpression do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true
            description expr(name)

            section :recipe do
              field :name
            end
          end
        end
      end
    end

    test "an expression refers to fields of the resource" do
      assert_dsl_error ~r/the `description` expression is invalid/ do
        defmodule BadExpression do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true

            section :recipe do
              description expr(nope)
              field :name
            end
          end
        end
      end
    end
  end
end
