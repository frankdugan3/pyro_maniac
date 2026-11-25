defmodule PyroManiac.CompileTimeResolutionTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias PyroManiac.Info

  defmodule RecipePage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Recipe

    page do
      route "/test"
      exclude [:activate, :retire, :destroy]
    end

    view [:read, :list] do
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

  defmodule StaffPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Staff

    view [:read, :list] do
      type :data_table
      primary? true
      default_sort "email"
      exclude([:id, :name_email])
      column(:name)
      column(:email)
      column(:role)
      column(:active)
    end

    view :read do
      type :card

      primary? true

      action [:create, :update], :guard

      field :name, autofocus: true
      field :email
      select :role
      field :active
    end

    page do
      route "/test"
      exclude [:deactivate, :destroy, :autocomplete]
    end
  end

  defmodule BatchPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Batch

    page do
      route "/test"
      exclude [:start_brewing, :advance_status, :complete, :move_card, :destroy, :kanban_read]
    end

    view [:read, :list] do
      type :data_table
      primary? true
      default_sort "batch_number"

      exclude([
        :id,
        :kanban_priority,
        :pass_rate,
        :recipe,
        :recipe_id,
        :brewer,
        :brewer_id
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

    view :read do
      type :card

      primary? true

      action [:create, :update], :guard

      field :batch_number, autofocus: true
      select :status
      field :brew_date
      field :package_date
      field :actual_og
      field :actual_fg
      field :actual_abv
      field :volume_liters
      field :notes
      combobox :recipe_id
      combobox :brewer_id
    end
  end

  describe "field type resolution" do
    test "string fields resolve to :text" do
      field = get_field(RecipePage, :create, :name)
      assert %PyroManiac.Form.Field{type: :text} = field
    end

    test "a custom Ash enum is a select with the options of the enum" do
      select = get_field(RecipePage, :create, :style)
      assert %PyroManiac.Form.Select{} = select

      assert %{value: :ipa, label: "IPA"} =
               Enum.find(select.__enum_options__, &(&1.value == :ipa))
    end

    test "a one_of constraint is a select with the values" do
      select = get_field(RecipePage, :create, :status)
      assert %PyroManiac.Form.Select{} = select
      assert Enum.map(select.__enum_options__, & &1.value) == [:draft, :active, :retired]
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

  describe "belongs_to combobox" do
    test "the label drops the _id suffix" do
      assert get_field(BatchPage, :create, :recipe_id).label == "Recipe"
      assert get_field(BatchPage, :create, :brewer_id).label == "Brewer"
    end

    test "it selects a record of the destination with the defaults" do
      combobox = get_field(BatchPage, :create, :recipe_id)

      assert %PyroManiac.Form.Combobox{__mode__: :select} = combobox
      assert combobox.__resource__ == Brewery.Recipe
      assert combobox.read_action == :read
      assert combobox.value_key == :id
      assert combobox.label_key == :name
      assert combobox.search == [:name]
      assert combobox.sort == [name: :asc]
      assert combobox.limit == 20
    end
  end

  defmodule FreeTextComboboxPage do
    @moduledoc false
    use PyroManiac, resource: Brewery.Supplier

    view :read do
      type :card
      primary? true

      section :main do
        field :name
      end

      action :create do
        state :guard
        combobox :name, autofocus: true

        combobox :code do
          read_action :suggest_codes
          argument :search, search()
          search false
        end

        combobox :contact_email do
          filter expr(is_nil(^input(:name)) or name == ^input(:name))
        end

        field :phone
        field :active
        field :notes
      end
    end

    page do
      route "/test"
      exclude [:update, :rename, :destroy, :suggest_codes, :by_prefix]
    end
  end

  describe "free-text combobox" do
    test "the defaults search, sort, and show the field of the form resource" do
      combobox = get_field(FreeTextComboboxPage, :create, :name)

      assert %PyroManiac.Form.Combobox{__mode__: :free_text} = combobox
      assert combobox.__resource__ == Brewery.Supplier
      assert combobox.read_action == :read
      assert combobox.value_key == :name
      assert combobox.label_key == :name
      assert combobox.search == [:name]
      assert combobox.sort == [name: :asc]
    end

    test "an explicit read action with search() in an argument" do
      combobox = get_field(FreeTextComboboxPage, :create, :code)

      assert combobox.read_action == :suggest_codes
      assert combobox.search == false
      assert [%{name: :search, value: {:_context, [:pyro_maniac, :search]}}] = combobox.arguments
    end

    test "^input(name) in the filter is recorded" do
      combobox = get_field(FreeTextComboboxPage, :create, :contact_email)
      assert combobox.__inputs__ == [:name]
    end
  end

  describe "private fields" do
    test "allow nil is resolved from the attribute" do
      assert get_field(RecipePage, :create, :name)."__allow_nil?__" == false
      assert get_field(RecipePage, :create, :description)."__allow_nil?__" == true
    end

    test "a non-enum field has no options" do
      assert get_field(RecipePage, :create, :name).__enum_options__ == []
    end

    test "the full path of a top-level input is empty" do
      assert get_field(RecipePage, :create, :name).__full_path__ == []
    end
  end

  describe "size resolution" do
    test "a field gets a size from its type" do
      assert get_field(RecipePage, :create, :target_abv).size == :term
      assert get_field(RecipePage, :create, :photos).size == :prose
      assert get_field(BatchPage, :create, :brew_date).size == :term
    end

    test "a string without max_length is a name, and a select or a combobox is a name" do
      assert get_field(RecipePage, :create, :name).size == :name
      assert get_field(RecipePage, :create, :status).size == :name
      assert get_field(BatchPage, :create, :recipe_id).size == :name
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

  defmodule MoneyInput do
    @moduledoc false
    @behaviour PyroManiac.Form.InputType

    @impl true
    def schema, do: [currency: [type: :atom, default: :usd, doc: "The currency."]]

    @impl true
    def default_size, do: :term
  end

  describe "input entity" do
    test "an app input type with options" do
      defmodule V.CompileTime.MoneyInputPage do
        @moduledoc false
        use PyroManiac, resource: Brewery.Recipe

        view :read do
          type :card
          primary? true

          section :main do
            field :name
          end

          action :create do
            state :guard
            field :name, autofocus: true
            select :style
            field :description
            input(:target_abv, {PyroManiac.CompileTimeResolutionTest.MoneyInput, currency: :eur})
            input(:target_og, PyroManiac.CompileTimeResolutionTest.MoneyInput)
            field :target_fg
            select :status
            field :photos, type: :attachment
          end
        end

        page do
          route "/test"
          exclude [:update, :activate, :retire, :destroy, :list]
        end
      end

      input = get_field(V.CompileTime.MoneyInputPage, :create, :target_abv)
      assert %PyroManiac.Form.Input{} = input
      assert input.__opts__ == [currency: :eur]
      assert input.size == :term

      assert get_field(V.CompileTime.MoneyInputPage, :create, :target_og).__opts__ == [
               currency: :usd
             ]
    end
  end

  describe "visible? expressions" do
    test "the attributes and the arguments of the expression are in __depends_on__" do
      defmodule V.CompileTime.WhenPage do
        @moduledoc false
        use PyroManiac, resource: Brewery.Recipe

        view :read do
          type :card
          primary? true

          section :main do
            field :name
          end

          action :create do
            state :guard
            field :name, autofocus: true
            select :style
            field :description, visible?: expr(status == :draft and not is_nil(name))
            field :target_abv
            field :target_og
            field :target_fg
            select :status
            field :photos, type: :attachment
          end
        end

        page do
          route "/test"
          exclude [:update, :activate, :retire, :destroy, :list]
        end
      end

      field = get_field(V.CompileTime.WhenPage, :create, :description)
      assert Enum.sort(field.__depends_on__) == [:name, :status]
    end

    # `parent(...)` refers to the form one level up, as in Ash. The `visible?`
    # of an input in a nested form is at its full path, so its parent is the
    # form. The `visible?` of a group with a `path` is at the level that
    # contains the group (it shows or hides all the rows).
    defmodule V.CompileTime.ParentVisiblePage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Shipment

      page do
        route "/test"
        exclude [:destroy]
      end

      view :read do
        type :card
        primary? true

        section :main do
          field :reference
        end

        action :create do
          state :guard
          field :reference, autofocus: true
          select :carrier

          section :lines do
            path [:lines]
            visible? expr(carrier != :pickup)
            field :description
            field :quantity
            field :pallet_count, visible?: expr(parent(carrier) == :truck and quantity > 0)
          end
        end
      end
    end

    # Regression: the option was `when`. Elixir parses a line that starts
    # with `when` as the guard operator of the line before it (and as the
    # first line of a block, it is a syntax error). Thus a `when` in the block
    # of a group, a row, a compound, or a step could not be written.
    defmodule V.CompileTime.VisibleBlockPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Shipment

      page do
        route "/test"
        exclude [:destroy]
      end

      view :read do
        type :card
        primary? true

        section :main do
          field :reference
        end

        action :create do
          state :guard

          row do
            visible? expr(carrier != :pickup)
            field :reference, autofocus: true
            select :carrier
          end

          section :lines do
            path [:lines]
            field :description

            compound :amount do
              description "The quantity and the pallets."
              visible? expr(not is_nil(description))
              field :quantity
              field :pallet_count
            end
          end
        end
      end
    end

    test "visible? can be the first line or a later line of a block" do
      [row, group] = Info.action_for(V.CompileTime.VisibleBlockPage, :create).fields
      [_description, compound] = group.fields

      assert row.__depends_on__ == [:carrier]
      assert compound.__depends_on__ == [:description]
    end

    test "a parent reference is in __depends_on__ as {:parent, name}" do
      [_reference, _carrier, group] =
        Info.action_for(V.CompileTime.ParentVisiblePage, :create).fields

      [_description, _quantity, pallets] = group.fields
      assert Enum.sort(pallets.__depends_on__) == [:quantity, {:parent, :carrier}]

      # The group is at the level of the form: `carrier` is an attribute of
      # the shipment, not of a line.
      assert group.__depends_on__ == [:carrier]
    end

    test "form_layout/1 gives a parent dependency as a map" do
      layout =
        V.CompileTime.ParentVisiblePage
        |> Info.action_for(:create)
        |> Info.form_layout()

      [_, _, %{children: [_, _, pallets]}] = layout.children
      assert %{parent: :carrier} in pallets.depends_on
      assert is_binary(JSON.encode!(layout))
    end
  end

  describe "Info.form_layout/1" do
    test "gives a plain tree that encodes as JSON" do
      layout =
        RecipePage
        |> Info.action_for(:create)
        |> Info.form_layout()

      assert %{kind: :form, children: [first | _]} = layout
      assert first.kind == :field
      assert first.name == :name
      assert is_binary(JSON.encode!(layout))
    end
  end

  describe "attachment column tagging" do
    defmodule AttachmentColumnPage do
      @moduledoc false
      use PyroManiac, resource: Brewery.Recipe

      page do
        route "/test"
        exclude [:destroy, :create, :update, :activate, :retire]
      end

      view [:read, :list] do
        type :data_table
        primary? true
        default_sort "name"
        exclude([:id, :recipe_ingredients, :batches, :photos_urls])
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
        column(:photos)
      end

      view :read do
        type :card

        primary? true

        section :main do
          field :name
        end
      end
    end

    test "an AshStorage attachment column resolves to type :attachment" do
      column = get_column(AttachmentColumnPage, :data_table, :photos)

      assert column.type == :attachment
      assert column.__attachment_destination__ == Brewery.StorageAttachment
    end

    test "non-attachment columns keep type :default" do
      column = get_column(AttachmentColumnPage, :data_table, :name)

      assert column.type == :default
      assert column.__attachment_destination__ == nil
    end
  end

  defp get_column(module, type, name) do
    module
    |> Info.view_for(:read, type)
    |> Map.get(:columns)
    |> Enum.find(&(&1.name == name))
  end

  defp get_field(module, action_name, field_name) do
    module
    |> Info.action_for(action_name)
    |> Info.form_fields()
    |> Enum.find(&(&1.name == field_name))
  end
end
