Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DelegateToTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import PyroManiac.Test.DslError

  alias PyroManiac.Info

  defmodule SourceBatchPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Batch

    forms do
      exclude([:start_brewing, :advance_status, :complete, :move_card])

      action [:create, :update] do
        field :batch_number, autofocus: true
        field :recipe_id
        field :brewer_id
        field :status
        field :brew_date
        field :package_date
        field :actual_og
        field :actual_fg
        field :actual_abv
        field :volume_liters
        field :notes
      end

      bulk_action :update do
        field :status, autofocus: true
        field :notes
      end
    end

    views do
      view [:read, :list] do
        type :data_table
        default_sort "-batch_number"
        exclude([:id, :recipe_id, :brewer_id, :recipe, :brewer, :kanban_priority])
        column(:batch_number, sortable?: true)
        column(:status, sortable?: true)
        column(:brew_date)
        column(:package_date)
        column(:actual_og)
        column(:actual_fg)
        column(:actual_abv)
        column(:volume_liters)
        column(:notes)
        column(:test_count)
        column(:passed_test_count)
        column(:pass_rate)
      end
    end
  end

  describe "form action delegate_to" do
    defmodule DelegatingFormPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      forms do
        exclude([:activate, :retire])

        action [:create, :update] do
          field :name, autofocus: true
          field :style
          field :description
          field :target_abv
          field :target_og
          field :target_fg
          field :status
          field :photos, type: :attachment
        end

        action :create do
          label "New Batch"
          resource Brewery.Batch
          delegate_to(SourceBatchPage)
          set :recipe_id, :id
        end

        action :update do
          label "Edit Batch"
          resource Brewery.Batch
          delegate_to(SourceBatchPage)
        end
      end

      views do
        view :read do
          type :data_table
          default_sort "name"
          exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
          column(:name)
          column(:style)
          column(:description)
          column(:status)
          column(:target_abv)
          column(:target_og)
          column(:target_fg)
          column(:gravity_spread)
          column(:ingredient_count)
          column(:batch_count)
        end
      end
    end

    test "resolves fields from target module" do
      form = Info.form_for(DelegatingFormPage, :create, Brewery.Batch)
      assert form != nil
      field_names = Enum.map(form.fields, & &1.name)
      assert :batch_number in field_names
      assert :status in field_names
      assert :brew_date in field_names
    end

    test "merges local sets with target sets" do
      form = Info.form_for(DelegatingFormPage, :create, Brewery.Batch)
      set_names = Enum.map(form.sets, & &1.name)
      assert :recipe_id in set_names
    end

    test "resolves update action through delegation" do
      form = Info.form_for(DelegatingFormPage, :update, Brewery.Batch)
      assert form != nil
      field_names = Enum.map(form.fields, & &1.name)
      assert :batch_number in field_names
    end

    test "local metadata overrides target" do
      defmodule LabelOverridePage do
        @moduledoc false
        use PyroManiac, resource: Brewery.Recipe

        forms do
          exclude([:activate, :retire])

          action [:create, :update] do
            field :name, autofocus: true
            field :style
            field :description
            field :target_abv
            field :target_og
            field :target_fg
            field :status
            field :photos, type: :attachment
          end

          action :create do
            resource Brewery.Batch
            delegate_to(PyroManiac.DelegateToTest.SourceBatchPage)
            set :recipe_id, :id
            label("New Batch for Recipe")
          end
        end

        views do
          view :read do
            type :data_table
            default_sort "name"
            exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
            column(:name)
            column(:style)
            column(:description)
            column(:status)
            column(:target_abv)
            column(:target_og)
            column(:target_fg)
            column(:gravity_spread)
            column(:ingredient_count)
            column(:batch_count)
          end
        end
      end

      form = Info.form_for(LabelOverridePage, :create, Brewery.Batch)
      assert form.label == "New Batch for Recipe"
    end

    test "form_for_action_type resolves delegated forms" do
      form = Info.form_for_action_type(DelegatingFormPage, :create, Brewery.Batch)
      assert form != nil
      assert form.resource == Brewery.Batch
    end

    test "passes existing validation after expansion" do
      form = Info.form_for(DelegatingFormPage, :create, Brewery.Batch)
      refute Enum.empty?(form.fields)
      autofocus_count = Enum.count(form.fields, & &1.autofocus)
      assert autofocus_count == 1
    end
  end

  describe "form action delegate_to errors" do
    test "raises when delegate_to target has no matching action" do
      assert_dsl_error ~r/has no form action :start_brewing/ do
        defmodule V.Delegate.NoMatchingAction do
          @moduledoc false
          use PyroManiac, resource: Brewery.Batch

          forms do
            exclude([:create, :advance_status, :complete])

            action :update do
              field :batch_number, autofocus: true
              field :recipe_id
              field :brewer_id
              field :status
              field :brew_date
              field :package_date
              field :actual_og
              field :actual_fg
              field :actual_abv
              field :volume_liters
              field :notes
            end

            action :start_brewing do
              delegate_to(PyroManiac.DelegateToTest.SourceBatchPage)
            end
          end
        end
      end
    end

    test "raises when delegate_to has inline fields" do
      assert_dsl_error ~r/delegate_to and inline fields are mutually exclusive/ do
        defmodule V.Delegate.InlineFields do
          @moduledoc false
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:activate, :retire])

            action [:create, :update] do
              field :name, autofocus: true
              field :style
              field :description
              field :target_abv
              field :target_og
              field :target_fg
              field :status
              field :photos, type: :attachment
            end

            action :create do
              resource Brewery.Batch
              delegate_to(PyroManiac.DelegateToTest.SourceBatchPage)
              field :batch_number, autofocus: true
            end
          end
        end
      end
    end
  end

  describe "form action delegate_to errors (non-PyroManiac target)" do
    test "raises when delegate_to target is not a PyroManiac module" do
      assert_raise RuntimeError,
                   fn ->
                     defmodule V.Delegate.NotPyroManiac do
                       @moduledoc false
                       use PyroManiac, resource: Brewery.Recipe

                       forms do
                         exclude([:activate, :retire])

                         action [:create, :update] do
                           field :name, autofocus: true
                           field :style
                           field :description
                           field :target_abv
                           field :target_og
                           field :target_fg
                           field :status
                           field :photos, type: :attachment
                         end

                         action :create do
                           resource Brewery.Batch
                           delegate_to(Enum)
                         end
                       end
                     end
                   end
    end
  end

  describe "delegated view type" do
    defmodule DelegatingViewPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      forms do
        exclude([:create, :update, :activate, :retire])
      end

      views do
        view :read do
          type :data_table
          default_sort "name"
          exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
          column(:name)
          column(:style)
          column(:description)
          column(:status)
          column(:target_abv)
          column(:target_og)
          column(:target_fg)
          column(:gravity_spread)
          column(:ingredient_count)
          column(:batch_count)

          view do
            type :delegated
            relationship(:batches)
            delegate_to(SourceBatchPage)
          end
        end
      end
    end

    test "delegated view is stored as nested view" do
      view = Info.view_for(DelegatingViewPage, :read, :data_table)
      nested = hd(view.views)
      assert nested.type == :delegated
      assert nested.delegate_to == SourceBatchPage
      assert nested.relationship == :batches
    end

    test "delegated view has no name" do
      view = Info.view_for(DelegatingViewPage, :read, :data_table)
      nested = hd(view.views)
      assert nested.name == []
    end

    test "delegated view does not contribute to nested_view_loads" do
      view = Info.view_for(DelegatingViewPage, :read, :data_table)
      assert Info.nested_view_loads(view) == []
    end
  end

  describe "delegated view errors" do
    test "raises when delegated view has no delegate_to" do
      assert_dsl_error ~r/delegated views require `delegate_to` to be set/ do
        defmodule V.Delegate.NoDelegateTo do
          @moduledoc false
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
              default_sort "name"
              exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
              column(:name)
              column(:style)
              column(:description)
              column(:status)
              column(:target_abv)
              column(:target_og)
              column(:target_fg)
              column(:gravity_spread)
              column(:ingredient_count)
              column(:batch_count)

              view do
                type :delegated
                relationship(:batches)
              end
            end
          end
        end
      end
    end

    test "raises when delegated view has inline columns" do
      assert_dsl_error ~r/delegated views must not have columns/ do
        defmodule V.Delegate.InlineColumns do
          @moduledoc false
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
              default_sort "name"
              exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
              column(:name)
              column(:style)
              column(:description)
              column(:status)
              column(:target_abv)
              column(:target_og)
              column(:target_fg)
              column(:gravity_spread)
              column(:ingredient_count)
              column(:batch_count)

              view do
                type :delegated
                relationship(:batches)
                delegate_to(SourceBatchPage)
                column(:batch_number)
              end
            end
          end
        end
      end
    end

    test "raises when non-delegated view has delegate_to" do
      assert_dsl_error ~r/`delegate_to` is only allowed on `:delegated` views/ do
        defmodule V.Delegate.WrongType do
          @moduledoc false
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
              default_sort "name"
              exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
              column(:name)
              column(:style)
              column(:description)
              column(:status)
              column(:target_abv)
              column(:target_og)
              column(:target_fg)
              column(:gravity_spread)
              column(:ingredient_count)
              column(:batch_count)

              view :read do
                type :data_table
                relationship(:batches)
                delegate_to(SourceBatchPage)
              end
            end
          end
        end
      end
    end

    test "raises when non-delegated view has no name" do
      assert_dsl_error ~r/non-delegated views require `name` to be set/ do
        defmodule V.Delegate.NoName do
          @moduledoc false
          use PyroManiac, resource: Brewery.Recipe

          forms do
            exclude([:create, :update, :activate, :retire])
          end

          views do
            view :read do
              type :data_table
              default_sort "name"
              exclude([:id, :recipe_ingredients, :batches, :photos, :photos_urls])
              column(:name)
              column(:style)
              column(:description)
              column(:status)
              column(:target_abv)
              column(:target_og)
              column(:target_fg)
              column(:gravity_spread)
              column(:ingredient_count)
              column(:batch_count)

              view do
                type :data_table
                relationship(:batches)
              end
            end
          end
        end
      end
    end
  end

  describe "bulk action delegate_to" do
    defmodule DelegatingBulkPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Batch

      forms do
        exclude([:create, :start_brewing, :advance_status, :complete, :move_card])

        action :update do
          field :batch_number, autofocus: true
          field :recipe_id
          field :brewer_id
          field :status
          field :brew_date
          field :package_date
          field :actual_og
          field :actual_fg
          field :actual_abv
          field :volume_liters
          field :notes
        end

        bulk_action :update do
          delegate_to(SourceBatchPage)
        end
      end

      views do
        view :read do
          type :data_table
          default_sort "-batch_number"
          exclude([:id, :recipe_id, :brewer_id, :recipe, :brewer, :kanban_priority])
          column(:batch_number)
          column(:status)
          column(:brew_date)
          column(:package_date)
          column(:actual_og)
          column(:actual_fg)
          column(:actual_abv)
          column(:volume_liters)
          column(:notes)
          column(:test_count)
          column(:passed_test_count)
          column(:pass_rate)
        end
      end
    end

    test "resolves bulk action fields from target module" do
      ba = Info.bulk_action_for(DelegatingBulkPage, :update)
      assert ba != nil
      field_names = Enum.map(ba.fields, & &1.name)
      assert :status in field_names
      assert :notes in field_names
    end
  end

  describe "double-nested delegated views" do
    defmodule DoubleNestedPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      forms do
        exclude([:create, :update, :activate, :retire])
      end

      views do
        view :read do
          type :data_table
          default_sort "name"
          exclude([:id, :recipe_ingredients, :photos, :photos_urls])
          column(:name)
          column(:style)
          column(:description)
          column(:status)
          column(:target_abv)
          column(:target_og)
          column(:target_fg)
          column(:gravity_spread)
          column(:ingredient_count)
          column(:batch_count)

          view do
            type :delegated
            relationship(:batches)
            delegate_to(BreweryWeb.BatchLive)
          end
        end
      end
    end

    test "delegated view references the target module" do
      view = Info.view_for(DoubleNestedPage, :read, :data_table)
      batch_view = hd(view.views)
      assert batch_view.type == :delegated
      assert batch_view.delegate_to == BreweryWeb.BatchLive
      assert batch_view.relationship == :batches
    end

    test "delegated module's own views are intact" do
      batch_views = Info.views(BreweryWeb.BatchLive)
      refute Enum.empty?(batch_views)
      dt_view = Info.view_for(BreweryWeb.BatchLive, :read, :data_table)
      assert dt_view != nil
      column_names = Enum.map(dt_view.columns, & &1.name)
      assert :batch_number in column_names
      assert :pass_rate in column_names
    end

    test "delegated module contains its own nested delegated views" do
      dt_view = Info.view_for(BreweryWeb.BatchLive, :read, :data_table)
      assert [qt_view] = dt_view.views
      assert qt_view.type == :delegated
      assert qt_view.delegate_to == BreweryWeb.QualityTestLive
      assert qt_view.relationship == :quality_tests
    end
  end
end
