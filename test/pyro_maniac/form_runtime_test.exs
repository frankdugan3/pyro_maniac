defmodule PyroManiac.FormRuntimeTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias PyroManiac.Form.Combobox
  alias PyroManiac.Info

  doctest PyroManiac.TypeInfer

  defmodule Status do
    @moduledoc false
    use Ash.Type.NewType, subtype_of: :atom, constraints: [one_of: [:open, :closed]]
  end

  # An application interval type, as `Hsm.Ash.Type.Interval`.
  defmodule StoredInterval do
    @moduledoc false
    use Ash.Type

    @impl true
    def storage_type(_constraints), do: :interval
    @impl true
    def cast_input(value, _constraints), do: {:ok, value}
    @impl true
    def cast_stored(value, _constraints), do: {:ok, value}
    @impl true
    def dump_to_native(value, _constraints), do: {:ok, value}
  end

  defmodule Color do
    @moduledoc false
    use Ash.Type.Enum, values: [red: "Stop", green: "Go"]
  end

  defmodule SupplierPage do
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
          filter expr(is_nil(^input(:name)) or name == ^input(:name))
        end

        field :contact_email, visible?: expr(active == true)
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

  defmodule ShipmentPage do
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
          field :description
          field :quantity
          field :pallet_count, visible?: expr(parent(carrier) == :truck and quantity > 0)
        end
      end
    end
  end

  setup do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Brewery.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  defp input(name) do
    SupplierPage
    |> Info.action_for(:create)
    |> Info.form_fields()
    |> Enum.find(&(&1.name == name))
  end

  describe "TypeInfer.closed_values/2" do
    test "array items, new types, arrays of new types, and enums" do
      assert [%{value: :a}] =
               PyroManiac.TypeInfer.closed_values({:array, :atom}, items: [one_of: [:a]])

      assert [%{value: :open}, %{value: :closed}] = PyroManiac.TypeInfer.closed_values(Status, [])
      assert [%{value: :open}, _] = PyroManiac.TypeInfer.closed_values({:array, Status}, [])

      assert [%{value: :red, description: "Stop"}, %{value: :green, description: "Go"}] =
               PyroManiac.TypeInfer.closed_values(Color, [])

      assert PyroManiac.TypeInfer.closed_values(:boolean, []) == nil
    end

    test "an Ash type that stores an interval is an interval" do
      assert PyroManiac.TypeInfer.interval_type?(:interval)
      assert PyroManiac.TypeInfer.interval_type?(StoredInterval)
      refute PyroManiac.TypeInfer.interval_type?(Ash.Type.String)
      refute PyroManiac.TypeInfer.interval_type?(NotAType)
    end

    test "the search filter type agrees with the form" do
      assert PyroManiac.TypeInfer.filter_type(Status, []) == :enum
      assert PyroManiac.TypeInfer.filter_type(:atom, one_of: [:a]) == :enum
    end
  end

  describe "visible?/3" do
    test "a visible? expression with the attribute changes of the changeset" do
      email = input(:contact_email)

      shown =
        Ash.Changeset.for_create(Brewery.Supplier, :create, %{name: "A", code: "A", active: true})

      hidden =
        Ash.Changeset.for_create(Brewery.Supplier, :create, %{name: "A", code: "A", active: false})

      assert PyroManiac.Form.visible?(email, shown, nil)
      refute PyroManiac.Form.visible?(email, hidden, nil)
      assert PyroManiac.Form.visible?(email, %{source: shown}, nil)
    end

    test "parent(...) refers to the record of the parent changeset" do
      [_reference, _carrier, group] = Info.action_for(ShipmentPage, :create).fields
      [_description, _quantity, pallets] = group.fields

      line =
        Ash.Changeset.for_create(Brewery.ShipmentLine, :create, %{
          description: "Kegs",
          quantity: 4
        })

      truck = Ash.Changeset.for_create(Brewery.Shipment, :create, %{reference: "S1"})

      courier =
        Ash.Changeset.for_create(Brewery.Shipment, :create, %{reference: "S1", carrier: :courier})

      assert PyroManiac.Form.visible?(pallets, line, nil, parent: truck)
      refute PyroManiac.Form.visible?(pallets, line, nil, parent: %{source: courier})

      # Without the parent, the value is not known, and the entity shows.
      assert PyroManiac.Form.visible?(pallets, line, nil)
    end

    test "an entity with no visible? is visible" do
      assert PyroManiac.Form.visible?(input(:phone), nil, nil)
    end
  end

  describe "combobox_options/4" do
    setup do
      for {name, code} <- [{"Hop Co", "HOP"}, {"Hop Co", "HOP2"}, {"Malt Inc", "MALT"}] do
        Brewery.Supplier
        |> Ash.Changeset.for_create(:create, %{name: name, code: code})
        |> Ash.create!()
      end

      :ok
    end

    test "free text: the different values that contain the typed text" do
      assert [%{label: "Hop Co", value: "Hop Co"}] =
               PyroManiac.Form.combobox_options(input(:name), "hop", %{}, nil)

      assert ["Hop Co", "Malt Inc"] =
               input(:name)
               |> PyroManiac.Form.combobox_options("", %{}, nil)
               |> Enum.map(& &1.value)
    end

    test "^input(name) filters by the value of another input" do
      code = input(:code)
      assert %Combobox{__inputs__: [:name]} = code

      assert ["HOP", "HOP2"] =
               code
               |> PyroManiac.Form.combobox_options("", %{name: "Hop Co"}, nil)
               |> Enum.map(& &1.value)

      assert ["HOP", "HOP2", "MALT"] =
               code
               |> PyroManiac.Form.combobox_options("", %{"name" => ""}, nil)
               |> Enum.map(& &1.value)
    end

    test "the label of a free-text value is the value" do
      assert PyroManiac.Form.combobox_label(input(:code), "HOP", nil) == "HOP"
      assert PyroManiac.Form.combobox_label(input(:code), "", nil) == nil
    end
  end
end
