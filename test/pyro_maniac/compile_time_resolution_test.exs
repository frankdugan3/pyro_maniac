defmodule PyroManiac.CompileTimeResolutionTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias PyroManiac.Info

  defmodule RecipePage do
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
    end

    views do
      view [:read, :list] do
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

  defmodule StaffPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Staff

    views do
      view [:read, :list] do
        type :data_table
        default_sort "email"
        exclude([:id, :name_email])
        column(:name)
        column(:email)
        column(:role)
        column(:active)
      end
    end

    forms do
      exclude([:deactivate])

      action [:create, :update] do
        field :name, autofocus: true
        field :email
        field :role
        field :active
      end
    end
  end

  defmodule BatchPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Batch

    forms do
      exclude([:start_brewing, :advance_status, :complete, :move_card])

      action [:create, :update] do
        field :batch_number, autofocus: true
        field :status
        field :brew_date
        field :package_date
        field :actual_og
        field :actual_fg
        field :actual_abv
        field :volume_liters
        field :notes
        field :recipe_id
        field :brewer_id
      end
    end

    views do
      view [:read, :list] do
        type :data_table
        default_sort "batch_number"

        exclude([
          :id,
          :kanban_priority,
          :pass_rate,
          :recipe,
          :recipe_id,
          :brewer,
          :brewer_id,
          :quality_tests
        ])

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
      end
    end
  end

  describe "field type resolution" do
    test "string fields resolve to :text" do
      field = get_field(RecipePage, :create, :name)
      assert field.type == :text
    end

    test "enum fields (custom Ash enum) resolve to :select" do
      field = get_field(RecipePage, :create, :style)
      assert field.type == :select
    end

    test "enum fields (one_of constraint) resolve to :select" do
      field = get_field(RecipePage, :create, :status)
      assert field.type == :select
    end

    test "decimal fields resolve to :number" do
      field = get_field(RecipePage, :create, :target_abv)
      assert field.type == :number
    end

    test "boolean fields resolve to :boolean" do
      field = get_field(StaffPage, :create, :active)
      assert field.type == :boolean
    end

    test "date fields resolve to :date" do
      field = get_field(BatchPage, :create, :brew_date)
      assert field.type == :date
    end

    test "explicit types are preserved" do
      field = get_field(RecipePage, :create, :photos)
      assert field.type == :attachment
    end
  end

  describe "enum_options resolution" do
    test "custom Ash enum populates enum_options" do
      field = get_field(RecipePage, :create, :style)
      assert is_list(field.enum_options)
      refute Enum.empty?(field.enum_options)
      assert {"IPA", :ipa} in field.enum_options
    end

    test "one_of constraint populates enum_options" do
      field = get_field(RecipePage, :create, :status)
      assert is_list(field.enum_options)
      refute Enum.empty?(field.enum_options)
      values = Enum.map(field.enum_options, &elem(&1, 1))
      assert :draft in values
      assert :active in values
      assert :retired in values
    end

    test "non-enum fields have empty enum_options" do
      field = get_field(RecipePage, :create, :name)
      assert field.enum_options == []
    end
  end

  describe "allow_nil? resolution" do
    test "required fields have allow_nil? false" do
      field = get_field(RecipePage, :create, :name)
      assert field.allow_nil? == false
    end

    test "optional fields have allow_nil? true" do
      field = get_field(RecipePage, :create, :description)
      assert field.allow_nil? == true
    end
  end

  describe "Info.resolve_field_type/3" do
    test "infers :text for string attributes" do
      assert Info.resolve_field_type(Brewery.Recipe, :name) == :text
    end

    test "infers :select for custom enum types" do
      assert Info.resolve_field_type(Brewery.Recipe, :style) == :select
    end

    test "infers :select for one_of constraints" do
      assert Info.resolve_field_type(Brewery.Recipe, :status) == :select
    end

    test "infers :number for decimal types" do
      assert Info.resolve_field_type(Brewery.Recipe, :target_abv) == :number
    end

    test "infers :boolean for boolean types" do
      assert Info.resolve_field_type(Brewery.Staff, :active) == :boolean
    end

    test "infers :date for date types" do
      assert Info.resolve_field_type(Brewery.Batch, :brew_date) == :date
    end

    test "explicit override passes through" do
      assert Info.resolve_field_type(Brewery.Recipe, :name, :password) == :password
    end
  end

  describe "Info.enum_options_for/2" do
    test "returns options for custom Ash enum" do
      opts = Info.enum_options_for(Brewery.Recipe, :style)
      assert is_list(opts)
      assert {"IPA", :ipa} in opts
    end

    test "returns options for one_of constraint" do
      opts = Info.enum_options_for(Brewery.Recipe, :status)
      assert is_list(opts)
      values = Enum.map(opts, &elem(&1, 1))
      assert :draft in values
    end

    test "returns nil for non-enum field" do
      assert Info.enum_options_for(Brewery.Recipe, :name) == nil
    end
  end

  describe "Info.field_allow_nil?/2" do
    test "returns false for required fields" do
      assert Info.field_allow_nil?(Brewery.Recipe, :name) == false
    end

    test "returns true for optional fields" do
      assert Info.field_allow_nil?(Brewery.Recipe, :description) == true
    end
  end

  describe "extensible field types" do
    test "extra_form_types allows custom types" do
      defmodule V.CompileTime.ExtraFormTypes do
        @moduledoc false
        use PyroManiac, resource: Brewery.Recipe

        forms do
          extra_form_types([:money])
          exclude([:update, :activate, :retire])

          action :create do
            field :name, autofocus: true
            field :style
            field :description
            field :target_abv, type: :money
            field :target_og
            field :target_fg
            field :status
            field :photos, type: :attachment
          end
        end
      end

      field = get_field(V.CompileTime.ExtraFormTypes, :create, :target_abv)
      assert field.type == :money
    end
  end

  defp get_field(module, action_name, field_name) do
    module
    |> Info.form_for(action_name)
    |> Map.get(:fields)
    |> find_field(field_name)
  end

  defp find_field(fields, name) do
    Enum.find_value(fields, fn
      %PyroManiac.Form.Field{name: ^name} = field -> field
      %PyroManiac.Form.FieldGroup{fields: children} -> find_field(children, name)
      %PyroManiac.Form.Step{fields: children} -> find_field(children, name)
      _ -> nil
    end)
  end
end
