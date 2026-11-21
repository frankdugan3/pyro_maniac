defmodule PyroManiac.Dsl.Transformers.ValidateSurface do
  @moduledoc false

  # The page uses only the surface of its resources (refer to
  # `PyroManiac.Resource.Expose`):
  #
  # - Each action that the page uses is exposed, and the exposed `loads`,
  #   `filter`, and `sort` cover what the page loads, filters on, and sorts on
  #   (`PyroManiac.Surface.Requirement`).
  # - Each `exclude` names something that is exposed, so the lists stay short.
  # - A view with realtime options is on a resource with a `realtime` section.
  #   For `on_create`, `on_update`, and `on_destroy`, each exposed action of
  #   the type is published to a static topic (or is in `except`), and at
  #   least one action of the type is published. `on_bulk` needs `bulk`.

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Resource.Info, as: ResourceInfo
  alias PyroManiac.Surface
  alias PyroManiac.Surface.Requirement
  alias PyroManiac.View.View

  @runs_after [
    PyroManiac.Dsl.Transformers.ResolveViewResources,
    PyroManiac.Dsl.Transformers.ExpandViewArguments,
    PyroManiac.Dsl.Transformers.ValidateViews,
    PyroManiac.Dsl.Transformers.ExpandFormActions,
    PyroManiac.Dsl.Transformers.ValidatePage
  ]

  @impl true
  def after?(module) when module in @runs_after, do: true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    resource = Transformer.get_persisted(dsl, :resource, nil)
    views = Transformer.get_entities(dsl, [:views])
    forms = Transformer.get_entities(dsl, [:forms])
    searches = Transformer.get_entities(dsl, [:searches])

    # A resource without `PyroManiac.Resource` has no surface. The verifier
    # `ResourceHasExtension` reports it.
    if pyro_maniac_resource?(resource) do
      resource
      |> Requirement.requirements(views, forms, searches)
      |> Enum.filter(&pyro_maniac_resource?(&1.resource))
      |> Enum.each(&validate_requirement(&1, module))

      validate_action_excludes(dsl, [:views], resource, [:read], module)
      validate_action_excludes(dsl, [:forms], resource, [:create, :update], module)

      for %View{} = view <- views do
        validate_view(view, resource, nil, module)
      end
    end

    {:ok, dsl}
  end

  defp pyro_maniac_resource?(resource) do
    Ash.Resource.Info.resource?(resource) and PyroManiac.Resource in Spark.extensions(resource)
  end

  defp validate_requirement(%Requirement{} = req, module) do
    case ResourceInfo.exposed(req.resource, req.action) do
      nil ->
        Error.raise!(
          module: module,
          location: req.location,
          path: req.origin,
          why:
            "action #{inspect(req.action)} of #{inspect(req.resource)} is used here, " <>
              "but it is not exposed",
          fix:
            "add `expose #{inspect(req.action)}` to the `pyro_maniac` section of " <>
              inspect(req.resource)
        )

      expose ->
        validate_paths(req, expose, :loads, req.loads, module)
        validate_paths(req, expose, :filter, req.filter, module)
        validate_paths(req, expose, :sort, req.sort, module)
    end
  end

  defp validate_paths(req, expose, key, required, module) do
    case Surface.uncovered(required, Map.get(expose, key)) do
      [] ->
        :ok

      missing ->
        Error.raise!(
          module: module,
          location: req.location,
          path: req.origin,
          why:
            "#{inspect(Surface.from_paths(missing))} is used here, but it is not in " <>
              "`#{key}` of `expose #{inspect(req.action)}` on #{inspect(req.resource)}",
          fix:
            "add #{inspect(Surface.from_paths(missing))} to `#{key}` of " <>
              "`expose #{inspect(req.action)}` in #{inspect(req.resource)}"
        )
    end
  end

  defp validate_action_excludes(dsl, section, resource, types, module) do
    for name <- Transformer.get_option(dsl, section, :exclude, []) do
      action = Ash.Resource.Info.action(resource, name)

      if is_nil(action) or action.type not in types or not ResourceInfo.exposed?(resource, name) do
        Error.raise!(
          module: module,
          location:
            Transformer.get_opt_anno(dsl, section, :exclude) ||
              Transformer.get_section_anno(dsl, section),
          path: section ++ [:exclude],
          why:
            "`exclude` has #{inspect(name)}, which is not an exposed " <>
              "#{Enum.map_join(types, " or ", &inspect/1)} action of #{inspect(resource)}",
          fix: "remove #{inspect(name)} from `exclude`"
        )
      end
    end
  end

  defp validate_view(%View{type: :delegated}, _resource, _parent, _module), do: :ok

  defp validate_view(%View{} = view, page_resource, parent, module) do
    resource = view.resource || page_resource

    validate_field_excludes(view, resource, parent, module)
    validate_realtime(view, resource, module)

    for %View{} = nested <- view.views || [] do
      validate_view(nested, page_resource, resource, module)
    end
  end

  defp validate_field_excludes(%View{exclude: exclude} = view, resource, parent, module)
       when exclude not in [nil, []] do
    exposed =
      view
      |> Requirement.view_actions(parent)
      |> Enum.flat_map(fn action ->
        case ResourceInfo.exposed(resource, action) do
          nil -> []
          expose -> Surface.top_level(expose.loads)
        end
      end)

    for name <- exclude, name not in exposed do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :exclude) || Entity.anno(view),
        path: [:views, :view, view_name(view), :exclude],
        why:
          "`exclude` has #{inspect(name)}, which is not an exposed field of the " <>
            "read action of this view on #{inspect(resource)}",
        fix: "remove #{inspect(name)} from `exclude`"
      )
    end
  end

  defp validate_field_excludes(_view, _resource, _parent, _module), do: :ok

  @record_options [on_create: :create, on_update: :update, on_destroy: :destroy]

  defp validate_realtime(%View{} = view, resource, module) do
    options =
      Enum.filter([:on_create, :on_update, :on_destroy, :on_bulk], fn option ->
        Map.get(view, option) not in [nil, :none]
      end)

    cond do
      options == [] ->
        :ok

      not ResourceInfo.realtime?(resource) ->
        realtime_error(view, hd(options), module,
          why:
            "the view has realtime options (#{Enum.map_join(options, ", ", &"`#{&1}`")}), " <>
              "but #{inspect(resource)} has no `realtime` section",
          fix:
            "add `realtime do mode :auto end` to the `pyro_maniac` section of #{inspect(resource)}"
        )

      true ->
        Enum.each(options, &validate_realtime_option(view, &1, resource, module))
    end
  end

  # Each exposed action of the type sends its notifications to a static
  # topic, or it is in `except`. Some action of the type is published, else
  # the option has no effect.
  defp validate_realtime_option(view, :on_bulk, resource, module) do
    if ResourceInfo.realtime_bulk(resource) == [] do
      realtime_error(view, :on_bulk, module,
        why:
          "`on_bulk #{inspect(view.on_bulk)}` has no effect: #{inspect(resource)} has no " <>
            "`bulk` in its `realtime` section",
        fix:
          "add the bulk actions (or events) to `bulk` in the `realtime` section of " <>
            "#{inspect(resource)}, or remove `on_bulk`"
      )
    end
  end

  defp validate_realtime_option(view, option, resource, module) do
    type = Keyword.fetch!(@record_options, option)
    except = ResourceInfo.realtime_except(resource)
    actions = resource |> Ash.Resource.Info.actions() |> Enum.filter(&(&1.type == type))
    published = Enum.filter(actions, &ResourceInfo.published?(resource, &1))

    unpublished =
      Enum.find(actions, fn action ->
        ResourceInfo.exposed?(resource, action.name) and action.name not in except and
          action not in published
      end)

    cond do
      unpublished ->
        realtime_error(view, option, module,
          why:
            "`#{option} #{inspect(Map.get(view, option))}` misses the changes of the exposed " <>
              "action #{inspect(unpublished.name)}: no publication with a static topic sends " <>
              "its notifications",
          fix:
            "publish #{inspect(unpublished.name)} in `pub_sub` of #{inspect(resource)}, add it " <>
              "to `except` in `realtime`, or use `mode :auto`"
        )

      published == [] ->
        realtime_error(view, option, module,
          why:
            "`#{option} #{inspect(Map.get(view, option))}` has no effect: no #{type} action " <>
              "of #{inspect(resource)} is published to a static topic",
          fix:
            "publish a #{type} action in `pub_sub` of #{inspect(resource)}, or remove `#{option}`"
        )

      true ->
        :ok
    end
  end

  defp realtime_error(view, option, module, opts) do
    Error.raise!(
      [
        module: module,
        location: Entity.property_anno(view, option) || Entity.anno(view),
        path: [:views, :view, view_name(view), option]
      ] ++ opts
    )
  end

  defp view_name(%View{name: [name | _]}), do: name
  defp view_name(_view), do: :view
end
