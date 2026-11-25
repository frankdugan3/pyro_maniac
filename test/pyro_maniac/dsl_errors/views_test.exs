Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DslErrors.ViewsTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import PyroManiac.Test.DslError

  describe "view structure" do
    test "duplicate views (same action + type)" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.DuplicateViews]
      views -> view -> read -> data_table defined in <FILE:LINE>:
        view {:read, :data_table} is already defined. Each action + type combination must be unique.
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DuplicateViews do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
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
          end

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

    test "a view requires a name" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.NonDelegatedNeedsName]
      views -> view defined in <FILE:LINE>:
        a view requires `name` to be set

        Fix: add an action name like `view :read do ... end`
      │
      <LINE> │           view do
      │           ~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule NonDelegatedNeedsName do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view do
            type :data_table
            primary? true
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

  describe "view types requiring specific options" do
    test "a render view needs a render" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.RenderNeedsRenderOrComponent]
      views -> view -> read defined in <FILE:LINE>:
        a `:render` view has a `render` for each renderer of the page

        Fix: add `render PyroManiac.LiveView, BreweryWeb.Components.Dashboard` inside the view block
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule RenderNeedsRenderOrComponent do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :render
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

    test "calendar view needs date_field with did-you-mean" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.CalendarNeedsDateField]
      views -> view -> read -> date_field defined in <FILE:LINE>:
        calendar views require `date_field` to be set

        Fix: set `date_field :brew_date` to a date or datetime attribute on the resource
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule CalendarNeedsDateField do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :calendar
            primary? true
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

    test "gantt view requires start_field" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.GanttNeedsStartField]
      views -> view -> read -> start_field defined in <FILE:LINE>:
        gantt views require `start_field` to be set

        Fix: set `start_field :brew_date` to a date or datetime attribute on the resource
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule GanttNeedsStartField do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :gantt
            primary? true
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

    test "gantt view requires end_field when start_field provided" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.GanttNeedsEndField]
      views -> view -> read -> end_field defined in <FILE:LINE>:
        gantt views require `end_field` to be set

        Fix: set `end_field :package_date` to a date or datetime attribute on the resource
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule GanttNeedsEndField do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :gantt
            primary? true
            start_field :inserted_at
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

  describe "action validation" do
    test "action not found suggests near matches" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.UnknownAction]
      views -> view -> reed defined in <FILE:LINE>:
        action :reed not found on resource Brewery.Recipe

        Did you mean:
          * :read
      │
      <LINE> │           view :reed do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule UnknownAction do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:update, :activate, :retire]
          end

          view :reed do
            type :data_table
            primary? true
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

    test "action wrong type" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.WrongActionType]
      views -> view -> create defined in <FILE:LINE>:
        action :create is type :create, but views require :read actions

        Fix: pick a read action, or change action :create to type :read
      │
      <LINE> │           view :create do
      │           ~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule WrongActionType do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:update, :activate, :retire]
          end

          view :create do
            type :data_table
            primary? true
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

  describe "column validation" do
    test "duplicate column name" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.DuplicateColumnName]
      views -> view -> read -> column -> name defined in <FILE:LINE>:
        column :name is already defined
      │
      <LINE> │             column :name
      │             ~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DuplicateColumnName do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "name"
            exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
            column :name
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

    test "duplicate column label" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.DuplicateColumnLabel]
      views -> view -> read -> column -> style defined in <FILE:LINE>:
        another column already uses the label "Name"
      │
      <LINE> │             column :style do
      │             ~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DuplicateColumnLabel do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire, :destroy, :list]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "name"
            exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
            column :name

            column :style do
              label "Name"
            end

            column :description
            column :status
            column :target_abv
            column :target_og
            column :target_fg
            column :gravity_spread
            column :ingredient_count
            column :batch_count
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

    test "column source not exist suggests near matches" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.ColumnSourceNotExist]
      views -> view -> read -> column -> recipe_abv defined in <FILE:LINE>:
        column :recipe_abv source [:recipe] -> :target_abv_typo does not exist on Brewery.Recipe

        Did you mean:
          * :target_abv
      │
      <LINE> │             column :recipe_abv, source: [:recipe, :target_abv_typo]
      │             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule ColumnSourceNotExist do
          use PyroManiac, resource: Brewery.Batch

          page do
            route "/test"
            exclude [:create, :update, :start_brewing, :advance_status, :complete]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "batch_number"

            exclude([
              :id,
              :recipe,
              :recipe_id,
              :brewer,
              :brewer_id
            ])

            column :batch_number
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
            column :recipe_abv, source: [:recipe, :target_abv_typo]
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

    test "column source not public" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.ColumnSourcePrivate]
      views -> view -> read -> column -> tester_notes defined in <FILE:LINE>:
        column :tester_notes source [:tester] -> :internal_notes is not public on Brewery.Staff

        Fix: mark the field public on Brewery.Staff, or pick a different source
      │
      <LINE> │             column :tester_notes, source: [:tester, :internal_notes]
      │             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule ColumnSourcePrivate do
          use PyroManiac, resource: Brewery.QualityTest

          page do
            route "/test"
            exclude [:create, :update]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "tested_at"
            exclude([:id, :batch, :batch_id, :tester, :tester_id, :lab_reports])
            column :test_type
            column :tested_at
            column :result
            column :passed
            column :notes
            column :tester_notes, source: [:tester, :internal_notes]
          end

          view :read do
            type :card

            primary? true

            section :main do
              field :test_type
            end
          end
        end
      end
    end
  end

  describe "public field coverage" do
    test "missing public attribute" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.MissingPublicAttribute]
      views -> view -> read defined in <FILE:LINE>:
        exposed field :description is not a defined or excluded column

        Fix: either add `column :description` or list it in `exclude([...])`
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingPublicAttribute do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "name"
            exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
            column :name
            column :style
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

  describe "default_display" do
    test "default_display [] requires at least one column" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.EmptyDefaultDisplay]
      views -> view -> read -> default_display defined in <FILE:LINE>:
        must display at least one column by default

        Fix: list at least one column name, e.g. `default_display([:name, :status])`
      │
      <LINE> │             default_display([])
      │             ~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule EmptyDefaultDisplay do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "name"
            default_display([])

            exclude([
              :id,
              :recipe_ingredients,
              :batches,
              :photos,
              :photos_urls,
              :gravity_spread
            ])

            column :name
            column :style
            column :description
            column :status
            column :target_abv
            column :target_og
            column :target_fg
            column :ingredient_count
            column :batch_count
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

    test "default_display references unknown column with did-you-mean" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.UnknownDefaultDisplay]
      views -> view -> read -> default_display defined in <FILE:LINE>:
        :stat is an undefined or excluded column

        Did you mean:
          * :status
      │
      <LINE> │             default_display([:stat])
      │             ~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule UnknownDefaultDisplay do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "name"
            default_display([:stat])

            exclude([
              :id,
              :recipe_ingredients,
              :batches,
              :photos,
              :photos_urls,
              :gravity_spread
            ])

            column :name
            column :style
            column :description
            column :status
            column :target_abv
            column :target_og
            column :target_fg
            column :ingredient_count
            column :batch_count
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

  describe "default_sort" do
    test "default_sort empty string" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.EmptyDefaultSort]
      views -> view -> read -> default_sort defined in <FILE:LINE>:
        "": must sort on at least one column
      │
      <LINE> │             default_sort ""
      │             ~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule EmptyDefaultSort do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
            default_sort ""

            exclude([
              :id,
              :recipe_ingredients,
              :batches,
              :photos,
              :photos_urls,
              :gravity_spread
            ])

            column :name
            column :style
            column :description
            column :status
            column :target_abv
            column :target_og
            column :target_fg
            column :ingredient_count
            column :batch_count
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

    test "default_sort invalid Ash sort" do
      assert_dsl_error ~r/"---name" is an invalid Ash sort/ do
        defmodule InvalidAshSort do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "---name"

            exclude([
              :id,
              :recipe_ingredients,
              :batches,
              :photos,
              :photos_urls,
              :gravity_spread
            ])

            column :name
            column :style
            column :description
            column :status
            column :target_abv
            column :target_og
            column :target_fg
            column :ingredient_count
            column :batch_count
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

  describe "kanban" do
    test "kanban view requires KanBan extension on resource" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.KanbanWithoutExtension]
      views -> view -> read defined in <FILE:LINE>:
        kanban views require the resource Brewery.Recipe to use the PyroManiac.KanBan extension

        Fix: add `use PyroManiac.KanBan` to the resource
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule KanbanWithoutExtension do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :kanban
            primary? true
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

  describe "kanban options" do
    test "a kanban view takes its options from the kan_ban section" do
      assert_dsl_error ~r/a `:kanban` view takes `group_by` from the `kan_ban` section/ do
        defmodule KanbanWithGroupBy do
          use PyroManiac, resource: Brewery.Batch

          page do
            route "/test"
            exclude [:create, :update, :start_brewing, :advance_status, :complete, :move_card]
          end

          view :kanban_read do
            type :kanban
            primary? true
            group_by :status
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

  describe "ensure_loaded" do
    test "ensure_loaded with unknown field" do
      assert_dsl_error ~r/\[:bogus\] is an invalid Ash load statement for Brewery\.Staff/ do
        defmodule EnsureLoadedUnknownField do
          use PyroManiac, resource: Brewery.Staff

          page do
            route "/test"
            exclude [:create, :update, :deactivate]
          end

          view :read do
            type :data_table
            primary? true
            ensure_loaded([:bogus])
            exclude([:id, :name_email])
            column :name
            column :email
            column :role
            column :active
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

  describe "default_sort key validation" do
    test "default_sort references column not defined in view (with did-you-mean)" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.SortKeyNotInColumns]
      views -> view -> read -> default_sort defined in <FILE:LINE>:
        key [:id] is an undefined or excluded column
      │
      <LINE> │             default_sort "id"
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule SortKeyNotInColumns do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "id"

            exclude([
              :id,
              :recipe_ingredients,
              :batches,
              :photos,
              :photos_urls,
              :gravity_spread
            ])

            column :name
            column :style
            column :description
            column :status
            column :target_abv
            column :target_og
            column :target_fg
            column :ingredient_count
            column :batch_count
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

  describe "public field coverage (additional kinds)" do
    test "missing public calculation" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.MissingPublicCalculation]
      views -> view -> read defined in <FILE:LINE>:
        exposed field :gravity_spread is not a defined or excluded column

        Fix: either add `column :gravity_spread` or list it in `exclude([...])`
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingPublicCalculation do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "name"
            exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
            column :name
            column :style
            column :description
            column :status
            column :target_abv
            column :target_og
            column :target_fg
            column :ingredient_count
            column :batch_count
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

    test "missing public aggregation" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.MissingPublicAggregation]
      views -> view -> read defined in <FILE:LINE>:
        exposed field :ingredient_count is not a defined or excluded column

        Fix: either add `column :ingredient_count` or list it in `exclude([...])`
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingPublicAggregation do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :update, :activate, :retire]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "name"

            exclude([
              :id,
              :recipe_ingredients,
              :batches,
              :photos,
              :photos_urls,
              :gravity_spread
            ])

            column :name
            column :style
            column :description
            column :status
            column :target_abv
            column :target_og
            column :target_fg
            column :batch_count
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

    test "missing public relationship" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.MissingPublicRelationship]
      views -> view -> read defined in <FILE:LINE>:
        exposed relationship :brewer is not a defined or excluded column

        Fix: either add a column traversing :brewer, or list it in `exclude([...])`
      │
      <LINE> │           view :read do
      │           ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingPublicRelationship do
          use PyroManiac, resource: Brewery.Batch

          page do
            route "/test"
            exclude [:create, :update, :start_brewing, :advance_status, :complete]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "batch_number"

            exclude([
              :id,
              :recipe,
              :recipe_id,
              :brewer_id,
              :kanban_priority,
              :pass_rate
            ])

            column :batch_number
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

  describe "realtime / pub_sub" do
    test "realtime options without pub_sub prefix" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.RealtimeWithoutPubSub]
      views -> view -> read -> on_create defined in <FILE:LINE>:
        the view has realtime options (`on_create`), but Brewery.Supplier has no `realtime` section

        Fix: add `realtime do mode :auto end` to the `pyro_maniac` section of Brewery.Supplier
      │
      <LINE> │             on_create :notify
      │             ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule RealtimeWithoutPubSub do
          use PyroManiac, resource: Brewery.Supplier

          page do
            route "/test"
            exclude [:create, :update]
          end

          view :read do
            type :data_table
            primary? true
            default_sort "name"
            exclude([:id])
            on_create :notify
            column :name
            column :code
            column :contact_email
            column :phone
            column :active
            column :notes
            column :ingredient_count
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

  describe "inline edits" do
    test "the action of a column has the inputs of the cell" do
      assert_dsl_error ~r/the `action` of column :status has no inputs/ do
        defmodule ColumnActionNoInputs do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :activate, :retire, :destroy, :list]
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
              :gravity_spread,
              :ingredient_count,
              :batch_count,
              :style
            ]

            column :name

            column :status do
              action :update, :guard
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

    test "the inputs of a column action are inputs of the action" do
      assert_dsl_error ~r/:batch_count is not an input of :update. An inline edit has inputs only/ do
        defmodule ColumnActionNotAccepted do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :activate, :retire, :destroy, :list]
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
              :gravity_spread,
              :ingredient_count,
              :style,
              :status
            ]

            column :name

            column :batch_count do
              action :update do
                state :guard
                field :batch_count, autofocus: true
              end
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

    test "edit_columns names columns of the view" do
      assert_dsl_error ~r/:nope is not a column of the view/ do
        defmodule EditColumnsUnknown do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :activate, :retire, :destroy, :list]
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
              :target_fg,
              :gravity_spread,
              :ingredient_count,
              :batch_count,
              :style,
              :status
            ]

            column :name
            column :target_og

            edit_columns :update, [:target_og, :nope] do
              state :guard
              field :target_og, autofocus: true
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

    test "a column in edit_columns has no action of its own" do
      assert_dsl_error ~r/column :target_og is in `edit_columns`, so it has no `action` of its own/ do
        defmodule EditColumnsAndCellAction do
          use PyroManiac, resource: Brewery.Recipe

          page do
            route "/test"
            exclude [:create, :activate, :retire, :destroy, :list]
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
              :target_fg,
              :gravity_spread,
              :ingredient_count,
              :batch_count,
              :style,
              :status
            ]

            column :name

            column :target_og do
              action :update do
                state :guard
                field :target_og, autofocus: true
              end
            end

            column :target_fg

            edit_columns :update, [:target_og, :target_fg] do
              state :guard
              field :target_og, autofocus: true
              field :target_fg
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

    test "a column action and edit_columns are actions of the page" do
      defmodule InlineEditsPage do
        use PyroManiac, resource: Brewery.Recipe

        page do
          route "/test"
          exclude [:create, :activate, :retire, :destroy, :list]
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
            :gravity_spread,
            :ingredient_count,
            :batch_count,
            :style
          ]

          column :name

          column :status do
            action :update do
              state :guard
              select :status, autofocus: true
            end
          end

          column :target_og
          column :target_fg

          edit_columns :update, [:target_og, :target_fg] do
            state :guard
            field :target_og, autofocus: true
            field :target_fg
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

      actions = PyroManiac.Info.actions(InlineEditsPage)

      assert %{__column__: :status, fields: [%{name: :status}]} =
               Enum.find(actions, &(&1.__column__ == :status))

      assert %{__columns__: [:target_og, :target_fg]} =
               Enum.find(actions, &(&1.__columns__ != []))
    end
  end
end
