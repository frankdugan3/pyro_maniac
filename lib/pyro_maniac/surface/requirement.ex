defmodule PyroManiac.Surface.Requirement do
  @moduledoc """
  What a part of a page needs from the surface of a resource: an action, and
  the paths that it loads, filters on, and sorts on.

  `requirements/4` gives the requirements of a page from its compiled
  entities. The page verifier compares them with the surface. A migration
  can use them to write the surface.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Form.{Action, BulkAction, Combobox, Tree}
  alias PyroManiac.Surface
  alias PyroManiac.View.View

  defstruct [:resource, :action, :origin, :location, loads: [], filter: [], sort: []]

  @type t :: %__MODULE__{
          resource: Ash.Resource.t(),
          action: atom(),
          origin: [atom()],
          location: :erl_anno.anno() | nil,
          loads: [Surface.path()],
          filter: [Surface.path()],
          sort: [Surface.path()]
        }

  @doc """
  The requirements of a page: its resource, and its views, forms (actions and
  bulk actions), and searches, after the transformers. Delegated views and
  delegated forms are not included: the delegate module has its own
  requirements.
  """
  @spec requirements(Ash.Resource.t(), [struct()], [struct()], [struct()]) :: [t()]
  def requirements(resource, views, forms, searches) do
    search_paths = Enum.flat_map(searches, &search_paths/1)

    view_requirements =
      Enum.flat_map(views, fn
        %View{} = view -> view_requirements(view, resource, nil, search_paths)
        _ -> []
      end)

    form_requirements = Enum.flat_map(forms, &form_requirements(&1, resource))

    view_requirements ++ form_requirements
  end

  @doc """
  Merges the requirements of the same resource and action: one requirement
  for each, with all the paths.
  """
  @spec merge([t()]) :: [t()]
  def merge(requirements) do
    requirements
    |> Enum.group_by(&{&1.resource, &1.action})
    |> Enum.map(fn {_key, [first | _] = group} ->
      %{
        first
        | loads: group |> Enum.flat_map(& &1.loads) |> Enum.uniq(),
          filter: group |> Enum.flat_map(& &1.filter) |> Enum.uniq(),
          sort: group |> Enum.flat_map(& &1.sort) |> Enum.uniq()
      }
    end)
  end

  @doc "The read actions that a view uses."
  @spec view_actions(View.t(), Ash.Resource.t() | nil) :: [atom()]
  def view_actions(%View{read_action: read_action}, _parent) when not is_nil(read_action),
    do: [read_action]

  def view_actions(%View{relationship: rel, resource: resource} = view, parent)
      when not is_nil(rel) and not is_nil(parent) do
    case Ash.Resource.Info.relationship(parent, rel) do
      %{read_action: read_action, destination: ^resource} when not is_nil(read_action) ->
        [read_action]

      _ ->
        List.wrap(view.name)
    end
  end

  def view_actions(%View{name: names}, _parent), do: List.wrap(names)

  # Views -----------------------------------------------------------------

  defp view_requirements(%View{type: :delegated}, _resource, _parent, _search_paths), do: []

  defp view_requirements(%View{} = view, page_resource, parent, search_paths) do
    resource = view.resource || page_resource
    origin = [:views, :view | List.wrap(List.first(List.wrap(view.name)))]
    location = Spark.Dsl.Entity.anno(view)

    # A nested `:render` view without a relationship renders the row of this
    # view: it has no read, and its loads are loads of this view.
    {row_renders, nested} = Enum.split_with(view.views || [], &row_render?/1)

    loads =
      (view_loads(view, resource) ++ Enum.flat_map(row_renders, &Surface.paths(&1.loads)))
      |> Enum.uniq()

    filter = view_filter(view, resource) ++ if(is_nil(parent), do: search_paths, else: [])
    sort = view_sort(view, resource)

    reads =
      if row_render?(view) and not is_nil(parent) do
        []
      else
        for action <- view_actions(view, parent) do
          %__MODULE__{
            resource: resource,
            action: action,
            origin: origin,
            location: location,
            loads: loads,
            filter: Enum.uniq(filter),
            sort: sort
          }
        end
      end

    reads ++
      edit_requirements(view, resource, origin) ++
      kanban_requirements(view, resource, origin, location) ++
      Enum.flat_map(nested, &view_requirements(&1, page_resource, resource, []))
  end

  @doc "Whether a view is a nested `:render` view of the row of its parent (no relationship)."
  @spec row_render?(View.t()) :: boolean()
  def row_render?(%View{type: :render, relationship: nil}), do: true
  def row_render?(_view), do: false

  @special_fields [
    :date_field,
    :end_date_field,
    :start_field,
    :end_field,
    :progress_field,
    :parent_field,
    :group_by,
    :priority
  ]

  defp view_loads(view, resource) do
    (source_paths(view, resource) ++
       tone_paths(view) ++
       for(field <- @special_fields, name = Map.get(view, field), do: [name]) ++
       render_paths(view) ++
       Surface.paths(PyroManiac.Info.nested_view_loads(view)) ++
       Surface.paths(view.ensure_loaded) ++
       label_paths(resource) ++ attachment_paths(resource))
    |> Enum.reject(&(&1 == []))
    |> Enum.uniq()
  end

  # The sources of the columns, the fields, and the sections of a view.
  defp source_paths(view, resource) do
    Enum.map(view.columns || [], &List.wrap(&1.source)) ++
      Enum.map(view.fields || [], &List.wrap(&1.source)) ++
      Enum.flat_map(view.sections || [], fn section ->
        Enum.map(section.fields || [], &List.wrap(&1.source)) ++
          Enum.flat_map(section.relationships || [], &section_relationship_paths(&1, resource))
      end)
  end

  # The fields that the `tone` expressions of a view refer to.
  defp tone_paths(view) do
    ((view.columns || []) ++
       (view.fields || []) ++ Enum.flat_map(view.sections || [], &(&1.fields || [])))
    |> Enum.flat_map(&(Map.get(&1, :__tone_refs__) || []))
    |> Enum.map(&[&1])
  end

  defp render_paths(%View{type: :render, loads: loads}), do: Surface.paths(loads)
  defp render_paths(_view), do: []

  defp section_relationship_paths(%{name: name, fields: fields}, resource)
       when fields in [nil, []] do
    destination = destination(resource, name)
    [[name] | Enum.map(label_paths(destination), &[name | &1])]
  end

  defp section_relationship_paths(%{name: name, fields: fields}, _resource) do
    Enum.map(fields, &[name | List.wrap(&1.source)])
  end

  # A column on a field that Ash cannot filter (`filterable? false`) or sort
  # (`sortable? false`) has no filter or sort: the renderer turns it off.
  defp view_filter(%View{type: :data_table, columns: columns}, resource) do
    for column <- columns || [],
        column.filterable?,
        path = List.wrap(column.source),
        usable_path?(resource, path, :filter),
        do: path
  end

  defp view_filter(_view, _resource), do: []

  defp view_sort(%View{} = view, resource) do
    column_sort =
      for column <- view.columns || [],
          column.sortable? or column.keyset_sortable?,
          view.type == :data_table,
          path = List.wrap(column.source),
          usable_path?(resource, path, :sort),
          do: path

    Enum.uniq(column_sort ++ default_sort_paths(view.default_sort, resource))
  end

  defp usable_path?(resource, [name], option) do
    case Ash.Resource.Info.field(resource, name) do
      nil -> true
      field -> PyroManiac.Resource.Info.usable?(field, option)
    end
  end

  defp usable_path?(resource, [name | rest], option) do
    case Ash.Resource.Info.relationship(resource, name) do
      %{destination: destination} -> usable_path?(destination, rest, option)
      nil -> true
    end
  end

  defp usable_path?(_resource, [], _option), do: true

  @doc false
  def default_sort_paths(nil, _resource), do: []

  def default_sort_paths(sort, resource) do
    case Ash.Sort.parse_input(resource, sort) do
      {:ok, sort} when is_list(sort) -> Enum.flat_map(sort, &sort_paths(&1, []))
      _ -> []
    end
  end

  defp sort_paths({key, nested}, path) when is_list(nested),
    do: Enum.flat_map(nested, &sort_paths(&1, path ++ [key]))

  defp sort_paths({key, _direction}, path) when is_atom(key), do: [path ++ [key]]
  defp sort_paths({%{name: name}, _direction}, path), do: [path ++ [name]]
  defp sort_paths(key, path) when is_atom(key), do: [path ++ [key]]
  defp sort_paths(_other, _path), do: []

  defp edit_requirements(view, resource, origin) do
    for column <- view.columns || [],
        not is_nil(column.edit_with),
        action = edit_action(column.edit_with, resource),
        not is_nil(action) do
      %__MODULE__{
        resource: resource,
        action: action,
        origin: origin ++ [:column, column.name, :edit_with],
        location: Spark.Dsl.Entity.anno(column)
      }
    end
  end

  defp edit_action({action, _type}, _resource), do: action

  defp edit_action(_type, resource) do
    case Ash.Resource.Info.primary_action(resource, :update) do
      nil -> nil
      action -> action.name
    end
  end

  defp kanban_requirements(%View{type: :kanban} = view, resource, origin, location) do
    move =
      view.kanban_action ||
        (PyroManiac.KanBan.Info.has_kanban?(resource) &&
           PyroManiac.KanBan.Info.move_action!(resource))

    if move do
      [%__MODULE__{resource: resource, action: move, origin: origin, location: location}]
    else
      []
    end
  end

  defp kanban_requirements(_view, _resource, _origin, _location), do: []

  defp search_paths(search) do
    for field <- search.fields || [],
        source <- List.wrap(field.source) do
      List.wrap(source)
    end
  end

  # Forms -----------------------------------------------------------------

  defp form_requirements(%Action{delegate_to: delegate}, _resource) when not is_nil(delegate),
    do: []

  defp form_requirements(%Action{} = action, page_resource) do
    resource = action.resource || page_resource
    origin = [:forms, :action, action.name]

    [
      %__MODULE__{
        resource: resource,
        action: action.name,
        origin: origin,
        location: Spark.Dsl.Entity.anno(action),
        loads: action |> PyroManiac.Info.loads_for_form() |> Surface.paths()
      }
      | combobox_requirements(action, origin)
    ]
  end

  defp form_requirements(%BulkAction{delegate_to: delegate}, _resource)
       when not is_nil(delegate),
       do: []

  defp form_requirements(%BulkAction{} = bulk_action, page_resource) do
    origin = [:forms, :bulk_action, bulk_action.name]

    [
      %__MODULE__{
        resource: page_resource,
        action: bulk_action.name,
        origin: origin,
        location: Spark.Dsl.Entity.anno(bulk_action)
      }
      | combobox_requirements(bulk_action, origin)
    ]
  end

  defp form_requirements(_entity, _resource), do: []

  defp combobox_requirements(container, origin) do
    for %Combobox{} = combobox <- Tree.inputs(container.fields),
        not is_nil(combobox.__resource__),
        not is_nil(combobox.read_action) do
      %__MODULE__{
        resource: combobox.__resource__,
        action: combobox.read_action,
        origin: origin ++ [:combobox, combobox.name],
        location: Spark.Dsl.Entity.anno(combobox),
        loads:
          [combobox.label_key, combobox.value_key]
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Enum.map(&[&1]),
        filter:
          case combobox.search do
            list when is_list(list) -> Enum.map(list, &[&1])
            _ -> []
          end,
        sort: Enum.map(combobox.sort || [], fn {key, _direction} -> [key] end)
      }
    end
  end

  # Helpers ---------------------------------------------------------------

  defp label_paths(nil), do: []

  defp label_paths(resource) do
    case PyroManiac.Resource.Info.default_label(resource) do
      nil -> []
      label -> [[label]]
    end
  rescue
    _ -> []
  end

  defp destination(resource, name) do
    case Ash.Resource.Info.relationship(resource, name) do
      %{destination: destination} -> destination
      _ -> nil
    end
  end

  defp attachment_paths(resource) do
    if Code.ensure_loaded?(AshStorage) and Code.ensure_loaded?(AshStorage.Info) and
         AshStorage in Spark.extensions(resource) do
      resource |> AshStorage.Info.attachments() |> Enum.map(&[&1.name])
    else
      []
    end
  rescue
    _ -> []
  end
end
