defmodule Brewery.Shipment do
  @moduledoc false
  # A shipment and its lines: the nested form of the tests of `parent(...)`
  # in `visible?`. ETS, because no test reads or writes the rows.

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [PyroManiac.Resource]

  pyro_maniac do
    default_label :reference
  end

  attributes do
    uuid_primary_key :id

    attribute :reference, :string, allow_nil?: false, public?: true

    attribute :carrier, :atom,
      constraints: [one_of: [:truck, :courier, :pickup]],
      default: :truck,
      public?: true
  end

  relationships do
    has_many :lines, Brewery.ShipmentLine, public?: true
  end

  aggregates do
    count :line_count, :lines, public?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:reference, :carrier]
      argument :lines, {:array, :map}, default: []
      change manage_relationship(:lines, type: :create)
    end
  end
end

defmodule Brewery.ShipmentLine do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [PyroManiac.Resource]

  pyro_maniac do
    default_label :description
  end

  attributes do
    uuid_primary_key :id

    attribute :description, :string, allow_nil?: false, public?: true
    attribute :quantity, :integer, public?: true
    attribute :pallet_count, :integer, public?: true
  end

  relationships do
    belongs_to :shipment, Brewery.Shipment, public?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:description, :quantity, :pallet_count]
    end
  end
end
