defmodule PyroManiac.InfoTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Ash.DataLayer.Ets
  alias Ash.Notifier.PubSub
  alias PyroManiac.Test.Support.LiveViewBackend

  require Ash.Query

  doctest PyroManiac.Info, import: true

  defmodule User do
    @moduledoc false
    use Ash.Resource,
      data_layer: Ets,
      notifiers: [PubSub],
      domain: PyroManiac.InfoTest.Domain

    alias PyroManiac.InfoTest.Domain

    require Ash.Query

    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false, public?: true

      attribute :email, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [
          max_length: 160
        ],
        public?: true

      attribute :active, :boolean, allow_nil?: false, default: true, public?: true

      attribute :role, :atom,
        allow_nil?: false,
        constraints: [one_of: ~w[reader author editor admin]a],
        default: :reader,
        public?: true

      attribute :notes, :string,
        description: "Note anything unusual about yourself",
        public?: true
    end

    relationships do
      belongs_to :best_friend, __MODULE__, domain: Domain
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

        argument :best_friend_id, :uuid
        change manage_relationship(:best_friend_id, :best_friend, type: :append_and_remove)

        description "Just an ordinary create action."
      end

      update :update do
        primary? true
        require_atomic? false
        argument :best_friend_id, :uuid
        change manage_relationship(:best_friend_id, :best_friend, type: :append_and_remove)
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

  defmodule Domain do
    @moduledoc false
    use Ash.Domain

    resources do
      resource User
    end
  end

  defmodule UserPage do
    @moduledoc false

    use PyroManiac, resource: PyroManiac.InfoTest.User, backends: [LiveViewBackend]

    data_table do
      action_type [:read] do
        default_sort "email"
        exclude [:id, :name_email, :best_friend]
        column :name
        column :email
        column :role
        column :active
        column :notes
      end
    end

    form do
      action_type [:create, :update] do
        class "max-w-md justify-self-center"

        field_group "Primary Info" do
          class "md:grid-cols-2"

          field :name do
            description "Your full real name"
            autofocus true
          end

          field :email
        end

        field_group "Authorization" do
          class "md:grid-cols-2"

          field :role do
            label "Role"
          end

          field :active do
            label "Active"
          end
        end

        field_group "Friendships" do
          field :best_friend_id do
            label "Best Friend"
            type :autocomplete
            prompt "Search friends for your bestie"
            autocomplete_option_label_key :name_email
          end
        end

        field :notes do
          type :long_text
          input_class "min-h-[10rem]"
        end
      end
    end
  end
end
