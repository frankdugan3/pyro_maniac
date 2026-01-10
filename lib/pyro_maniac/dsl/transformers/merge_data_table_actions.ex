defmodule PyroManiac.Dsl.Transformers.MergeDataTableActions do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias Ash.Resource
  alias PyroManiac.DataTable.{Action, ActionType, Column}
  alias Spark.Dsl.Transformer
  alias Spark.Error.DslError

  @ash_resource_transformers Resource.Dsl.transformers()

  @impl true
  def after?(module) when module in @ash_resource_transformers, do: true

  def after?(_), do: false

  @impl true
  def transform(dsl) do
    if [] == Transformer.get_entities(dsl, [:data_table]) do
      {:ok, dsl}
    else
      {:ok, merge_data_table(dsl)}
    end
  end

  defp merge_data_table(dsl) do
    context = %{
      default_class: Transformer.get_option(dsl, [:data_table], :class, nil),
      default_description: Transformer.get_option(dsl, [:data_table], :description, nil),
      dsl: dsl,
      excluded_actions: Transformer.get_option(dsl, [:data_table], :exclude, []),
      module: Transformer.get_persisted(dsl, :module, nil),
      resource: Transformer.get_persisted(dsl, :resource, nil),
      resource_actions: get_resource_actions(dsl) |> Enum.reduce(%{}, &Map.put(&2, &1.name, &1))
    }

    actions =
      for %Action{name: names} = action <-
            Transformer.get_entities(dsl, [:data_table]),
          name <- names do
        %{action | name: name}
        |> merge_action(context)
      end

    action_types =
      for %ActionType{name: names} = action_type <-
            Transformer.get_entities(dsl, [:data_table]),
          name <- names,
          into: %{} do
        {name, %{action_type | name: name}}
      end

    dsl =
      Transformer.remove_entity(dsl, [:data_table], fn
        %ActionType{} -> true
        %Action{} -> true
        _ -> false
      end)

    default_actions =
      for name <- expected_actions(context, actions) do
        %{type: type} = Map.fetch!(context.resource_actions, name)

        action_type =
          Map.get(action_types, type) ||
            raise DslError.exception(
                    module: context.module,
                    path: [:data_table],
                    message: """
                    data table for action #{inspect(name)} is not defined or excluded, and no defaults for type #{inspect(type)} exist
                    """
                  )

        action_type
        |> Map.delete(:__struct__)
        |> Map.put(:name, name)
        |> then(fn action -> struct!(Action, action) end)
        |> merge_action(context)
      end

    Enum.reduce(actions ++ default_actions, dsl, fn action, dsl ->
      Transformer.add_entity(dsl, [:data_table], action, prepend: true)
    end)
  end

  defp expected_actions(context, actions) do
    already_defined = MapSet.new(actions, & &1.name)

    context.resource_actions
    |> Map.values()
    |> Enum.filter(fn action ->
      action.name not in context.excluded_actions && action.type in [:read] &&
        action.get? == false
    end)
    |> MapSet.new(& &1.name)
    |> MapSet.difference(already_defined)
  end

  defp merge_action(%Action{name: name} = action, context) do
    resource_action =
      Map.get(context.resource_actions, name) ||
        raise DslError.exception(
                module: context.module,
                path: [:data_table, :action],
                message: """
                action #{inspect(name)} not found in resource
                """
              )

    if resource_action.get? do
      raise DslError.exception(
              module: context.module,
              path: [:data_table, :action],
              message: """
              action #{inspect(name)} does not support list results
              """
            )
    end

    if resource_action.type not in [:read] do
      raise DslError.exception(
              module: context.module,
              path: [:data_table, :action],
              message: """
              action #{inspect(name)} is an unsupported type: #{inspect(resource_action.type)}
              """
            )
    end

    if name in context.excluded_actions do
      raise DslError.exception(
              module: context.module,
              path: [:data_table, :action],
              message: """
              action #{inspect(name)} is listed in exclude
              """
            )
    end

    action
    |> Map.put(:label, action.label || default_label(name))
    |> Map.put(:class, action.class || context.default_class)
    |> expand_action_description(context)
    |> Map.put(:columns, merge_columns(action.columns, context))
  end

  defp merge_columns(columns, context) do
    Enum.reduce(columns, %{}, fn
      %Column{} = column, acc ->
        Map.put(
          acc,
          column.name,
          column
          |> expand_column_description(context)
          |> expand_column_sortable(context)
        )
    end)
  end

  defp expand_action_description(action, context) do
    description = Map.get(action, :description, context.default_description)

    description =
      if description == :inherit do
        Map.get(context.resource_action, :description)
      else
        description
      end

    Map.put(action, :description, description)
  end

  defp expand_column_sortable(column, context) do
    {name, path} = List.pop_at(column.source, -1)

    sortable? =
      column.sortable? &&
        context.resource
        |> PyroManiac.Info.resource_by_path(path)
        |> Resource.Info.sortable?(
          name,
          include_private?: false
        )

    keyset_sortable? =
      column.keyset_sortable? &&
        context.resource
        |> PyroManiac.Info.resource_by_path(path)
        |> Resource.Info.sortable?(
          name,
          pagination_type: :keyset,
          include_private?: false
        )

    column
    |> Map.put(:sortable?, sortable?)
    |> Map.put(:keyset_sortable?, keyset_sortable?)
  end

  defp expand_column_description(%{description: :inherit} = column, context) do
    {name, path} = List.pop_at(column.source, -1)

    description =
      context.resource
      |> PyroManiac.Info.resource_by_path(path)
      |> Resource.Info.field(name)
      |> Map.get(:description)

    Map.put(column, :description, description)
  end

  defp expand_column_description(column, _context), do: column
end
