if Code.ensure_loaded?(AshTypescript.Rpc) do
  defmodule PyroManiac.Domain.Typescript do
    @moduledoc """
    Connects the surface of the resources of a domain (refer to
    `PyroManiac.Resource.Expose`) to the `typescript_rpc` configuration of
    AshTypescript. Available only when AshTypescript is a dependency.

    This extension adds `AshTypescript.Rpc` to the domain.

        defmodule MyApp.Purchasing do
          use Ash.Domain, extensions: [PyroManiac.Domain.Typescript]

          pyro_maniac_typescript do
            mode :auto
          end
        end

    - `mode :validate` (the default): you write `typescript_rpc`. A verifier
      checks that each exposed action has an `rpc_action`, that its
      `allowed_loads` covers the exposed loads, and that filter and sort are
      enabled when the action exposes `filter` and `sort` fields.
    - `mode :auto`: a transformer adds an `rpc_action` for each exposed action
      that has no written `rpc_action`. Written rpc actions stay and are
      validated as in `:validate` mode.

    In `:auto` mode, each resource of the domain with `AshTypescript.Resource`
    is in `typescript_rpc`, also with no exposed action. Thus it has
    TypeScript types.

    In both modes, a verifier checks:

    - Each resource with `expose` uses `AshTypescript.Resource`.
    - Each resource that the exposed `loads` reach through a relationship (for
      example, the attachments of a record) has TypeScript types: it uses
      `AshTypescript.Resource`, and its domain lists it in `typescript_rpc`
      (or uses this extension in `:auto` mode).

    `allowed_loads` can hold only loadable fields (relationships,
    calculations, aggregates). `:auto` mode leaves out the plain attributes of
    the exposed loads. A client can select each public attribute: AshTypescript
    cannot restrict attributes.

    ## The rpc name

    `default_rpc_name/2` uses the resource prefix (`resource_prefix/1`):

    | Action | Name |
    |---|---|
    | `:read` | `list_` and the plural of the prefix |
    | `:create`, `:update`, `:destroy` | the action, `_`, and the prefix |
    | other | the prefix, `_`, and the action |

    Give a function to `rpc_name` to change the names.
    """
    @moduledoc group: "PyroManiac"

    @section %Spark.Dsl.Section{
      name: :pyro_maniac_typescript,
      describe: "Connect the surface of the resources of this domain to AshTypescript.",
      schema: [
        mode: [
          type: {:one_of, [:validate, :auto]},
          default: :validate,
          doc: "`:validate` checks the `typescript_rpc` that you write. `:auto` makes it."
        ],
        rpc_name: [
          type: {:fun, 2},
          default: &__MODULE__.default_rpc_name/2,
          doc: "A function of a resource and an action name that gives the rpc action name."
        ]
      ]
    }

    use Spark.Dsl.Extension,
      sections: [@section],
      add_extensions: [AshTypescript.Rpc],
      transformers: [PyroManiac.Domain.Typescript.Transformers.AddRpcActions],
      verifiers: [PyroManiac.Domain.Typescript.Verifiers.VerifyRpc]

    @doc """
    The default rpc action name of an action of a resource.

        iex> PyroManiac.Domain.Typescript.default_rpc_name(MyApp.Purchasing.Vendor, :read)
        :list_purchasing_vendors

        iex> PyroManiac.Domain.Typescript.default_rpc_name(MyApp.Purchasing.Vendor, :create)
        :create_purchasing_vendor

        iex> PyroManiac.Domain.Typescript.default_rpc_name(MyApp.Purchasing.Vendor, :archive)
        :purchasing_vendor_archive

        iex> PyroManiac.Domain.Typescript.default_rpc_name(MyApp.Customers.Address, :read)
        :list_customers_addresses
    """
    @spec default_rpc_name(module(), atom()) :: atom()
    def default_rpc_name(resource, action) do
      prefix = resource_prefix(resource)

      name =
        case action do
          :read -> "list_" <> pluralize(prefix)
          action when action in [:create, :update, :destroy] -> "#{action}_#{prefix}"
          action -> "#{prefix}_#{action}"
        end

      String.to_atom(name)
    end

    @doc """
    The resource prefix: the module name without its first segment, in snake
    case, joined with `_`.

        iex> PyroManiac.Domain.Typescript.resource_prefix(MyApp.FFL.ADRecord)
        "ffl_ad_record"
    """
    @spec resource_prefix(module()) :: String.t()
    def resource_prefix(resource), do: PyroManiac.Realtime.default_prefix(resource)

    @doc """
    The plural of a snake case name. `s`, `x`, `z`, `ch`, or `sh` at the end
    add `es`. A consonant and `y` at the end change to `ies`. All other names
    add `s`.

        iex> PyroManiac.Domain.Typescript.pluralize("customers_address")
        "customers_addresses"

        iex> PyroManiac.Domain.Typescript.pluralize("calibration_category")
        "calibration_categories"

        iex> PyroManiac.Domain.Typescript.pluralize("purchasing_day")
        "purchasing_days"

        iex> PyroManiac.Domain.Typescript.pluralize("purchasing_vendor")
        "purchasing_vendors"
    """
    @spec pluralize(String.t()) :: String.t()
    def pluralize(name) do
      cond do
        String.ends_with?(name, ["s", "x", "z", "ch", "sh"]) ->
          name <> "es"

        String.match?(name, ~r/[^aeiou]y$/) ->
          String.slice(name, 0..-2//1) <> "ies"

        true ->
          name <> "s"
      end
    end
  end
end
