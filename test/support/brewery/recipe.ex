defmodule Brewery.Recipe do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource, AshStorage],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "brewery_recipes"
    repo(Brewery.Repo)
  end

  pyro_maniac do
    default_label :name
  end

  storage do
    service({AshStorage.Service.Disk, root: "/tmp/pyro_maniac_test_attachments"})
    blob_resource(Brewery.StorageBlob)
    attachment_resource(Brewery.StorageAttachment)
    has_many_attached(:photos)
  end

  pub_sub do
    module Phoenix.PubSub
    name PyroManiac.PubSub
    prefix "brewery:recipe"
    publish_all :create, ["created"]
    publish_all :update, ["updated"]
    publish_all :destroy, ["destroyed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string,
      allow_nil?: false,
      public?: true,
      description: "Recipe name."

    attribute :style, Brewery.BeerStyle,
      allow_nil?: false,
      public?: true,
      description: "Beer style category."

    attribute :description, :string,
      public?: true,
      description: "Tasting notes and recipe overview."

    attribute :target_abv, :decimal,
      public?: true,
      description: "Target alcohol by volume (%)."

    attribute :target_og, :decimal,
      public?: true,
      description: "Target original gravity."

    attribute :target_fg, :decimal,
      public?: true,
      description: "Target final gravity."

    attribute :status, :atom,
      allow_nil?: false,
      constraints: [one_of: ~w[draft active retired]a],
      default: :draft,
      public?: true,
      description: "Recipe lifecycle status."
  end

  relationships do
    has_many :recipe_ingredients, Brewery.RecipeIngredient
    has_many :batches, Brewery.Batch
  end

  aggregates do
    count :ingredient_count, :recipe_ingredients, public?: true
    count :batch_count, :batches, public?: true
  end

  calculations do
    calculate :gravity_spread, :decimal do
      calculation expr(target_og - target_fg)
      public? true
      description "Difference between target OG and FG."
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [:name])
    end

    create :create do
      primary? true
      description "Draft a new recipe."
    end

    update :update do
      primary? true
      require_atomic? false
    end

    update :activate do
      accept []
      change set_attribute(:status, :active)
      description "Mark recipe as active for production."
    end

    update :retire do
      accept []
      change set_attribute(:status, :retired)
      description "Retire recipe from active production."
    end
  end
end
