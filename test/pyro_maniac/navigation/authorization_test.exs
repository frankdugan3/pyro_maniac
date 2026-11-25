defmodule PyroManiac.Navigation.AuthorizationTest do
  @moduledoc false
  # `Ash.can?/3` with `maybe_is: true, run_queries?: false`: the strict check
  # of the policies, with no query.
  use ExUnit.Case, async: true

  alias PyroManiac.Navigation.Authorization

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defmodule ActorIsActive do
    @moduledoc false
    use Ash.Policy.SimpleCheck

    @impl true
    def describe(_opts), do: "actor is active"

    @impl true
    def requires_original_data?(_actor, _opts), do: false

    @impl true
    def match?(nil, _context, _opts), do: false
    def match?(actor, _context, _opts), do: Map.get(actor, :active?, false)
  end

  defmodule Runtime do
    @moduledoc false
    use Ash.Policy.Check

    @impl true
    def describe(_opts), do: "a check that needs the data"

    @impl true
    def type, do: :manual

    @impl true
    def strict_check(_actor, _context, _opts), do: {:ok, :unknown}

    @impl true
    def check(_actor, data, _context, _opts), do: data
  end

  defmodule Doc do
    @moduledoc false
    use Ash.Resource,
      domain: PyroManiac.Navigation.AuthorizationTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer],
      extensions: [PyroManiac.Resource]

    pyro_maniac do
      default_label(:name)

      expose [:list, :runtime] do
        loads [:name]
        filter [:name]
        sort [:name]
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :owner_id, :uuid, public?: true
    end

    actions do
      read :list, primary?: true
      read :runtime
    end

    policies do
      policy action(:list) do
        forbid_unless PyroManiac.Navigation.AuthorizationTest.ActorIsActive
        authorize_if expr(owner_id == ^actor(:id))
      end

      policy action(:runtime) do
        authorize_if PyroManiac.Navigation.AuthorizationTest.Runtime
      end
    end
  end

  defmodule ListPage do
    @moduledoc false
    use PyroManiac, resource: PyroManiac.Navigation.AuthorizationTest.Doc

    page do
      route "/docs"
      exclude [:runtime]
    end

    view :list do
      type :card
      primary? true

      section :main do
        field :name
      end
    end
  end

  defmodule RuntimePage do
    @moduledoc false
    use PyroManiac, resource: PyroManiac.Navigation.AuthorizationTest.Doc

    page do
      route "/runtime"
      exclude [:list]
    end

    view :runtime do
      type :card
      primary? true

      section :main do
        field :name
      end
    end
  end

  @active %{id: "a", active?: true}
  @inactive %{id: "b", active?: false}

  test "a simple check before the filter gives an exact answer" do
    assert Authorization.authorized?(ListPage, @active) == true
    assert Authorization.authorized?(ListPage, @inactive) == false
    assert Authorization.authorized?(ListPage, nil) == false
  end

  test "a check that the strict check cannot decide is true, also with no actor" do
    assert Authorization.authorized?(RuntimePage, @inactive) == true
    assert Authorization.authorized?(RuntimePage, nil) == true
  end
end
