Code.put_compiler_option(:debug_info, true)

defmodule PyroManiac.DelegateToTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import PyroManiac.Test.DslError

  alias PyroManiac.Info

  defmodule SourceBatchPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Batch

    page do
      route "/test"
      exclude [:start_brewing, :advance_status, :complete, :move_card, :destroy, :kanban_read]
    end

    view [:read, :list] do
      type :data_table
      primary? true
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

      bulk_action :update do
        state :guard
        select :status, autofocus: true
        field :notes
      end
    end

    view :read do
      type :card

      primary? true

      action [:create, :update], :guard

      field :batch_number, autofocus: true
      combobox :recipe_id
      combobox :brewer_id
      select :status
      field :brew_date
      field :package_date
      field :actual_og
      field :actual_fg
      field :actual_abv
      field :volume_liters
      field :notes
    end
  end

  describe "form action delegate_to" do
    defmodule DelegatingFormPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      page do
        route "/test"
        exclude [:activate, :retire, :destroy, :list, :create, :update]
      end

      view :read do
        type :data_table
        primary? true
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

        action :create do
          state :guard
          label "New Batch"
          resource Brewery.Batch
          delegate_to SourceBatchPage
          set :recipe_id, :id
        end
      end

      view :read do
        type :card

        primary? true

        section :main do
          field :name
        end

        action :update do
          state :guard
          label "Edit Batch"
          resource Brewery.Batch
          delegate_to SourceBatchPage
        end
      end
    end

    test "resolves fields from target module" do
      form = Info.action_for(DelegatingFormPage, :create, Brewery.Batch)
      assert form != nil
      field_names = Enum.map(form.fields, & &1.name)
      assert :batch_number in field_names
      assert :status in field_names
      assert :brew_date in field_names
    end

    test "merges local sets with target sets" do
      form = Info.action_for(DelegatingFormPage, :create, Brewery.Batch)
      set_names = Enum.map(form.sets, & &1.name)
      assert :recipe_id in set_names
    end

    test "resolves update action through delegation" do
      form = Info.action_for(DelegatingFormPage, :update, Brewery.Batch)
      assert form != nil
      field_names = Enum.map(form.fields, & &1.name)
      assert :batch_number in field_names
    end

    test "local metadata overrides target" do
      defmodule LabelOverridePage do
        @moduledoc false
        use PyroManiac, resource: Brewery.Recipe

        page do
          route "/test"
          exclude [:activate, :retire, :destroy, :list]
        end

        view :read do
          type :data_table
          primary? true
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

          action :create do
            state :guard
            resource Brewery.Batch
            delegate_to PyroManiac.DelegateToTest.SourceBatchPage
            set :recipe_id, :id
            label "New Batch for Recipe"
          end
        end

        view :read do
          type :card

          primary? true

          action [:create, :update], :guard

          field :name, autofocus: true
          select :style
          field :description
          field :target_abv
          field :target_og
          field :target_fg
          select :status
          field :photos, type: :attachment
        end
      end

      form = Info.action_for(LabelOverridePage, :create, Brewery.Batch)
      assert form.label == "New Batch for Recipe"
    end

    test "form_for_action_type resolves delegated forms" do
      form = Info.action_for_type(DelegatingFormPage, :create, Brewery.Batch)
      assert form != nil
      assert form.resource == Brewery.Batch
    end

    test "passes existing validation after expansion" do
      form = Info.action_for(DelegatingFormPage, :create, Brewery.Batch)
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

          view :read do
            type :card
            primary? true
            action [:update], :guard

            field :batch_number, autofocus: true
            combobox :recipe_id
            combobox :brewer_id
            select :status
            field :brew_date
            field :package_date
            field :actual_og
            field :actual_fg
            field :actual_abv
            field :volume_liters
            field :notes

            action :start_brewing do
              state :guard
              delegate_to PyroManiac.DelegateToTest.SourceBatchPage
            end
          end

          page do
            route "/test"
            exclude [:create, :advance_status, :complete]
          end
        end
      end
    end

    test "raises when delegate_to has inline fields" do
      assert_dsl_error ~r/delegate_to and inline fields are mutually exclusive/ do
        defmodule V.Delegate.InlineFields do
          @moduledoc false
          use PyroManiac, resource: Brewery.Recipe

          view :read do
            type :card
            primary? true
            action [:create, :update], :guard

            field :name, autofocus: true
            select :style
            field :description
            field :target_abv
            field :target_og
            field :target_fg
            select :status
            field :photos, type: :attachment

            action :create do
              state :guard
              resource Brewery.Batch
              delegate_to PyroManiac.DelegateToTest.SourceBatchPage
              field :batch_number, autofocus: true
            end
          end

          page do
            route "/test"
            exclude [:activate, :retire]
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

                       view :read do
                         type :card
                         primary? true
                         action [:create, :update], :guard

                         field :name, autofocus: true
                         select :style
                         field :description
                         field :target_abv
                         field :target_og
                         field :target_fg
                         select :status
                         field :photos, type: :attachment

                         action :create do
                           state :guard
                           resource Brewery.Batch
                           delegate_to Enum
                         end
                       end

                       page do
                         route "/test"
                         exclude [:activate, :retire]
                       end
                     end
                   end
    end
  end

  describe "bulk action delegate_to" do
    defmodule DelegatingBulkPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Batch

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

      view :read do
        type :data_table
        primary? true
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

        bulk_action :update do
          state :guard
          delegate_to SourceBatchPage
        end
      end

      view :read do
        type :card

        primary? true

        action [:update], :guard

        field :batch_number, autofocus: true
        combobox :recipe_id
        combobox :brewer_id
        select :status
        field :brew_date
        field :package_date
        field :actual_og
        field :actual_fg
        field :actual_abv
        field :volume_liters
        field :notes
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
end
