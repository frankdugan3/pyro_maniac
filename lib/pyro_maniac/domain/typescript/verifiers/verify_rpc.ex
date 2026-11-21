if Code.ensure_loaded?(AshTypescript.Rpc) do
  defmodule PyroManiac.Domain.Typescript.Verifiers.VerifyRpc do
    @moduledoc false
    use Spark.Dsl.Verifier

    alias PyroManiac.Domain.Typescript.Info
    alias PyroManiac.Dsl.Error
    alias PyroManiac.Surface

    @section [:pyro_maniac_typescript]

    @impl true
    def verify(dsl) do
      module = Spark.Dsl.Verifier.get_persisted(dsl, :module)
      rpc_resources = Spark.Dsl.Extension.get_entities(dsl, [:typescript_rpc])

      dsl
      |> Ash.Domain.Info.resource_references()
      |> Enum.map(& &1.resource)
      |> Enum.filter(&(PyroManiac.Resource in Spark.extensions(&1)))
      |> Enum.reject(&(PyroManiac.Resource.Info.exposed(&1) == []))
      |> Enum.reduce_while(:ok, fn resource, :ok ->
        case verify_resource(dsl, module, resource, rpc_resources) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end

    defp verify_resource(dsl, module, resource, rpc_resources) do
      if AshTypescript.Resource in Spark.extensions(resource) do
        rpc_actions =
          rpc_resources
          |> Enum.filter(&(&1.resource == resource))
          |> Enum.flat_map(& &1.rpc_actions)

        exposed = PyroManiac.Resource.Info.exposed(resource)

        with :ok <-
               Enum.find_value(
                 exposed,
                 :ok,
                 &verify_expose(dsl, module, resource, &1, rpc_actions)
               ) do
          Enum.find_value(exposed, :ok, &verify_destinations(dsl, module, resource, &1))
        end
      else
        type_name =
          resource |> Module.split() |> Enum.drop(1) |> Enum.join()

        error(dsl, module,
          why:
            "#{inspect(resource)} has `expose` entities, but it does not use the " <>
              "AshTypescript.Resource extension",
          fix:
            "add AshTypescript.Resource to the extensions of #{inspect(resource)}, " <>
              "and add `typescript do type_name #{inspect(type_name)} end`"
        )
      end
    end

    # A client can load the records that the exposed loads reach, so each of
    # these resources needs TypeScript types.
    # A resource of this domain is checked against this domain (the resource
    # can have no `domain:`); another resource against its own domain.
    defp rpc_resource?(dsl, destination) do
      local? =
        dsl
        |> Ash.Domain.Info.resource_references()
        |> Enum.any?(&(&1.resource == destination))

      if local? do
        AshTypescript.Resource in Spark.extensions(destination) and
          (Spark.Dsl.Extension.get_opt(dsl, [:pyro_maniac_typescript], :mode, :validate) == :auto or
             dsl
             |> Spark.Dsl.Extension.get_entities([:typescript_rpc])
             |> Enum.any?(&(&1.resource == destination)))
      else
        Info.rpc_resource?(destination)
      end
    end

    defp verify_destinations(dsl, module, resource, expose) do
      resource
      |> Info.load_destinations(expose.loads)
      |> Enum.find(fn {destination, _path} -> not rpc_resource?(dsl, destination) end)
      |> case do
        nil ->
          nil

        {destination, path} ->
          type_name = destination |> Module.split() |> Enum.drop(1) |> Enum.join()

          error(dsl, module,
            why:
              "`loads` of `expose #{inspect(expose.name)}` on #{inspect(resource)} reaches " <>
                "#{inspect(destination)} (#{Enum.join(path, ".")}), which has no TypeScript types",
            fix:
              "add AshTypescript.Resource and `typescript do type_name #{inspect(type_name)} end` " <>
                "to #{inspect(destination)}, and `PyroManiac.Domain.Typescript` (`mode :auto`) to " <>
                "#{inspect(Ash.Resource.Info.domain(destination))}; or remove the load"
          )
      end
    end

    defp verify_expose(dsl, module, resource, expose, rpc_actions) do
      case Enum.find(rpc_actions, &(&1.action == expose.name)) do
        nil ->
          error(dsl, module,
            why:
              "action #{inspect(expose.name)} of #{inspect(resource)} is exposed, but it has " <>
                "no `rpc_action` in `typescript_rpc`",
            fix:
              "add `rpc_action #{inspect(Info.rpc_name_fun(dsl).(resource, expose.name))}, " <>
                "#{inspect(expose.name)}` to `typescript_rpc`, or use `mode :auto`"
          )

        rpc_action ->
          verify_rpc_action(dsl, module, resource, expose, rpc_action)
      end
    end

    defp verify_rpc_action(dsl, module, resource, expose, rpc_action) do
      missing =
        resource
        |> Info.allowed_loads(expose.loads)
        |> Surface.paths()
        |> missing_loads(rpc_action)

      cond do
        missing != [] ->
          error(dsl, module,
            why:
              "rpc action #{inspect(rpc_action.name)} does not allow the exposed loads " <>
                "#{inspect(Surface.from_paths(missing))} of #{inspect(resource)}",
            fix: "add them to `allowed_loads`, or remove them from `denied_loads`"
          )

        expose.filter != [] and rpc_action.enable_filter? == false ->
          error(dsl, module,
            why:
              "rpc action #{inspect(rpc_action.name)} disables filter, but the exposed " <>
                "action #{inspect(expose.name)} has `filter` fields",
            fix: "remove `enable_filter? false`, or remove `filter` from the `expose`"
          )

        expose.sort != [] and rpc_action.enable_sort? == false ->
          error(dsl, module,
            why:
              "rpc action #{inspect(rpc_action.name)} disables sort, but the exposed " <>
                "action #{inspect(expose.name)} has `sort` fields",
            fix: "remove `enable_sort? false`, or remove `sort` from the `expose`"
          )

        true ->
          nil
      end
    end

    # The required paths that the `allowed_loads` or `denied_loads` of the
    # rpc action do not allow.
    defp missing_loads(required, %{allowed_loads: allowed}) when not is_nil(allowed),
      do: Surface.uncovered(required, allowed)

    defp missing_loads(required, %{denied_loads: denied}) when not is_nil(denied) do
      denied = Surface.paths(denied)
      Enum.filter(required, fn path -> Enum.any?(denied, &List.starts_with?(path, &1)) end)
    end

    defp missing_loads(_required, _rpc_action), do: []

    defp error(dsl, module, opts) do
      {:error,
       Error.build(
         [
           module: module,
           location: Spark.Dsl.Extension.get_section_anno(dsl, @section),
           path: @section
         ] ++ opts
       )}
    end
  end
end
