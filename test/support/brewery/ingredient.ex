defmodule Brewery.Ingredient do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource]

  postgres do
    table "brewery_ingredients"
    repo(Brewery.Repo)
  end

  pyro_maniac do
    default_label :name
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true, description: "Ingredient name."

    attribute :lot_number, :string,
      public?: true,
      description: "Lot or batch number from supplier."

    attribute :type, :atom,
      allow_nil?: false,
      constraints: [one_of: ~w[grain hop yeast adjunct water_treatment]a],
      public?: true,
      description: "Category of ingredient."

    attribute :unit, :atom,
      allow_nil?: false,
      constraints: [one_of: ~w[kg g l ml each]a],
      default: :kg,
      public?: true

    attribute :description, :string, public?: true
  end

  relationships do
    belongs_to :supplier, Brewery.Supplier, allow_nil?: false, public?: true
  end

  actions do
    default_accept :*
    defaults [:read, :destroy]

    create :create do
      primary? true
      argument :supplier_id, :uuid, allow_nil?: false
      change manage_relationship(:supplier_id, :supplier, type: :append_and_remove)
      description "Add a new ingredient to inventory."
    end

    update :update do
      primary? true
      require_atomic? false
    end
  end
end
