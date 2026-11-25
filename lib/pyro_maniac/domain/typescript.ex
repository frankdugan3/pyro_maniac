if Code.ensure_loaded?(AshTypescript.Rpc) do
  defmodule PyroManiac.Domain.Typescript do
    @moduledoc """
    Connects the surface of the resources of a domain (refer to
    `PyroManiac.Resource.Expose`) to the `typescript_rpc` configuration of
    AshTypescript. Available only when AshTypescript is a dependency.

    This extension adds `AshTypescript.Rpc` to the domain.

        defmodule Brewery.Domain do
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
    TypeScript types. A filter preset storage (`PyroManiac.FilterPresets`)
    with `AshTypescript.Resource` gets an rpc action for each of its actions
    `for_page`, `create`, `update`, and `destroy`: the renderers read and
    save the presets of a page with them.

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

    `default_rpc_name/2` uses the `short_name` and the `plural_name` of the
    resource (`Ash.Resource.Info`; without a `plural_name`, `pluralize/1` of
    the short name):

    | Action | Name |
    |---|---|
    | `:read` | `list_` and the plural name |
    | `:create`, `:update`, `:destroy` | the action, `_`, and the short name |
    | other | the short name, `_`, and the action |

    Give a function to `rpc_name` to change the names.

    ## The field names

    AshTypescript refuses a field name with `?`. A resource with
    `PyroManiac.Resource` or `PyroManiac.FilterPresets` and
    `AshTypescript.Resource` gives each public field `name?` the client name
    `is_name` (`isName` with the camel case formatter), unless its
    `typescript field_names` has one. The renderers use the same names.
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

        iex> PyroManiac.Domain.Typescript.default_rpc_name(Brewery.Supplier, :read)
        :list_suppliers

        iex> PyroManiac.Domain.Typescript.default_rpc_name(Brewery.Supplier, :create)
        :create_supplier

        iex> PyroManiac.Domain.Typescript.default_rpc_name(Brewery.Recipe, :activate)
        :recipe_activate

        iex> PyroManiac.Domain.Typescript.default_rpc_name(Brewery.Batch, :read)
        :list_batches

        iex> PyroManiac.Domain.Typescript.default_rpc_name(Brewery.QualityTest, :read)
        :list_quality_tests
    """
    @spec default_rpc_name(module(), atom()) :: atom()
    def default_rpc_name(resource, action) do
      short = to_string(Ash.Resource.Info.short_name(resource))

      name =
        case action do
          :read -> "list_" <> plural_name(resource, short)
          action when action in [:create, :update, :destroy] -> "#{action}_#{short}"
          action -> "#{short}_#{action}"
        end

      String.to_atom(name)
    end

    defp plural_name(resource, short) do
      case Ash.Resource.Info.plural_name(resource) do
        nil -> pluralize(short)
        plural -> to_string(plural)
      end
    end

    @doc """
    The resource prefix: the module name without its first segment, in snake
    case, joined with `_`.

        iex> PyroManiac.Domain.Typescript.resource_prefix(Brewery.QualityTest)
        "quality_test"
    """
    @spec resource_prefix(module()) :: String.t()
    def resource_prefix(resource), do: PyroManiac.Realtime.default_prefix(resource)

    @doc """
    The plural of a snake case name. `s`, `x`, `z`, `ch`, or `sh` at the end
    add `es`. A consonant and `y` at the end change to `ies`. All other names
    add `s`.

        iex> PyroManiac.Domain.Typescript.pluralize("batch")
        "batches"

        iex> PyroManiac.Domain.Typescript.pluralize("brewery")
        "breweries"

        iex> PyroManiac.Domain.Typescript.pluralize("brew_day")
        "brew_days"

        iex> PyroManiac.Domain.Typescript.pluralize("supplier")
        "suppliers"
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
