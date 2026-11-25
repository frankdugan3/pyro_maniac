defmodule PyroManiac.ViewOptionsTest do
  @moduledoc false
  # The options of views and actions: `state`, `confirm`, overridable `set`,
  # `clone?`, `new_row?`, `reorder?`, the `:timeline` type, the `workflow`
  # node, the filters of a page, the filter preset storage, the command
  # palette, the ordering extension, and the decorations.
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  alias PyroManiac.Info

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defmodule Ordered do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.ViewOptionsTest.Domain,
      data_layer: AshPostgres.DataLayer,
      extensions: [PyroManiac.Ordering, PyroManiac.Resource]

    postgres do
      table "pyro_ordered_things"
      repo(Brewery.Repo)
    end

    ordering do
      attribute :position
      scope(:group)
    end

    pyro_maniac do
      default_label(:name)

      expose :read do
        loads [:*]
        filter [:*]
        sort [:*]
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :group, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Preset do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.ViewOptionsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [PyroManiac.FilterPresets]

    filter_presets do
      owner(Brewery.Staff)
    end
  end

  defmodule RecipePage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    page do
      route "/test"
      exclude [:activate, :retire, :list]
      custom_filters? true
      filter_storage PyroManiac.ViewOptionsTest.Preset
      delete_preset_confirm(false)
      shared_filters? true
    end

    view :read do
      type :data_table
      primary? true
      clone? true
      new_row? true

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

      column :name do
        action :create, :discard do
          field :name, autofocus: true
        end
      end

      column :style do
        action :create, :discard do
          select :style
        end
      end

      column :status

      action :create, :guard do
        confirm expr(if gravity_spread > 0, do: "Create the recipe #{name}?")
        delegate_to PyroManiac.ViewOptionsTest.RecipePage
      end

      action :destroy, :discard do
        confirm "Delete the recipe?"
      end
    end

    view :read do
      type :card
      primary? true
      action [:create, :update], :recover

      field :name, autofocus: true
      select :style
      select :status
      field :description
      field :target_abv
      field :target_og
      field :target_fg
    end
  end

  describe "the state of a form" do
    test "an argument or an option" do
      card_actions = Info.actions(RecipePage, Info.primary_single_view(RecipePage))

      assert %{state: :recover} = Enum.find(card_actions, &(&1.name == :create))
      assert %{state: :recover} = Enum.find(card_actions, &(&1.name == :update))

      assert %{state: :guard} =
               Enum.find(
                 Info.actions(RecipePage),
                 &(&1.__view__ == {:read, :data_table} and &1.name == :create and
                     is_nil(&1.__column__))
               )
    end

    test "is required" do
      assert_dsl_error ~r/required :state option not found/ do
        defmodule NoState do
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true
            action :update

            field :name, autofocus: true
          end
        end
      end
    end
  end

  describe "confirm" do
    test "a text, or an expression whose refs are loaded" do
      table_actions = Info.actions(RecipePage, Info.view_for(RecipePage, :read, :data_table))

      assert %{confirm: "Delete the recipe?"} = Enum.find(table_actions, &(&1.name == :destroy))

      assert %{__confirm_refs__: refs} =
               Enum.find(table_actions, &(&1.name == :create and is_nil(&1.__column__)))

      assert Enum.sort(refs) == [:gravity_spread, :name]
    end

    test "the view loads the calculations that a confirm expression refers to" do
      view = Info.view_for(RecipePage, :read, :data_table)
      view = %{view | columns: Enum.filter(view.columns, &(&1.name == :name))}

      assert :gravity_spread in Info.build_loads_from_view(view, Brewery.Recipe)
    end

    test "an invalid expression" do
      assert_dsl_error ~r/the `confirm` expression is invalid/ do
        defmodule BadConfirm do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :list]
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end

            action :destroy, :discard do
              confirm expr(nope)
            end
          end
        end
      end
    end
  end

  describe "set" do
    test "an overridable set needs an input" do
      assert_dsl_error ~r/`set :recipe_id` is overridable/ do
        defmodule OverridableSet do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end

            action :create, :guard do
              resource Brewery.Batch
              set :recipe_id, :id, overridable?: true
              field :batch_number, autofocus: true
              select :status
              field :brew_date
              field :package_date
              field :actual_og
              field :actual_fg
              field :actual_abv
              field :volume_liters
              field :notes
              combobox :brewer_id
            end
          end
        end
      end
    end
  end

  describe "clone? and new_row?" do
    test "a view with a create action" do
      table = Info.view_for(RecipePage, :read, :data_table)
      assert table.clone? and table.new_row?
    end

    test "clone? needs a create action" do
      assert_dsl_error ~r/`clone\?` makes records with a create action, but the view names none/ do
        defmodule CloneWithoutCreate do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :card
            primary? true
            clone? true

            section :main do
              field :name
            end
          end
        end
      end
    end

    test "a new row edits each required input" do
      assert_dsl_error ~r/the new row creates a record with :create, which requires :style/ do
        defmodule NewRowMissing do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:update, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :data_table
            primary? true
            new_row? true

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

            column :name do
              action :create, :discard do
                field :name, autofocus: true
              end
            end

            column :style
            column :status

            action :create, :guard do
              delegate_to PyroManiac.ViewOptionsTest.RecipePage
            end
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end
  end

  describe "timeline" do
    test "needs date_field" do
      assert_dsl_error ~r/timeline views require `date_field` to be set/ do
        defmodule TimelineNoDate do
          use PyroManiac, resource: Brewery.Batch

          view :read do
            type :timeline
            primary? true
            field :batch_number
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :batch_number
            end
          end
        end
      end
    end

    test "a timeline of batches" do
      defmodule BatchTimeline do
        use PyroManiac, resource: Brewery.Batch

        page do
          route "/test"

          exclude [
            :create,
            :update,
            :start_brewing,
            :advance_status,
            :complete,
            :destroy,
            :list,
            :kanban_read,
            :move_card
          ]
        end

        view :read do
          type :timeline
          primary? true
          date_field :brew_date
          end_date_field :package_date
          orientation(:horizontal)
          field :batch_number
          field :status
        end

        view :read do
          type :card
          primary? true

          section :main do
            field :batch_number
          end
        end
      end

      view = Info.primary_list_view(BatchTimeline)
      assert view.type == :timeline
      assert view.orientation == :horizontal

      assert :batch_number in Info.build_loads_from_view(view, Brewery.Batch) or
               [:batch_number] in PyroManiac.Card.paths(view, Brewery.Batch)
    end

    test "parent_field is a belongs_to of the resource to itself" do
      assert_dsl_error ~r/`parent_field :recipe` makes a tree of the records, but it is not a `belongs_to` from Brewery.Batch to Brewery.Batch/ do
        defmodule ListBadParent do
          use PyroManiac, resource: Brewery.Batch

          view :read do
            type :list
            primary? true
            parent_field :recipe
            field :batch_number
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :batch_number
            end
          end
        end
      end
    end

    test "parent_field is an option of a list only" do
      assert_dsl_error ~r/`parent_field` is an option of a `:list` view, but this view is `:grid`/ do
        defmodule GridParent do
          use PyroManiac, resource: Brewery.Batch

          view :read do
            type :grid
            primary? true
            parent_field :recipe
            field :batch_number
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :batch_number
            end
          end
        end
      end
    end

    test "orientation is an option of a timeline and a board only" do
      assert_dsl_error ~r/`orientation` is an option of a `:timeline` or `:kanban` view, but this view is `:calendar`/ do
        defmodule CalendarOrientation do
          use PyroManiac, resource: Brewery.Batch

          view :read do
            type :calendar
            primary? true
            date_field :brew_date
            orientation(:horizontal)
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :batch_number
            end
          end
        end
      end
    end
  end

  describe "workflow" do
    test "needs a state machine" do
      assert_dsl_error ~r/`workflow` shows the state machine of the record, but Brewery.Recipe uses neither/ do
        defmodule NoStateMachine do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :card
            primary? true
            field :name

            workflow do
              type :badge
            end
          end
        end
      end
    end

    test "the engine of a resource" do
      assert PyroManiac.Workflow.engine(Brewery.Recipe) == nil
      assert PyroManiac.Workflow.loads(Brewery.Recipe) == []
    end
  end

  describe "filters" do
    test "the options of a page" do
      assert Info.custom_filters?(RecipePage)
      assert Info.filter_storage(RecipePage) == Preset
      assert Info.shared_filters?(RecipePage)
    end

    test "a storage needs custom_filters?" do
      assert_dsl_error ~r/`filter_storage` saves the filters that the user builds/ do
        defmodule StorageWithoutCustom do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
            filter_storage :client
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end

    test "the delete of a saved filter says if it asks first" do
      assert_dsl_error ~r/the saved filters can be deleted, and the page does not say/ do
        defmodule PresetNoConfirm do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
            custom_filters? true
            filter_storage :client
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end

    test "a shared filter needs a resource" do
      assert_dsl_error ~r/a shared filter is saved in a resource/ do
        defmodule SharedOnClient do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
            custom_filters? true
            filter_storage :client
            delete_preset_confirm(false)
            shared_filters? true
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end

    test "the storage is a filter preset resource" do
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          defmodule StorageNotPresets do
            use PyroManiac, resource: Brewery.Recipe

            page do
              route "/test"
              exclude [:create, :update, :activate, :retire, :destroy, :list]
              custom_filters? true
              filter_storage Brewery.Staff
              delete_preset_confirm(false)
            end

            view :read do
              type :card
              primary? true

              section :main do
                field :name
              end
            end
          end
        end)

      assert output =~
               "Brewery.Staff is not a resource with the `PyroManiac.FilterPresets` extension"
    end

    test "the preset storage resource" do
      names = Preset |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name)

      for name <- [
            :id,
            :name,
            :page,
            :view,
            :filter,
            :sort,
            :inputs,
            :interactive?,
            :shared?,
            :owner_id
          ],
          do: assert(name in names, inspect(name))

      actions = Preset |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert Enum.sort(actions) == [:create, :destroy, :for_page, :read, :update]
      assert PyroManiac.FilterPresets.storage?(Preset)
    end

    # The owner relationship had no `source`: the setup ran after
    # `Ash.Resource.Transformers.SetRelationshipSource`, and the migration
    # generator of AshPostgres crashed on it (`nil` is not a Spark DSL module).
    test "the owner relationship has its source" do
      assert %{source: Preset, destination: Brewery.Staff, source_attribute: :owner_id} =
               Ash.Resource.Info.relationship(Preset, :owner)
    end
  end

  describe "ordering" do
    test "an ordered attribute and its move action" do
      assert %{
               attribute: :position,
               scope: :group,
               move_action: :move,
               algorithm: :fractional_index
             } =
               PyroManiac.Ordering.Info.ordering(Ordered)

      assert %{type: Ash.Type.String} = Ash.Resource.Info.attribute(Ordered, :position)
      assert %{type: :update} = Ash.Resource.Info.action(Ordered, :move)
    end

    test "kanban uses the same ordering" do
      assert %{attribute: :kanban_priority, scope: :status} =
               PyroManiac.Ordering.Info.ordering(Brewery.Batch)
    end

    test "the rank of the order is a default sort without a column" do
      defmodule RankSortPage do
        use PyroManiac, resource: PyroManiac.ViewOptionsTest.Ordered

        page do
          route "/ordered"
        end

        view :read do
          type :data_table
          primary? true
          reorder?(true)
          default_sort "position"
          exclude [:id, :position]

          column :name
          column :group
        end

        view :read do
          type :card
          primary? true

          section :main do
            field :name
          end
        end
      end

      assert [%{default_sort: "position"} | _] = PyroManiac.Info.views(RankSortPage)

      assert_dsl_error ~r/key \[:group\] is an undefined or excluded column/ do
        defmodule OtherSortPage do
          use PyroManiac, resource: PyroManiac.ViewOptionsTest.Ordered

          page do
            route "/ordered-other"
          end

          view :read do
            type :data_table
            primary? true
            default_sort "group"
            exclude [:id, :position, :group]

            column :name
          end

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end

    test "reorder? needs an ordered resource" do
      assert_dsl_error ~r/Brewery.Recipe has no order: `reorder\?` moves a record/ do
        defmodule ReorderWithoutOrder do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :data_table
            primary? true
            reorder?(true)

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

          view :read do
            type :card
            primary? true

            section :main do
              field :name
            end
          end
        end
      end
    end
  end

  describe "the command palette" do
    defmodule Nav do
      @moduledoc false
      use PyroManiac.Navigation

      nav do
        item :recipes do
          page BreweryWeb.RecipeLive
        end
      end

      command_palette do
        hotkey "mod+p"

        command :new_recipe do
          label "New recipe"
          group "Recipes"
          keywords ["create"]
          page BreweryWeb.RecipeLive
          path "/recipes?new"
        end
      end
    end

    test "a page command without a path opens the route of the page" do
      defmodule RoutedPage do
        @moduledoc false
        use PyroManiac, resource: Brewery.Recipe

        page do
          route "/routed-recipes"
          exclude [:create, :update, :destroy, :activate, :retire, :list]
        end

        view :read do
          type :card
          primary? true

          field :name
        end
      end

      defmodule RoutedNav do
        @moduledoc false
        use PyroManiac.Navigation

        command_palette do
          command :recipes do
            label "Recipes"
            page PyroManiac.ViewOptionsTest.RoutedPage
          end
        end
      end

      assert %{commands: [%{path: "/routed-recipes"}]} =
               PyroManiac.Navigation.Info.command_palette(RoutedNav)
    end

    test "the palette and its commands" do
      assert %{enabled?: true, hotkey: "mod+p", navigation?: true, commands: [command]} =
               PyroManiac.Navigation.Info.command_palette(Nav)

      assert %{name: :new_recipe, label: "New recipe", keywords: ["create"]} = command
    end

    test "a command has one target" do
      assert_raise Spark.Error.DslError, ~r/command :nowhere has 0 targets/, fn ->
        defmodule NavNoTarget do
          use PyroManiac.Navigation

          command_palette do
            command :nowhere do
              label "Nowhere"
            end
          end
        end
      end
    end
  end

  describe "decorations" do
    test "the default set" do
      assert Info.decorations() == Info.default_decorations()
      assert :danger in Info.decorations()
    end
  end
end
