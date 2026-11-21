defmodule PyroManiac.Resource.Verifiers.VerifyExpose do
  @moduledoc false
  use Spark.Dsl.Verifier

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Resource.Expose
  alias PyroManiac.Surface
  alias Spark.Dsl.Entity

  @impl true
  def verify(dsl) do
    module = Spark.Dsl.Verifier.get_persisted(dsl, :module)
    exposes = PyroManiac.Resource.Info.exposed(dsl)

    with :ok <- verify_unique(exposes, module) do
      Enum.find_value(exposes, :ok, &error_of(verify_expose(&1, dsl, module)))
    end
  end

  defp error_of(:ok), do: nil
  defp error_of(error), do: error

  defp verify_unique(exposes, module) do
    exposes
    |> Enum.group_by(& &1.name)
    |> Enum.find(fn {_name, group} -> length(group) > 1 end)
    |> case do
      nil ->
        :ok

      {name, [_ | [second | _]]} ->
        error(module, second, [:pyro_maniac, :expose, name],
          why: "action #{inspect(name)} is exposed more than once",
          fix: "expose each action in one `expose` only"
        )
    end
  end

  defp verify_expose(%Expose{name: name} = expose, dsl, module) do
    path = [:pyro_maniac, :expose, name]

    case Ash.Resource.Info.action(dsl, name) do
      nil ->
        error(module, expose, path,
          why: "action #{inspect(name)} does not exist",
          suggestions:
            Error.did_you_mean(name, Enum.map(Ash.Resource.Info.actions(dsl), & &1.name))
        )

      %{public?: false} ->
        error(module, expose, path,
          why: "action #{inspect(name)} is not public, so it cannot be exposed",
          fix: "set `public? true` on the action, or remove it from `expose`"
        )

      action ->
        with :ok <- verify_read_only(expose, action, module, path),
             :ok <- verify_fields(expose, :loads, dsl, module, path, &loadable/2),
             :ok <- verify_fields(expose, :filter, dsl, module, path, &usable(&1, &2, :filter)) do
          verify_fields(expose, :sort, dsl, module, path, &usable(&1, &2, :sort))
        end
    end
  end

  defp verify_read_only(%Expose{filter: filter, sort: sort} = expose, action, module, path) do
    if action.type != :read and (filter != [] or sort != []) do
      error(module, expose, path,
        why:
          "action #{inspect(action.name)} is a #{inspect(action.type)} action, " <>
            "but `filter` and `sort` are only for read actions",
        fix: "remove `filter` and `sort` from this `expose`"
      )
    else
      :ok
    end
  end

  defp verify_fields(expose, key, dsl, module, path, kind) do
    expose
    |> Map.get(key)
    |> Surface.paths()
    |> Enum.find_value(:ok, fn field_path ->
      case check_path(dsl, field_path, kind) do
        :ok ->
          nil

        {:error, why} ->
          error(module, expose, path ++ [key],
            why: "#{inspect(key)} has #{format_path(field_path)}: #{why}"
          )
      end
    end)
  end

  defp check_path(resource, [name], kind), do: kind.(resource, name)

  defp check_path(resource, [name | rest], kind) do
    case Ash.Resource.Info.relationship(resource, name) do
      %{public?: true, destination: destination} ->
        check_path(destination, rest, kind)

      %{} ->
        {:error, "relationship #{inspect(name)} is not public"}

      nil ->
        {:error, "#{inspect(name)} is not a relationship of #{name_of(resource)}"}
    end
  end

  defp loadable(resource, name) do
    case Ash.Resource.Info.field(resource, name) do
      nil -> {:error, "#{inspect(name)} is not a field of #{name_of(resource)}"}
      %{public?: true} -> :ok
      _ -> {:error, "#{inspect(name)} is not public on #{name_of(resource)}"}
    end
  end

  # A field in `filter` or `sort` is public, and Ash allows it there
  # (`filterable?`, `sortable?`).
  defp usable(resource, name, option) do
    with :ok <- loadable(resource, name) do
      if PyroManiac.Resource.Info.usable?(Ash.Resource.Info.field(resource, name), option),
        do: :ok,
        else: {:error, "#{inspect(name)} is not #{option}able on #{name_of(resource)}"}
    end
  end

  defp error(module, entity, path, opts) do
    {:error, Error.build([module: module, location: Entity.anno(entity), path: path] ++ opts)}
  end

  defp format_path(path), do: path |> Enum.map_join(".", &to_string/1)

  defp name_of(resource) when is_atom(resource), do: inspect(resource)

  defp name_of(dsl) do
    dsl |> Spark.Dsl.Verifier.get_persisted(:module) |> inspect()
  end
end
