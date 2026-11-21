if Code.ensure_loaded?(AshTypescript.Rpc) do
  defmodule PyroManiac.Domain.Typescript.Info do
    @moduledoc """
    Introspection for `PyroManiac.Domain.Typescript`.
    """
    @moduledoc group: "PyroManiac"

    @section [:pyro_maniac_typescript]

    @doc "The `mode` of a domain, or `nil` when the domain does not use the extension."
    @spec mode(Spark.Dsl.t() | module()) :: :validate | :auto | nil
    def mode(domain) do
      if extension?(domain),
        do: Spark.Dsl.Extension.get_opt(domain, @section, :mode, :validate)
    end

    @doc "Whether the domain uses `PyroManiac.Domain.Typescript`."
    @spec extension?(Spark.Dsl.t() | module()) :: boolean()
    def extension?(domain) when is_atom(domain),
      do: PyroManiac.Domain.Typescript in Spark.extensions(domain)

    def extension?(_dsl), do: true

    @doc """
    The rpc action name of an action of a resource: the name of the written
    or generated `rpc_action` in the domain (by default, the domain of the
    resource), or `nil`.
    """
    @spec rpc_name(Ash.Resource.t(), atom(), module() | nil) :: atom() | nil
    def rpc_name(resource, action, domain \\ nil) do
      domain = domain || Ash.Resource.Info.domain(resource)

      if domain && extension?(domain) do
        domain
        |> AshTypescript.Rpc.Info.typescript_rpc()
        |> Enum.filter(&(&1.resource == resource))
        |> Enum.flat_map(& &1.rpc_actions)
        |> Enum.find_value(fn rpc_action -> rpc_action.action == action && rpc_action.name end)
      end
    end

    @doc "The `rpc_name` function of a domain."
    @spec rpc_name_fun(Spark.Dsl.t() | module()) :: (module(), atom() -> atom())
    def rpc_name_fun(domain) do
      Spark.Dsl.Extension.get_opt(
        domain,
        @section,
        :rpc_name,
        &PyroManiac.Domain.Typescript.default_rpc_name/2
      )
    end

    @doc """
    The `allowed_loads` for an exposed field list: the loadable fields only
    (relationships, calculations, aggregates, and embedded attributes). A
    relationship with only plain attributes gives the relationship.
    """
    @spec allowed_loads(Ash.Resource.t(), PyroManiac.Surface.field_list()) ::
            PyroManiac.Surface.field_list()
    def allowed_loads(resource, loads) do
      loads
      |> PyroManiac.Surface.paths()
      |> Enum.flat_map(&loadable_path(resource, &1))
      |> PyroManiac.Surface.from_paths()
    end

    @doc """
    The resources that a field list reaches through its relationships, each
    with the path of the relationship: `[{destination, [:relationship, ...]}]`.
    A client can load these records, so each needs TypeScript types.
    """
    @spec load_destinations(Ash.Resource.t(), PyroManiac.Surface.field_list()) ::
            [{Ash.Resource.t(), [atom()]}]
    def load_destinations(resource, loads) do
      loads
      |> PyroManiac.Surface.paths()
      |> Enum.flat_map(&destinations_of_path(resource, &1, []))
      |> Enum.uniq()
    end

    defp destinations_of_path(resource, [name | rest], prefix) do
      case Ash.Resource.Info.relationship(resource, name) do
        %{destination: destination} ->
          path = prefix ++ [name]
          [{destination, path} | destinations_of_path(destination, rest, path)]

        nil ->
          []
      end
    end

    defp destinations_of_path(_resource, [], _prefix), do: []

    @doc """
    Whether a resource has TypeScript types: it uses `AshTypescript.Resource`,
    and its domain lists it in `typescript_rpc` (or makes the list, with
    `PyroManiac.Domain.Typescript` in `:auto` mode).
    """
    @spec rpc_resource?(Ash.Resource.t()) :: boolean()
    def rpc_resource?(resource) do
      domain = Ash.Resource.Info.domain(resource)

      AshTypescript.Resource in Spark.extensions(resource) and not is_nil(domain) and
        (mode(domain) == :auto or
           domain
           |> AshTypescript.Rpc.Info.typescript_rpc()
           |> Enum.any?(&(&1.resource == resource)))
    end

    defp loadable_path(resource, [name | rest]) do
      case Ash.Resource.Info.field(resource, name) do
        %Ash.Resource.Attribute{} = attribute ->
          if embedded?(attribute.type), do: [[name]], else: []

        %{destination: destination} when rest != [] ->
          case Enum.flat_map(loadable_path(destination, rest), &[[name | &1]]) do
            [] -> [[name]]
            paths -> paths
          end

        nil ->
          []

        _loadable ->
          [[name]]
      end
    end

    defp embedded?({:array, type}), do: embedded?(type)

    defp embedded?(type),
      do: is_atom(type) and Code.ensure_loaded?(type) and Ash.Type.embedded_type?(type)
  end
end
