defmodule Brewery.Supplier do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource]

  postgres do
    table "brewery_suppliers"
    repo(Brewery.Repo)
  end

  pyro_maniac do
    default_label :name
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true

    attribute :code, :string,
      allow_nil?: false,
      public?: true,
      description: "Unique supplier code."

    attribute :contact_email, :string,
      public?: true,
      description: "Primary contact email."

    attribute :phone, :string, public?: true
    attribute :active, :boolean, allow_nil?: false, default: true, public?: true

    attribute :notes, :string,
      description: "Internal notes about the supplier.",
      public?: true
  end

  identities do
    identity :unique_code, [:code]
  end

  relationships do
    has_many :ingredients, Brewery.Ingredient
  end

  aggregates do
    count :ingredient_count, :ingredients, public?: true
  end

  actions do
    default_accept :*
    defaults [:read, :destroy]

    create :create do
      primary? true
      description "Register a new ingredient supplier."
    end

    update :update do
      primary? true
      require_atomic? false
    end
  end
end
