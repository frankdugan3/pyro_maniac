defmodule PyroManiac.Dsl.Transformers.ValidateViews do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias Ash.Resource
  alias PyroManiac.Dsl.Error
  alias PyroManiac.View.{Column, View}

  @valid_edit_with_input_types [
    :autocomplete,
    :checkbox,
    :color,
    :date,
    :datetime,
    :email,
    :number,
    :password,
    :range,
    :select,
    :tel,
    :text,
    :textarea,
    :time,
    :url
  ]

  @ash_resource_transformers Resource.Dsl.transformers()

  @impl true
  def after?(PyroManiac.Dsl.Transformers.ResolveViewResources), do: true
  def after?(module) when module in @ash_resource_transformers, do: true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    views = Transformer.get_entities(dsl, [:views])

    validate_no_duplicate_views(views, module)

    default_resource = Transformer.get_persisted(dsl, :resource, nil)

    {final_views, any_kanban_mutated?} =
      Enum.map_reduce(views, false, fn
        %View{type: :delegated} = view, mutated? ->
          validate_delegated_view(view, module)
          {view, mutated?}

        %View{type: :kanban} = view, _mutated? ->
          resource = view.resource || default_resource
          validate_non_delegated_view(view, module)
          validate_view(view, resource, module)
          view = populate_kanban_from_extension(view, resource)
          {view, true}

        %View{} = view, mutated? ->
          resource = view.resource || default_resource
          validate_non_delegated_view(view, module)
          validate_view(view, resource, module)
          {view, mutated?}
      end)

    dsl =
      if any_kanban_mutated? do
        dsl =
          Transformer.remove_entity(dsl, [:views], fn
            %View{} -> true
            _ -> false
          end)

        Enum.reduce(final_views, dsl, fn view, dsl ->
          Transformer.add_entity(dsl, [:views], view, prepend: true)
        end)
      else
        dsl
      end

    {:ok, dsl}
  end

  defp validate_no_duplicate_views(views, module) do
    pairs =
      for %View{name: names, type: type} = view <- views,
          type != :delegated,
          name <- names do
        {name, type, view}
      end

    Enum.reduce(pairs, %{}, fn {name, type, view}, seen ->
      key = {name, type}

      if Map.has_key?(seen, key) do
        Error.raise!(
          module: module,
          location: Entity.anno(view),
          path: [:views, :view, name, type],
          why:
            "view {#{inspect(name)}, #{inspect(type)}} is already defined. " <>
              "Each action + type combination must be unique."
        )
      else
        Map.put(seen, key, true)
      end
    end)
  end

  defp validate_delegated_view(%View{type: :delegated} = view, module) do
    if is_nil(view.delegate_to) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :delegate_to) || Entity.anno(view),
        path: [:views, :view, :delegated],
        why: "delegated views require `delegate_to` to be set",
        fix:
          "add `delegate_to SomeModule` inside the view block, where SomeModule is a PyroManiac module"
      )
    end

    if view.ensure_loaded != [] do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :ensure_loaded) || Entity.anno(view),
        path: [:views, :view, :delegated],
        why:
          "`ensure_loaded` is not allowed on `:delegated` views — " <>
            "the delegated module owns its own loads",
        fix: "set `ensure_loaded` on the views inside the delegated module instead"
      )
    end

    if view.columns != [] or view.fields != [] or view.sections != [] or
         (is_list(view.views) and view.views != []) do
      Error.raise!(
        module: module,
        location: Entity.anno(view),
        path: [:views, :view, :delegated],
        why:
          "delegated views must not have columns, fields, sections, or nested views — " <>
            "the delegated module owns its own DSL",
        fix:
          "remove all child entities from this view, or change `type :delegated` to a regular type"
      )
    end
  end

  defp validate_non_delegated_view(%View{} = view, module) do
    if view.name == [] do
      Error.raise!(
        module: module,
        location: Entity.anno(view),
        path: [:views, :view],
        why: "non-delegated views require `name` to be set",
        fix: "add an action name like `view :read do ... end`"
      )
    end

    if view.delegate_to do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :delegate_to) || Entity.anno(view),
        path: [:views, :view, hd(view.name)],
        why: "`delegate_to` is only allowed on `:delegated` views",
        fix: "use `type :delegated` to mount a full sub-Viewer, or remove `delegate_to`"
      )
    end
  end

  defp validate_view(%View{} = view, resource, module) do
    validate_ensure_loaded(view, resource, module)
    do_validate_view(view, resource, module)
  end

  defp validate_ensure_loaded(%View{ensure_loaded: []}, _resource, _module), do: :ok

  defp validate_ensure_loaded(%View{ensure_loaded: ensure_loaded} = view, resource, module) do
    query = Ash.Query.load(Ash.Query.new(resource), ensure_loaded)

    if !query.valid? do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :ensure_loaded) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :ensure_loaded],
        why:
          "#{inspect(ensure_loaded)} is an invalid Ash load statement for #{inspect(resource)}.\n\n" <>
            Ash.Error.error_descriptions(query.errors)
      )
    end
  end

  defp do_validate_view(%View{type: :data_table} = view, resource, module) do
    validate_action_exists(view, resource, module)
    validate_no_duplicate_columns(view, module)
    validate_all_columns_valid(view, resource, module)
    validate_all_public_included(view, resource, module)
    validate_default_displays_valid(view, module)
    validate_default_sorts_valid(view, resource, module)
    validate_edit_with_valid(view, resource, module)
    validate_realtime_pubsub(view, resource, module)
    validate_nested_views(view, module)
  end

  defp do_validate_view(%View{type: :render} = view, _resource, module) do
    if is_nil(view.render) && is_nil(view.component) do
      Error.raise!(
        module: module,
        location: Entity.anno(view),
        path: [:views, :view, hd(view.name)],
        why: "render views must have either `render` or `component` set",
        fix: "set `render fn assigns -> ... end` or `component MyComponent` inside the view block"
      )
    end
  end

  defp do_validate_view(%View{type: :kanban} = view, resource, module) do
    validate_action_exists(view, resource, module)

    if !PyroManiac.KanBan.Info.has_kanban?(resource) do
      Error.raise!(
        module: module,
        location: Entity.anno(view),
        path: [:views, :view, hd(view.name)],
        why:
          "kanban views require the resource #{inspect(resource)} to use the PyroManiac.KanBan extension",
        fix: "add `use PyroManiac.KanBan` to the resource"
      )
    end

    validate_nested_views(view, module)
  end

  defp do_validate_view(%View{type: :calendar} = view, resource, module) do
    validate_action_exists(view, resource, module)

    if is_nil(view.date_field) do
      candidates = date_attribute_names(resource)

      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :date_field) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :date_field],
        why: "calendar views require `date_field` to be set",
        suggestions: candidates,
        fix: "set `date_field :foo` to a date or datetime attribute on the resource"
      )
    end

    validate_nested_views(view, module)
  end

  defp do_validate_view(%View{type: :gantt} = view, resource, module) do
    validate_action_exists(view, resource, module)
    candidates = date_attribute_names(resource)

    if is_nil(view.start_field) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :start_field) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :start_field],
        why: "gantt views require `start_field` to be set",
        suggestions: candidates,
        fix: "set `start_field :foo` to a date or datetime attribute on the resource"
      )
    end

    if is_nil(view.end_field) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :end_field) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :end_field],
        why: "gantt views require `end_field` to be set",
        suggestions: candidates,
        fix: "set `end_field :foo` to a date or datetime attribute on the resource"
      )
    end

    validate_nested_views(view, module)
  end

  defp do_validate_view(%View{} = view, resource, module) do
    validate_action_exists(view, resource, module)
    validate_nested_views(view, module)
  end

  defp populate_kanban_from_extension(view, resource) do
    lane = PyroManiac.KanBan.Info.lane!(resource)
    priority = PyroManiac.KanBan.Info.priority!(resource)
    move_action = PyroManiac.KanBan.Info.move_action!(resource)

    %{
      view
      | default_sort: Atom.to_string(priority),
        group_by: lane,
        kanban_action: move_action,
        priority: priority
    }
  end

  defp validate_action_exists(%View{name: names} = view, resource, module) do
    for name <- names do
      resource_action = Resource.Info.action(resource, name)

      if !resource_action do
        suggestions = read_action_suggestions(name, resource)

        Error.raise!(
          module: module,
          location: Entity.anno(view),
          path: [:views, :view, name],
          why: "action #{inspect(name)} not found on resource #{inspect(resource)}",
          suggestions: suggestions
        )
      end

      if resource_action.type != :read do
        Error.raise!(
          module: module,
          location: Entity.anno(view),
          path: [:views, :view, name],
          why:
            "action #{inspect(name)} is type #{inspect(resource_action.type)}, " <>
              "but views require :read actions",
          fix: "pick a read action, or change action #{inspect(name)} to type :read"
        )
      end
    end
  end

  defp validate_no_duplicate_columns(%View{columns: columns} = view, module) do
    case find_duplicate(columns, & &1.name) do
      nil ->
        :ok

      duplicate ->
        Error.raise!(
          module: module,
          location: Entity.anno(duplicate),
          path: [:views, :view, hd(view.name), :column, duplicate.name],
          why: "column #{inspect(duplicate.name)} is already defined"
        )
    end

    case find_duplicate(columns, & &1.label) do
      nil ->
        :ok

      duplicate ->
        Error.raise!(
          module: module,
          location: Entity.property_anno(duplicate, :label) || Entity.anno(duplicate),
          path: [:views, :view, hd(view.name), :column, duplicate.name],
          why: "another column already uses the label #{inspect(duplicate.label)}"
        )
    end
  end

  defp validate_all_columns_valid(%View{columns: columns} = view, resource, module) do
    for %Column{} = column <- columns do
      {name, path} = List.pop_at(column.source, -1)
      source_resource = PyroManiac.Info.resource_by_path(resource, path)
      field = Resource.Info.field(source_resource, name)

      if !field do
        Error.raise!(
          module: module,
          location: Entity.property_anno(column, :source) || Entity.anno(column),
          path: [:views, :view, hd(view.name), :column, column.name],
          why:
            "column #{inspect(column.name)} source #{inspect(path)} -> #{inspect(name)} " <>
              "does not exist on #{inspect(source_resource)}",
          suggestions: source_attr_suggestions(name, source_resource)
        )
      end

      if !field.public? do
        Error.raise!(
          module: module,
          location: Entity.property_anno(column, :source) || Entity.anno(column),
          path: [:views, :view, hd(view.name), :column, column.name],
          why:
            "column #{inspect(column.name)} source #{inspect(path)} -> #{inspect(name)} " <>
              "is not public on #{inspect(source_resource)}",
          fix: "mark the field public on #{inspect(source_resource)}, or pick a different source"
        )
      end
    end
  end

  defp validate_all_public_included(
         %View{columns: columns, exclude: exclude} = view,
         resource,
         module
       ) do
    excluded = MapSet.new(exclude || [])
    location = Entity.anno(view)

    root_defined =
      columns
      |> Enum.reduce(MapSet.new(), fn
        %Column{source: [key]}, acc -> MapSet.put(acc, key)
        _, acc -> acc
      end)

    root = MapSet.union(excluded, root_defined)

    nested_defined =
      columns
      |> Enum.reduce(MapSet.new(), fn
        %Column{source: [head | _]}, acc -> MapSet.put(acc, head)
        _, acc -> acc
      end)

    nested = MapSet.union(excluded, nested_defined)

    for field <- Resource.Info.public_attributes(resource),
        !MapSet.member?(root, field.name) do
      Error.raise!(
        module: module,
        location: location,
        path: [:views, :view, hd(view.name)],
        why: "public attribute #{inspect(field.name)} is not a defined or excluded column",
        fix: "either add `column #{inspect(field.name)}` or list it in `exclude([...])`"
      )
    end

    for field <- Resource.Info.public_calculations(resource),
        !MapSet.member?(root, field.name) do
      Error.raise!(
        module: module,
        location: location,
        path: [:views, :view, hd(view.name)],
        why: "public calculation #{inspect(field.name)} is not a defined or excluded column",
        fix: "either add `column #{inspect(field.name)}` or list it in `exclude([...])`"
      )
    end

    for field <- Resource.Info.public_aggregates(resource),
        !MapSet.member?(root, field.name) do
      Error.raise!(
        module: module,
        location: location,
        path: [:views, :view, hd(view.name)],
        why: "public aggregation #{inspect(field.name)} is not a defined or excluded column",
        fix: "either add `column #{inspect(field.name)}` or list it in `exclude([...])`"
      )
    end

    for field <- Resource.Info.public_relationships(resource),
        !MapSet.member?(nested, field.name) do
      Error.raise!(
        module: module,
        location: location,
        path: [:views, :view, hd(view.name)],
        why: "public relationship #{inspect(field.name)} is not a defined or excluded column",
        fix:
          "either add a column traversing #{inspect(field.name)}, or list it in `exclude([...])`"
      )
    end
  end

  defp validate_default_displays_valid(%View{default_display: nil}, _module), do: :ok

  defp validate_default_displays_valid(%View{default_display: []} = view, module) do
    Error.raise!(
      module: module,
      location: Entity.property_anno(view, :default_display) || Entity.anno(view),
      path: [:views, :view, hd(view.name), :default_display],
      why: "must display at least one column by default",
      fix: "list at least one column name, e.g. `default_display([:name, :status])`"
    )
  end

  defp validate_default_displays_valid(
         %View{columns: columns, default_display: display} = view,
         module
       ) do
    column_names = MapSet.new(columns, & &1.name)
    column_name_list = Enum.map(columns, & &1.name)

    for col <- display, not MapSet.member?(column_names, col) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :default_display) || Entity.anno(view),
        path: [:views, :view, hd(view.name), :default_display],
        why: "#{inspect(col)} is an undefined or excluded column",
        suggestions: Error.did_you_mean(col, column_name_list)
      )
    end
  end

  defp validate_default_sorts_valid(%View{default_sort: nil}, _resource, _module), do: :ok

  defp validate_default_sorts_valid(%View{default_sort: default_sort} = view, resource, module) do
    location = Entity.property_anno(view, :default_sort) || Entity.anno(view)
    columns = MapSet.new(view.columns, &List.wrap(&1.source))

    case Ash.Sort.parse_input(resource, default_sort) do
      {:ok, []} ->
        Error.raise!(
          module: module,
          location: location,
          path: [:views, :view, hd(view.name), :default_sort],
          why: "#{inspect(default_sort)}: must sort on at least one column"
        )

      {:ok, sort} when is_list(sort) ->
        column_source_keys =
          view.columns
          |> Enum.map(&List.wrap(&1.source))
          |> Enum.filter(&match?([_], &1))
          |> Enum.map(&hd/1)

        for sort_key <- flatten_sort(sort), !MapSet.member?(columns, sort_key) do
          raise_unknown_sort_key(sort_key, column_source_keys, view, module, location)
        end

      {:error, error} ->
        Error.raise!(
          module: module,
          location: location,
          path: [:views, :view, hd(view.name), :default_sort],
          why:
            "#{inspect(default_sort)} is an invalid Ash sort.\n\n" <>
              Ash.Error.error_descriptions(error)
        )
    end
  end

  @spec raise_unknown_sort_key(term(), [atom()], View.t(), module(), :erl_anno.anno() | nil) ::
          no_return()
  defp raise_unknown_sort_key(sort_key, column_source_keys, view, module, location) do
    suggestions = sort_key_suggestions(sort_key, column_source_keys)

    Error.raise!(
      module: module,
      location: location,
      path: [:views, :view, hd(view.name), :default_sort],
      why: "key #{inspect(sort_key)} is an undefined or excluded column",
      suggestions: suggestions
    )
  end

  defp sort_key_suggestions([single], candidates),
    do: Error.did_you_mean(single, candidates)

  defp sort_key_suggestions(_, _), do: []

  defp flatten_sort(sort, acc \\ [], path \\ []) do
    Enum.reduce(sort, acc, fn
      {key, nested}, acc when is_list(nested) ->
        flatten_sort(nested, acc, path ++ [key])

      {key, direction}, acc when is_atom(direction) ->
        [path ++ [key] | acc]
    end)
  end

  defp validate_edit_with_valid(%View{columns: columns} = view, resource, module) do
    for %Column{edit_with: edit_with} = column <- columns, not is_nil(edit_with) do
      validate_column_edit_with(column, resource, module, view)
    end
  end

  defp validate_column_edit_with(%{edit_with: type} = column, resource, module, view)
       when is_atom(type) do
    validate_input_type(type, column, module, view)
    validate_has_update_action(resource, nil, column, module, view)
  end

  defp validate_column_edit_with(
         %{edit_with: {action_name, type}} = column,
         resource,
         module,
         view
       ) do
    validate_input_type(type, column, module, view)
    validate_has_update_action(resource, action_name, column, module, view)
  end

  defp validate_column_edit_with(%{edit_with: fun}, _resource, _module, _view)
       when is_function(fun, 1),
       do: :ok

  defp validate_input_type(type, column, module, view) do
    if type not in @valid_edit_with_input_types do
      Error.raise!(
        module: module,
        location: Entity.property_anno(column, :edit_with) || Entity.anno(column),
        path: [:views, :view, hd(view.name), :column, column.name],
        why:
          "edit_with input type #{inspect(type)} is not valid. " <>
            "Must be one of: #{inspect(@valid_edit_with_input_types)}",
        suggestions: Error.did_you_mean(type, @valid_edit_with_input_types)
      )
    end
  end

  defp validate_has_update_action(resource, nil, column, module, view) do
    primary =
      resource
      |> Resource.Info.actions()
      |> Enum.filter(&(&1.type == :update))
      |> Enum.find(& &1.primary?)

    if !primary do
      Error.raise!(
        module: module,
        location: Entity.property_anno(column, :edit_with) || Entity.anno(column),
        path: [:views, :view, hd(view.name), :column, column.name],
        why:
          "edit_with on column #{inspect(column.name)} requires a primary update action, " <>
            "but none exists on resource #{inspect(resource)}",
        fix:
          "add a primary update action to the resource, or specify an explicit action via " <>
            "`edit_with: {:action_name, :input_type}`"
      )
    end

    validate_field_accepted(primary, column, module, view)
  end

  defp validate_has_update_action(resource, action_name, column, module, view) do
    update_action = Resource.Info.action(resource, action_name)

    if !(update_action && update_action.type == :update) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(column, :edit_with) || Entity.anno(column),
        path: [:views, :view, hd(view.name), :column, column.name],
        why:
          "edit_with references action #{inspect(action_name)} which does not exist " <>
            "or is not an update action",
        suggestions: update_action_suggestions(action_name, resource)
      )
    end

    validate_field_accepted(update_action, column, module, view)
  end

  defp validate_field_accepted(update_action, column, module, view) do
    accepted = update_action.accept || []

    if column.name not in accepted do
      Error.raise!(
        module: module,
        location: Entity.property_anno(column, :edit_with) || Entity.anno(column),
        path: [:views, :view, hd(view.name), :column, column.name],
        why:
          "edit_with on column #{inspect(column.name)} but action " <>
            "#{inspect(update_action.name)} does not accept field #{inspect(column.name)}",
        fix:
          "either add #{inspect(column.name)} to the action's `accept` list, " <>
            "or pick an action that accepts it"
      )
    end
  end

  defp validate_realtime_pubsub(%View{} = view, resource, module) do
    has_realtime? =
      view.on_create not in [nil, :none] ||
        view.on_update not in [nil, :none] ||
        view.on_destroy not in [nil, :none]

    if has_realtime? do
      prefix = Ash.Notifier.PubSub.Info.prefix(resource)

      if is_nil(prefix) do
        Error.raise!(
          module: module,
          location: Entity.anno(view),
          path: [:views, :view, hd(view.name)],
          why:
            "view has realtime options (on_create/on_update/on_destroy) but the resource " <>
              "#{inspect(resource)} does not have a pub_sub configuration with a prefix",
          fix: "add a `pub_sub do prefix \"...\" end` block to the resource"
        )
      end

      pubsub_module = Ash.Notifier.PubSub.Info.module(resource)

      if is_nil(pubsub_module) do
        Error.raise!(
          module: module,
          location: Entity.anno(view),
          path: [:views, :view, hd(view.name)],
          why:
            "view has realtime options but the resource #{inspect(resource)} does not " <>
              "have a pub_sub module configured",
          fix: "add `module MyAppWeb.Endpoint` inside the resource's pub_sub block"
        )
      end
    end
  end

  defp validate_nested_views(%View{views: views}, module) when is_list(views) do
    for %View{} = nested <- views, do: validate_nested_view(nested, module)
  end

  defp validate_nested_views(_, _), do: :ok

  defp validate_nested_view(%View{type: :delegated} = view, module),
    do: validate_delegated_view(view, module)

  defp validate_nested_view(%View{delegate_to: delegate_to} = view, module)
       when not is_nil(delegate_to),
       do: validate_non_delegated_view(view, module)

  defp validate_nested_view(%View{name: []} = view, module) do
    Error.raise!(
      module: module,
      location: Entity.anno(view),
      path: [:views, :view],
      why: "non-delegated views require `name` to be set",
      fix: "add an action name like `view :read do ... end`"
    )
  end

  defp validate_nested_view(%View{resource: nil}, _module), do: :ok

  defp validate_nested_view(%View{resource: resource} = view, module),
    do: validate_view(view, resource, module)

  defp find_duplicate(entities, key_fn) do
    result =
      Enum.reduce_while(entities, MapSet.new(), fn entity, seen ->
        key = key_fn.(entity)

        if MapSet.member?(seen, key) do
          {:halt, entity}
        else
          {:cont, MapSet.put(seen, key)}
        end
      end)

    case result do
      %MapSet{} -> nil
      duplicate -> duplicate
    end
  end

  defp date_attribute_names(resource) do
    resource
    |> Resource.Info.public_attributes()
    |> Enum.filter(&date_type?/1)
    |> Enum.map(& &1.name)
  end

  defp date_type?(%{type: type}) do
    type in [
      Ash.Type.Date,
      Ash.Type.DateTime,
      Ash.Type.UtcDatetime,
      Ash.Type.UtcDatetimeUsec,
      Ash.Type.NaiveDatetime
    ]
  end

  defp read_action_suggestions(name, resource) do
    candidates =
      resource
      |> Resource.Info.actions()
      |> Enum.filter(&(&1.type == :read))
      |> Enum.map(& &1.name)

    Error.did_you_mean(name, candidates)
  end

  defp update_action_suggestions(name, resource) do
    candidates =
      resource
      |> Resource.Info.actions()
      |> Enum.filter(&(&1.type == :update))
      |> Enum.map(& &1.name)

    Error.did_you_mean(name, candidates)
  end

  defp source_attr_suggestions(name, source_resource) do
    candidates =
      Enum.map(Resource.Info.public_attributes(source_resource), & &1.name) ++
        Enum.map(Resource.Info.public_calculations(source_resource), & &1.name) ++
        Enum.map(Resource.Info.public_aggregates(source_resource), & &1.name) ++
        Enum.map(Resource.Info.public_relationships(source_resource), & &1.name)

    Error.did_you_mean(name, candidates)
  end
end
