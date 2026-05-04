defmodule PyroManiac.Navigation.Authorization do
  @moduledoc """
  Authorization filtering for navigation trees.

  Filters navigation items based on the current user's scope by resolving
  each page item's resource and default read action, then checking
  `Ash.can?/3` with `run_queries?: false`. Groups with no visible
  children after filtering are removed.
  """

  alias PyroManiac.Navigation.{Group, Item}

  @doc """
  Filters a navigation tree, removing items the given scope is not authorized to see.

  Recursively filters group children and removes empty groups. A `nil` scope
  is passed through to `Ash.can?/3` as a `nil` actor — items whose policies
  require an authenticated actor are filtered out.
  """
  @spec filter_authorized(list(), any()) :: list()
  def filter_authorized(entities, scope) do
    entities
    |> Enum.map(fn
      %Group{items: items} = group ->
        filtered = filter_authorized(items || [], scope)
        %{group | items: filtered}

      %Item{} = item ->
        item
    end)
    |> Enum.filter(fn
      %Group{items: []} -> false
      %Group{} -> true
      %Item{page: page} when not is_nil(page) -> authorized?(page, scope)
      %Item{} -> true
    end)
  end

  @doc """
  Returns `true` if the given page module's default read action is authorized for `scope`.

  Falls back to `true` if the resource or action cannot be resolved.
  """
  @spec authorized?(module(), any()) :: boolean()
  def authorized?(page_module, scope) do
    with {:ok, resource} <- fetch_resource(page_module),
         {:ok, action} <- fetch_default_read_action(page_module, resource) do
      Ash.can?({resource, action}, scope, run_queries?: false)
    else
      _ -> true
    end
  end

  defp fetch_resource(page_module) do
    case Spark.Dsl.Extension.get_persisted(page_module, :resource) do
      nil -> :error
      resource -> {:ok, resource}
    end
  rescue
    _ -> :error
  end

  defp fetch_default_read_action(page_module, resource) do
    view =
      PyroManiac.Info.primary_view(page_module, :data_table) ||
        PyroManiac.Info.primary_view(page_module, :grid)

    action_name =
      case view do
        %{name: [name | _]} -> name
        %{name: name} when is_atom(name) -> name
        _ -> nil
      end

    action =
      if action_name do
        Ash.Resource.Info.action(resource, action_name)
      else
        Ash.Resource.Info.primary_action(resource, :read)
      end

    case action do
      nil -> :error
      action -> {:ok, action}
    end
  rescue
    _ -> :error
  end
end
