if Code.ensure_loaded?(AshTypescript.Rpc) do
  defmodule PyroManiac.Domain.Typescript.Transformers.AddRpcActions do
    @moduledoc false
    use Spark.Dsl.Transformer

    alias PyroManiac.Domain.Typescript.Info
    alias Spark.Dsl.Transformer

    @impl true
    def transform(dsl) do
      case Transformer.get_option(dsl, [:pyro_maniac_typescript], :mode, :validate) do
        :auto -> {:ok, add_rpc_actions(dsl)}
        _ -> {:ok, dsl}
      end
    end

    defp add_rpc_actions(dsl) do
      rpc_name = Info.rpc_name_fun(dsl)

      dsl
      |> Ash.Domain.Info.resource_references()
      |> Enum.map(& &1.resource)
      |> Enum.filter(&surface_or_typescript?/1)
      |> Enum.reduce(dsl, &add_resource(&2, &1, rpc_name))
    end

    # A resource with `AshTypescript.Resource` is listed in `typescript_rpc`
    # also when it exposes no action: then it has TypeScript types (for
    # example, the destination of an exposed relationship load).
    defp surface_or_typescript?(resource) do
      Code.ensure_compiled!(resource)
      extensions = Spark.extensions(resource)
      PyroManiac.Resource in extensions or AshTypescript.Resource in extensions
    end

    defp add_resource(dsl, resource, rpc_name) do
      existing =
        dsl
        |> Transformer.get_entities([:typescript_rpc])
        |> Enum.find(&(&1.resource == resource))

      written = MapSet.new((existing && existing.rpc_actions) || [], & &1.action)

      new_rpc_actions =
        for expose <- PyroManiac.Resource.Info.exposed(resource),
            not MapSet.member?(written, expose.name) do
          rpc_action(resource, expose, rpc_name)
        end

      typescript? = AshTypescript.Resource in Spark.extensions(resource)

      cond do
        new_rpc_actions == [] and (existing || not typescript?) ->
          dsl

        existing ->
          Transformer.replace_entity(
            dsl,
            [:typescript_rpc],
            %{existing | rpc_actions: existing.rpc_actions ++ new_rpc_actions},
            &(&1 == existing)
          )

        true ->
          entity =
            Transformer.build_entity!(AshTypescript.Rpc, [:typescript_rpc], :resource,
              resource: resource
            )

          Transformer.add_entity(
            dsl,
            [:typescript_rpc],
            %{entity | rpc_actions: new_rpc_actions},
            type: :append
          )
      end
    end

    defp rpc_action(resource, expose, rpc_name) do
      Transformer.build_entity!(AshTypescript.Rpc, [:typescript_rpc, :resource], :rpc_action,
        name: rpc_name.(resource, expose.name),
        action: expose.name,
        allowed_loads: Info.allowed_loads(resource, expose.loads),
        enable_filter?: expose.filter != [],
        enable_sort?: expose.sort != []
      )
    end
  end
end
