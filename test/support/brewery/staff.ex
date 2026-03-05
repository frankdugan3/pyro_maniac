defmodule Brewery.Staff do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource],
    notifiers: [Ash.Notifier.PubSub]

  require Ash.Query

  postgres do
    table "brewery_staff"
    repo(Brewery.Repo)
  end

  pyro_maniac do
    default_label :name
  end

  pub_sub do
    module Phoenix.PubSub
    name PyroManiac.PubSub
    prefix "brewery:staff"
    publish_all :create, ["created"]
    publish_all :update, ["updated"]
    publish_all :destroy, ["destroyed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :email, :string, allow_nil?: false, public?: true, sensitive?: true

    attribute :role, :atom,
      allow_nil?: false,
      constraints: [one_of: ~w[brewer head_brewer quality admin]a],
      default: :brewer,
      public?: true

    attribute :active, :boolean, allow_nil?: false, default: true, public?: true
    attribute :internal_notes, :string, description: "Internal HR notes."
  end

  calculations do
    calculate :name_email, :ci_string do
      calculation expr(name <> " (" <> email <> ")")
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [:name])
    end

    read :autocomplete do
      argument :search, :ci_string

      prepare fn query, _ ->
        search_string = Ash.Query.get_argument(query, :search)

        query
        |> Ash.Query.filter(
          if ^search_string == "" do
            true
          else
            contains(name_email, ^search_string)
          end
        )
        |> Ash.Query.load(:name_email)
        |> Ash.Query.sort(:name_email)
        |> Ash.Query.limit(10)
      end
    end

    create :create do
      primary? true
      description "Add a new staff member."
    end

    update :update do
      primary? true
      require_atomic? false
    end

    update :deactivate do
      accept []
      change set_attribute(:active, false)
      description "Deactivate a staff member."
    end
  end

  code_interface do
    define :autocomplete, action: :autocomplete, args: [:search]
    define :list, action: :list
    define :by_id, action: :read, get_by: [:id]
    define :create, action: :create
    define :destroy, action: :destroy
  end
end
