defmodule PyroManiac.Dsl.Verifiers.ResourceHasExtension do
  @moduledoc false
  use PyroManiac.Dsl.Verifiers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Form.{Action, FieldGroup}
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
              "`pyro_maniac do default_label :foo end`"
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
             "`pyro_maniac do default_label :foo end`"
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
      collect_section_rels(view.sections || [], resource) ++
      collect_nested_rels(view.views || [], resource)
  end

  defp collect_column_rels(columns, resource) do
    for col <- columns,
        [first | _rest] when length(col.source) > 1 <- [col.source || []],
        rel = Ash.Resource.Info.relationship(resource, first),
        rel != nil do
      {first, rel.destination}
    end
  end

  defp collect_section_rels(sections, resource) do
    for section <- sections,
        rel_entity <- section.relationships || [],
        rel = Ash.Resource.Info.relationship(resource, rel_entity.name),
        rel != nil do
      {rel_entity.name, rel.destination}
    end
  end

  defp collect_nested_rels(views, resource) do
    Enum.flat_map(views, fn nested ->
      walk_nested_view(nested, resource)
    end)
  end

  defp walk_nested_view(%{relationship: nil} = nested, resource) do
    walk_view(nested, nested.resource || resource)
  end

  defp walk_nested_view(%{relationship: rel_name} = nested, resource) do
    case Ash.Resource.Info.relationship(resource, rel_name) do
      nil -> []
      rel -> [{rel_name, rel.destination} | walk_view(nested, rel.destination)]
    end
  end

  defp collect_form_relationships(dsl, resource) do
    forms = Spark.Dsl.Extension.get_entities(dsl, [:forms])

    for %Action{fields: fields} <- forms,
        {rel_name, dest} <- walk_fields(fields, resource) do
      {rel_name, dest}
    end
  end

  defp walk_fields(fields, resource) do
    Enum.flat_map(fields || [], fn
      %FieldGroup{fields: children, path: [rel_name | _rest]} ->
        case Ash.Resource.Info.relationship(resource, rel_name) do
          nil -> []
          rel -> [{rel_name, rel.destination} | walk_fields(children, rel.destination)]
        end

      %FieldGroup{fields: children} ->
        walk_fields(children, resource)

      _ ->
        []
    end)
  end
end
