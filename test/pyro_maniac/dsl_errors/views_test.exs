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
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DuplicateViews do
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
          end
        end
      end
    end

    test "delegated view requires delegate_to" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.DelegatedNeedsDelegateTo]
      views -> view -> delegated defined in <FILE:LINE>:
        delegated views require `delegate_to` to be set

        Fix: add `delegate_to SomeModule` inside the view block, where SomeModule is a PyroManiac module
      │
      <LINE> │             view do
      │             ~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DelegatedNeedsDelegateTo do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view do
              type :delegated
              relationship :batches
            end
          end
        end
      end
    end

    test "delegated view must not have child entities" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.DelegatedHasContent]
      views -> view -> delegated defined in <FILE:LINE>:
        delegated views must not have columns, fields, sections, or nested views — the delegated module owns its own DSL

        Fix: remove all child entities from this view, or change `type :delegated` to a regular type
      │
      <LINE> │             view do
      │             ~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DelegatedHasContent do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view do
              type :delegated
              relationship :batches
              delegate_to PyroManiac.DslErrors.ViewsTest.DelegatedHasContent
              column :name
            end
          end
        end
      end
    end

    test "non-delegated view requires name" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.NonDelegatedNeedsName]
      views -> view defined in <FILE:LINE>:
        non-delegated views require `name` to be set

        Fix: add an action name like `view :read do ... end`
      │
      <LINE> │             view do
      │             ~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule NonDelegatedNeedsName do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view do
              type :data_table
            end
          end
        end
      end
    end

    test "delegate_to only allowed on :delegated views" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.DelegateToOnNonDelegated]
      views -> view -> read defined in <FILE:LINE>:
        `delegate_to` is only allowed on `:delegated` views

        Fix: use `type :delegated` to mount a full sub-Viewer, or remove `delegate_to`
      │
      <LINE> │               delegate_to Some.Module
      │               ~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DelegateToOnNonDelegated do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
              delegate_to Some.Module
            end
          end
        end
      end
    end
  end

  describe "view types requiring specific options" do
    test "render view needs render or component" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.RenderNeedsRenderOrComponent]
      views -> view -> read defined in <FILE:LINE>:
        render views must have either `render` or `component` set

        Fix: set `render fn assigns -> ... end` or `component MyComponent` inside the view block
      │
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule RenderNeedsRenderOrComponent do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :render
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

        Fix: set `date_field :foo` to a date or datetime attribute on the resource
      │
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule CalendarNeedsDateField do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :calendar
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

        Fix: set `start_field :foo` to a date or datetime attribute on the resource
      │
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule GanttNeedsStartField do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :gantt
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

        Fix: set `end_field :foo` to a date or datetime attribute on the resource
      │
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule GanttNeedsEndField do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :gantt
              start_field :inserted_at
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
      <LINE> │             view :reed do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule UnknownAction do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :reed do
              type :data_table
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
      <LINE> │             view :create do
      │             ~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule WrongActionType do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :create do
              type :data_table
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
      <LINE> │               column :name
      │               ~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DuplicateColumnName do
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
      <LINE> │               column :style, label: "Name"
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule DuplicateColumnLabel do
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
              column :style, label: "Name"
              column :description
              column :status
              column :target_abv
              column :target_og
              column :target_fg
              column :gravity_spread
              column :ingredient_count
              column :batch_count
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
      <LINE> │               column :recipe_abv, source: [:recipe, :target_abv_typo]
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule ColumnSourceNotExist do
          use PyroManiac, resource: Brewery.Batch

          forms do
            exclude([:create, :update, :start_brewing, :advance_status, :complete])
          end

          views do
            view :read do
              type :data_table
              default_sort "batch_number"

              exclude([
                :id,
                :recipe,
                :recipe_id,
                :brewer,
                :brewer_id,
                :quality_tests
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
      <LINE> │               column :tester_notes, source: [:tester, :internal_notes]
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule ColumnSourcePrivate do
          use PyroManiac, resource: Brewery.QualityTest

          forms do
            exclude([:create, :update])
          end

          views do
            view :read do
              type :data_table
              default_sort "tested_at"
              exclude([:id, :batch, :batch_id, :tester, :tester_id, :lab_reports])
              column :test_type
              column :tested_at
              column :result
              column :passed
              column :notes
              column :tester_notes, source: [:tester, :internal_notes]
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
        public attribute :description is not a defined or excluded column

        Fix: either add `column :description` or list it in `exclude([...])`
      │
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingPublicAttribute do
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
      <LINE> │               default_display([])
      │               ~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule EmptyDefaultDisplay do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
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
      <LINE> │               default_display([:stat])
      │               ~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule UnknownDefaultDisplay do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
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
      <LINE> │               default_sort ""
      │               ~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule EmptyDefaultSort do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
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
          end
        end
      end
    end

    test "default_sort invalid Ash sort" do
      assert_dsl_error ~r/"---name" is an invalid Ash sort/ do
        defmodule InvalidAshSort do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
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
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule KanbanWithoutExtension do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :kanban
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
      <LINE> │               default_sort "id"
      │               ~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule SortKeyNotInColumns do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
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
        public calculation :gravity_spread is not a defined or excluded column

        Fix: either add `column :gravity_spread` or list it in `exclude([...])`
      │
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingPublicCalculation do
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
              column :ingredient_count
              column :batch_count
            end
          end
        end
      end
    end

    test "missing public aggregation" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.MissingPublicAggregation]
      views -> view -> read defined in <FILE:LINE>:
        public aggregation :ingredient_count is not a defined or excluded column

        Fix: either add `column :ingredient_count` or list it in `exclude([...])`
      │
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingPublicAggregation do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
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
          end
        end
      end
    end

    test "missing public relationship" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.MissingPublicRelationship]
      views -> view -> read defined in <FILE:LINE>:
        public relationship :brewer is not a defined or excluded column

        Fix: either add a column traversing :brewer, or list it in `exclude([...])`
      │
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule MissingPublicRelationship do
          use PyroManiac, resource: Brewery.Batch

          forms do
            exclude([:create, :update, :start_brewing, :advance_status, :complete])
          end

          views do
            view :read do
              type :data_table
              default_sort "batch_number"

              exclude([
                :id,
                :recipe,
                :recipe_id,
                :brewer_id,
                :quality_tests,
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
          end
        end
      end
    end
  end

  describe "realtime / pub_sub" do
    test "realtime options without pub_sub prefix" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.RealtimeWithoutPubSub]
      views -> view -> read defined in <FILE:LINE>:
        view has realtime options (on_create/on_update/on_destroy) but the resource Brewery.Supplier does not have a pub_sub configuration with a prefix

        Fix: add a `pub_sub do prefix "..." end` block to the resource
      │
      <LINE> │             view :read do
      │             ~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule RealtimeWithoutPubSub do
          use PyroManiac, resource: Brewery.Supplier

          forms do
            exclude([:create, :update])
          end

          views do
            view :read do
              type :data_table
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
          end
        end
      end
    end
  end

  describe "edit_with" do
    test "edit_with invalid input type with did-you-mean" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.EditWithInvalidType]
      views -> view -> read -> column -> name defined in <FILE:LINE>:
        edit_with input type :txt is not valid. Must be one of: [:autocomplete, :checkbox, :color, :date, :datetime, :email, :number, :password, :range, :select, :tel, :text, :textarea, :time, :url]

        Did you mean:
          * :text
          * :textarea
      │
      <LINE> │               column :name, edit_with: :txt
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule EditWithInvalidType do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
              default_sort "name"

              exclude([
                :id,
                :recipe_ingredients,
                :batches,
                :photos,
                :photos_urls,
                :gravity_spread
              ])

              column :name, edit_with: :txt
              column :style
              column :description
              column :status
              column :target_abv
              column :target_og
              column :target_fg
              column :ingredient_count
              column :batch_count
            end
          end
        end
      end
    end

    test "edit_with references unknown action with did-you-mean" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.EditWithUnknownAction]
      views -> view -> read -> column -> name defined in <FILE:LINE>:
        edit_with references action :updaet which does not exist or is not an update action

        Did you mean:
          * :update
      │
      <LINE> │               column :name, edit_with: {:updaet, :text}
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule EditWithUnknownAction do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
              default_sort "name"

              exclude([
                :id,
                :recipe_ingredients,
                :batches,
                :photos,
                :photos_urls,
                :gravity_spread
              ])

              column :name, edit_with: {:updaet, :text}
              column :style
              column :description
              column :status
              column :target_abv
              column :target_og
              column :target_fg
              column :ingredient_count
              column :batch_count
            end
          end
        end
      end
    end

    test "edit_with on column whose action does not accept the field" do
      expected = """
      [PyroManiac.DslErrors.ViewsTest.EditWithFieldNotAccepted]
      views -> view -> read -> column -> status defined in <FILE:LINE>:
        edit_with on column :status but action :activate does not accept field :status

        Fix: either add :status to the action's `accept` list, or pick an action that accepts it
      │
      <LINE> │               column :status, edit_with: {:activate, :select}
      │               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ <FILE:LINE>: (file)\
      """

      assert_dsl_error expected do
        defmodule EditWithFieldNotAccepted do
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
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
              column :status, edit_with: {:activate, :select}
              column :target_abv
              column :target_og
              column :target_fg
              column :ingredient_count
              column :batch_count
            end
          end
        end
      end
    end
  end
end
