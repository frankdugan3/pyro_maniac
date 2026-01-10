defmodule PyroManiac.Dsl.Verifiers.DataTable.AllPublicIncluded do
  @moduledoc """
  Ensures all public fields for each action are defined as columns or excluded.
  """

  use PyroManiac.Dsl.Verifiers

  alias Ash.Resource.Info, as: ResourceInfo
  alias PyroManiac.DataTable.{Action, Column}

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
        |> Map.put(:nested_columns, nested_columns(action))
        |> Map.put(:root_columns, root_columns(action))

      attributes_included(action, context)
      calculations_included(action, context)
      aggregates_included(action, context)
      relationships_included(action, context)
    end

    :ok
  end

  defp attributes_included(action, context) do
    for field <- ResourceInfo.public_attributes(context.resource) do
      if !MapSet.member?(context.root_columns, field.name) do
        raise DslError.exception(
                module: context.module,
                path: [:data_table, :action, action.name],
                message:
                  "public attribute #{inspect(field.name)} is not a defined or excluded column"
              )
      end
    end
  end

  defp calculations_included(action, context) do
    for field <- ResourceInfo.public_calculations(context.resource) do
      if !MapSet.member?(context.root_columns, field.name) do
        raise DslError.exception(
                module: context.module,
                path: [:data_table, :action, action.name],
                message:
                  "public calculation #{inspect(field.name)} is not a defined or excluded column"
              )
      end
    end
  end

  defp aggregates_included(action, context) do
    for field <- ResourceInfo.public_aggregates(context.resource) do
      if !MapSet.member?(context.root_columns, field.name) do
        raise DslError.exception(
                module: context.module,
                path: [:data_table, :action, action.name],
                message:
                  "public aggregation #{inspect(field.name)} is not a defined or excluded column"
              )
      end
    end
  end

  defp relationships_included(action, context) do
    for field <- ResourceInfo.public_relationships(context.resource) do
      if !MapSet.member?(context.nested_columns, field.name) do
        raise DslError.exception(
                module: context.module,
                path: [:data_table, :action, action.name],
                message:
                  "public relationship #{inspect(field.name)} is not a defined or excluded column"
              )
      end
    end
  end

  defp root_columns(action) do
    excluded = MapSet.new(action.exclude)

    defined =
      action.columns
      |> Map.values()
      |> Enum.reduce(MapSet.new(), fn
        %Column{source: [key]}, acc -> MapSet.put(acc, key)
        _, acc -> acc
      end)
      |> MapSet.new()

    MapSet.union(excluded, defined)
  end

  defp nested_columns(action) do
    excluded = MapSet.new(action.exclude)

    defined =
      action.columns
      |> Map.values()
      |> Enum.reduce(MapSet.new(), fn
        %Column{source: source}, acc -> MapSet.put(acc, source)
        _, acc -> acc
      end)
      |> MapSet.new()

    MapSet.union(excluded, defined)
  end
end
