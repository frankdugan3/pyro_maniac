defmodule PyroManiac.Dsl.Verifiers.ResourceHasExtension do
  @moduledoc false
  use PyroManiac.Dsl.Verifiers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Form.{Action, Tree}
  alias PyroManiac.View.View

  @impl true
  def verify(dsl) do
    module = Verifier.get_persisted(dsl, :module)
    resource = Verifier.get_persisted(dsl, :resource)

    with :ok <- check_resource(resource, module) do
      dsl
      |> collect_relationship_destinations(resource)
      |> Enum.uniq()
      |> Enum.reduce_while(:ok, fn {rel_name, destination}, :ok ->
        check_destination(destination, rel_name, module)
      end)
    end
  end

  defp check_destination(destination, rel_name, module) do
    if PyroManiac.Resource.Info.default_label(destination) do
      {:cont, :ok}
    else
      {:halt,
       {:error,
        Error.build(
          module: module,
          path: [:relationship, rel_name],
          why:
            "relationship #{inspect(rel_name)} targets #{inspect(destination)}, " <>
              "which must use the PyroManiac.Resource extension with a default_label configured",
          fix:
            "add `extensions: [PyroManiac.Resource]` to #{inspect(destination)} and configure " <>
              "`pyro_maniac do default_label :name end`"
        )}}
    end
  end

  defp check_resource(resource, module) do
    if PyroManiac.Resource.Info.default_label(resource) do
      :ok
    else
      {:error,
       Error.build(
         module: module,
         path: [:resource],
         why:
           "resource #{inspect(resource)} must use the PyroManiac.Resource extension with a " <>
             "default_label configured",
         fix:
           "add `extensions: [PyroManiac.Resource]` to #{inspect(resource)} and configure " <>
             "`pyro_maniac do default_label :name end`"
       )}
    end
  end

  defp collect_relationship_destinations(dsl, resource) do
    collect_view_relationships(dsl, resource) ++
      collect_form_relationships(dsl, resource)
  end

  defp collect_view_relationships(dsl, resource) do
    views = Verifier.get_persisted(dsl, :views_by_action_and_type) || %{}

    for {_key, %View{} = view} <- views,
        {rel_name, dest} <- walk_view(view, resource) do
      {rel_name, dest}
    end
  end

  defp walk_view(%View{} = view, resource) do
    collect_column_rels(view.columns || [], resource) ++
      collect_tree_rels(view.__tree__ || [], resource)
  end

  defp collect_column_rels(columns, resource) do
    for col <- columns,
        [first | _rest] when length(col.source) > 1 <- [col.source || []],
        rel = Ash.Resource.Info.relationship(resource, first),
        rel != nil do
      {first, rel.destination}
    end
  end

  defp collect_tree_rels(tree, resource) do
    # A `related` shows the labels of its records without fields.
    for %PyroManiac.Form.Related{fields: [], delegate_to: nil} = related <-
          PyroManiac.Form.Tree.all(tree),
        rel =
          Ash.Resource.Info.relationship(
            resource_at(resource, related.__full_path__),
            related.name
          ),
        rel != nil do
      {related.name, rel.destination}
    end
  end

  defp resource_at(resource, path) do
    PyroManiac.Info.resource_by_path(resource, path)
  rescue
    ArgumentError -> resource
  end

  defp collect_form_relationships(dsl, resource) do
    forms = Spark.Dsl.Extension.get_entities(dsl, [:forms])

    for %Action{fields: fields} <- forms,
        {rel_name, dest} <- walk_fields(fields, resource) do
      {rel_name, dest}
    end
  end

  # Each entity with a relative `path` (a section, a step, or a nested input)
  # follows the relationships of that path.
  defp walk_fields(fields, resource) do
    Enum.flat_map(fields || [], fn entity ->
      {pairs, destination} = follow_path(Map.get(entity, :path) || [], resource)
      pairs ++ walk_fields(Tree.children(entity), destination)
    end)
  end

  defp follow_path([], resource), do: {[], resource}

  defp follow_path([rel_name | rest], resource) do
    case Ash.Resource.Info.relationship(resource, rel_name) do
      nil ->
        {[], resource}

      rel ->
        {pairs, destination} = follow_path(rest, rel.destination)
        {[{rel_name, rel.destination} | pairs], destination}
    end
  end
end
