defmodule PyroManiac.Dsl.Verifiers.DataTable.DefaultSortsValid do
  @moduledoc """
  Ensure all actions have a valid default sort.
  """
  use PyroManiac.Dsl.Verifiers

  alias PyroManiac.DataTable.Action

  @impl true
  def verify(dsl) do
    context = %{
      dsl: dsl,
      module: Verifier.get_persisted(dsl, :module, nil),
      resource: Verifier.get_persisted(dsl, :resource, nil)
    }

    for %Action{} = action <- Verifier.get_entities(dsl, [:data_table]) do
      context =
        context
        |> Map.put(:action, action)
        |> Map.put(:columns, action.columns |> Map.values() |> MapSet.new(& &1.source))

      case Ash.Sort.parse_input(context.resource, action.default_sort) do
        {:ok, []} ->
          raise DslError.exception(
                  module: context.module,
                  path: [:data_table, :action, action.name, :default_sort],
                  message: "#{inspect(action.default_sort)}: must sort on at least one column"
                )

        {:ok, sort} when is_list(sort) ->
          sorts_are_columns(sort, context)
          :ok

        {:error, error} ->
          raise DslError.exception(
                  module: context.module,
                  path: [:data_table, :action, action.name, :default_sort],
                  message: """
                  #{inspect(action.default_sort)} is an invalid Ash sort.

                  #{Ash.Error.error_descriptions(error)}\
                  """
                )
      end
    end

    :ok
  end

  defp sorts_are_columns(sort, context) do
    for sort <- flatten_sort(sort) do
      if !MapSet.member?(context.columns, sort) do
        raise DslError.exception(
                module: context.module,
                path: [:data_table, :action, context.action.name, :default_sort],
                message: "key #{inspect(sort)} is an undefined or excluded column"
              )
      end
    end
  end

  defp flatten_sort(sort, acc \\ [], path \\ []) do
    sort
    |> Enum.reduce(acc, fn
      {key, nested}, acc when is_list(nested) ->
        flatten_sort(acc, nested, path ++ [key])

      {key, direction}, acc when is_atom(direction) ->
        [path ++ [key] | acc]
    end)
  end
end
