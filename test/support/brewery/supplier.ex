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

    expose [:read, :suggest_codes, :by_prefix] do
      loads [:id, :name, :code, :contact_email, :phone, :active, :notes, :ingredient_count]
      filter [:id, :name, :code, :contact_email, :phone, :active, :notes, :ingredient_count]
      sort [:id, :name, :code, :contact_email, :phone, :active, :notes, :ingredient_count]
    end

    expose [:destroy, :create, :update, :rename] do
      loads [:id, :name, :code, :contact_email, :phone, :active, :notes, :ingredient_count]
    end
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
    has_many :ingredients, Brewery.Ingredient, public?: true
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

    update :rename do
      description "Rename the supplier, with a reason."
      require_atomic? false
      accept [:name]
      argument :reason, :string, allow_nil?: false
    end

    read :suggest_codes do
      description "The different supplier codes that contain the search text."

      argument :search, :string,
        allow_nil?: false,
        default: "",
        constraints: [allow_empty?: true]

      prepare build(limit: 10, sort: [code: :asc], distinct: [:code], select: [:code])
      filter expr(contains(code, ^arg(:search)))
    end

    read :by_prefix do
      description "The suppliers whose code starts with a prefix."
      argument :prefix, :string, allow_nil?: false
      filter expr(contains(code, ^arg(:prefix)))
    end
  end
end
