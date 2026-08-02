defmodule PyroManiac.Info do
  @moduledoc """
  Helpers to introspect `PyroManiac` modules. Intended for use in components that automatically build UI from resource configuration.
  """

  alias PyroManiac.Form.{Action, BulkAction, FieldGroup}
  alias PyroManiac.Page.ExtraAction
  alias PyroManiac.Search
  alias PyroManiac.TypeInfer
  alias PyroManiac.View.View

  @spec resource(PyroManiac.t()) :: Ash.Resource.t() | nil
  def resource(pyro_maniac) do
    Spark.Dsl.Extension.get_persisted(pyro_maniac, :resource)
  end

  @spec default_label(PyroManiac.t()) :: atom()
  def default_label(pyro_maniac) do
    pyro_maniac
    |> resource()
    |> PyroManiac.Resource.Info.default_label()
  end

  @doc "Returns the page title."
  @spec title(PyroManiac.t()) :: String.t()
  def title(pyro_maniac) do
    Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :title)
  end

  @doc "Returns the page description (string, render function, or nil)."
  @spec description(PyroManiac.t()) :: String.t() | (map() -> any()) | nil
  def description(pyro_maniac) do
    Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :description, nil)
  end

  @doc "Returns the route path configured for this page, or nil."
  @spec route(PyroManiac.t()) :: String.t() | nil
  def route(pyro_maniac) do
    Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :route, nil)
  end

  @spec default_viewer(PyroManiac.t()) :: atom()
  def default_viewer(pyro_maniac) do
    Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :default_viewer, :data_table)
  end

  @spec track_presence?(PyroManiac.t()) :: boolean()
  def track_presence?(pyro_maniac) do
    Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :track_presence?, false)
  end

  @spec page_extra_actions(PyroManiac.t()) :: [ExtraAction.t()]
  def page_extra_actions(pyro_maniac) do
    pyro_maniac
    |> Spark.Dsl.Extension.get_entities([:page])
    |> Enum.filter(&match?(%ExtraAction{}, &1))
  end

  @doc """
  Returns all top-level view entities.
  """
  @spec views(PyroManiac.t()) :: [View.t()]
  def views(pyro_maniac) do
    pyro_maniac
    |> Spark.Dsl.Extension.get_persisted(:views_by_action_and_type, %{})
    |> Map.values()
    |> Enum.uniq()
  end

  @doc """
  Returns the view for a given `{action_name, type}` pair.
  """
  @spec view_for(PyroManiac.t(), atom(), atom()) :: View.t() | nil
  def view_for(pyro_maniac, action_name, type) do
    pyro_maniac
    |> Spark.Dsl.Extension.get_persisted(:views_by_action_and_type, %{})
    |> Map.get({action_name, type})
  end

  @doc """
  Returns all views of a given type.
  """
  @spec views_of_type(PyroManiac.t(), atom()) :: [View.t()]
  def views_of_type(pyro_maniac, type) do
    pyro_maniac
    |> views()
    |> Enum.filter(&(&1.type == type))
  end

  @doc """
  Returns the primary view for the given type.

  Finds the view matching the primary read action, or `:read`,
  or falls back to the first view of that type.
  """
  @spec primary_view(PyroManiac.t(), atom()) :: View.t() | nil
  def primary_view(pyro_maniac, type) do
    resource = resource(pyro_maniac)

    if resource do
      primary_read = Ash.Resource.Info.primary_action(resource, :read)
      primary_read_name = primary_read && primary_read.name

      view_for(pyro_maniac, primary_read_name, type) ||
        view_for(pyro_maniac, :read, type) ||
        views_of_type(pyro_maniac, type) |> List.first()
    end
  end

  @doc """
  Finds any view that contains the given action name, regardless of type.
  """
  @spec view_for_action(PyroManiac.t(), atom()) :: View.t() | nil
  def view_for_action(pyro_maniac, action_name) do
    pyro_maniac
    |> views()
    |> Enum.find(fn view -> action_name in view.name end)
  end

  @doc """
  Returns the extra actions defined on views.
  """
  @spec view_extra_actions(PyroManiac.t()) :: [ExtraAction.t()]
  def view_extra_actions(pyro_maniac) do
    pyro_maniac
    |> views()
    |> Enum.flat_map(fn view -> view.extra_actions || [] end)
    |> Enum.uniq_by(& &1.name)
  end

  @spec searches(PyroManiac.t()) :: [Search.Search.t()]
  def searches(pyro_maniac) do
    Spark.Dsl.Extension.get_entities(pyro_maniac, [:searches])
  end

  @spec form_for(PyroManiac.t(), atom()) :: Action.t() | nil
  def form_for(pyro_maniac, action_name) do
    pyro_maniac
    |> form_actions()
    |> Enum.find(&(&1.name == action_name))
  end

  @doc """
  Returns a form action by name, scoped to a specific resource.

  When `target_resource` matches the module's primary resource (or is nil),
  returns forms without an explicit `resource` option. Otherwise returns
  forms whose `resource` matches `target_resource`.
  """
  @spec form_for(PyroManiac.t(), atom(), atom()) :: Action.t() | nil
  def form_for(pyro_maniac, action_name, target_resource) do
    pyro_maniac
    |> form_actions_for_resource(target_resource)
    |> Enum.find(&(&1.name == action_name))
  end

  @spec form_actions(PyroManiac.t()) :: [Action.t()]
  def form_actions(pyro_maniac) do
    pyro_maniac
    |> Spark.Dsl.Extension.get_entities([:forms])
    |> Enum.filter(&match?(%Action{}, &1))
  end

  @doc """
  Returns form actions scoped to a specific resource.

  When `target_resource` matches the module's primary resource (or is nil),
  returns forms without an explicit `resource` option. Otherwise returns
  forms whose `resource` matches `target_resource`.
  """
  @spec form_actions_for_resource(PyroManiac.t(), atom()) :: [Action.t()]
  def form_actions_for_resource(pyro_maniac, target_resource) do
    primary = resource(pyro_maniac)

    pyro_maniac
    |> form_actions()
    |> Enum.filter(fn action ->
      if is_nil(target_resource) or target_resource == primary do
        is_nil(action.resource)
      else
        action.resource == target_resource
      end
    end)
  end

  @spec form_for_action_type(PyroManiac.t(), :create | :update) :: map() | nil
  def form_for_action_type(pyro_maniac, action_type) do
    case resource(pyro_maniac) do
      nil ->
        nil

      resource ->
        pyro_maniac
        |> form_actions()
        |> Enum.find(fn action ->
          is_nil(action.resource) &&
            match?(%{type: ^action_type}, Ash.Resource.Info.action(resource, action.name))
        end)
    end
  end

  @doc """
  Returns the first form action matching the given action type, scoped to a specific resource.

  When `target_resource` matches the module's primary resource (or is nil),
  behaves like `form_for_action_type/2`. Otherwise looks up forms with an
  explicit `resource` matching `target_resource`.
  """
  @spec form_for_action_type(PyroManiac.t(), :create | :update, atom()) :: map() | nil
  def form_for_action_type(pyro_maniac, action_type, target_resource) do
    primary = resource(pyro_maniac)

    if is_nil(target_resource) or target_resource == primary do
      form_for_action_type(pyro_maniac, action_type)
    else
      pyro_maniac
      |> form_actions_for_resource(target_resource)
      |> Enum.find(fn action ->
        match?(%{type: ^action_type}, Ash.Resource.Info.action(target_resource, action.name))
      end)
    end
  end

  @spec bulk_actions(PyroManiac.t()) :: [BulkAction.t()]
  def bulk_actions(pyro_maniac) do
    pyro_maniac
    |> Spark.Dsl.Extension.get_entities([:forms])
    |> Enum.filter(&match?(%BulkAction{}, &1))
  end

  @spec bulk_action_for(PyroManiac.t(), atom()) :: BulkAction.t() | nil
  def bulk_action_for(pyro_maniac, action_name) do
    pyro_maniac
    |> bulk_actions()
    |> Enum.find(&(&1.name == action_name))
  end

  @doc """
  Returns the load required for the `default_label` field if it's a calculation or aggregate.

  Attributes are always selected, so they don't need explicit loading.
  Returns a list (empty or single-element) suitable for concatenating with other loads.
  """
  @spec default_label_load(Ash.Resource.t()) :: [atom()]
  def default_label_load(resource) do
    field = PyroManiac.Resource.Info.default_label(resource)

    if field do
      cond do
        Ash.Resource.Info.calculation(resource, field) -> [field]
        Ash.Resource.Info.aggregate(resource, field) -> [field]
        true -> []
      end
    else
      []
    end
  end

  @doc """
  Returns the load required for the `default_label` field if it's a calculation, aggregate, or relationship.

  Returns a list (empty or single-element) suitable for concatenating with other loads.
  """
  @spec default_label_select(Ash.Resource.t()) :: [atom()]
  def default_label_select(resource) do
    field = PyroManiac.Resource.Info.default_label(resource)
    if field, do: [field], else: []
  end

  @doc """
  Returns a human-readable display name for a record using the configured `default_label` field.

  Passes the value through `Presenter.present/2` to ensure proper rendering of
  all value types (dates, decimals, enums, etc.).
  """
  @spec display_name(any(), atom(), any()) :: String.t()
  def display_name(nil, _default_label, _scope), do: ""

  def display_name(record, default_label, scope) do
    record
    |> Map.get(default_label)
    |> PyroManiac.Presenter.present(scope)
  end

  @doc """
  Builds the list of relationship loads required by a form action's field groups.
  """
  @spec loads_for_form(Action.t()) :: [atom() | {atom(), any()}]
  def loads_for_form(%Action{fields: fields}) do
    collect_field_group_loads(fields)
  end

  def loads_for_form(_), do: []

  defp collect_field_group_loads(fields) do
    fields
    |> Enum.flat_map(fn
      %FieldGroup{fields: children, path: [_ | _] = path} ->
        child_loads = collect_field_group_loads(children)
        [nest_load(path, []) | child_loads]

      %FieldGroup{fields: children} ->
        collect_field_group_loads(children)

      _ ->
        []
    end)
  end

  defp nest_load([single], []), do: single
  defp nest_load([single], children), do: {single, children}
  defp nest_load([head | tail], children), do: {head, [nest_load(tail, children)]}

  @doc """
  Builds the list of loads required to render a view.

  Combines:

  * The relationship / calculation / aggregate loads implied by the view's
    columns (`:data_table`), sections (`:grid`), fields, or explicit
    `loads:` (`:render`).
  * The view's `ensure_loaded` load statement, so those fields are always
    loaded regardless of the view's columns, fields, or sections.
  * The resource's `AshStorage` attachment relationships, when the
    optional `AshStorage` extension is loaded and present on the resource —
    so a view that surfaces an attachment badge or count always has the
    underlying relationship populated.
  """
  @spec build_loads_from_view(View.t(), Ash.Resource.t()) :: [atom() | {atom(), any()}]
  def build_loads_from_view(view, resource) do
    view
    |> do_build_loads_from_view(resource)
    |> merge_ensure_loaded(view)
    |> with_attachment_loads(resource)
  end

  defp merge_ensure_loaded(loads, %View{ensure_loaded: [_ | _] = ensure_loaded}) do
    Enum.uniq(loads ++ ensure_loaded)
  end

  defp merge_ensure_loaded(loads, _view), do: loads

  defp do_build_loads_from_view(%View{columns: columns, type: :data_table}, resource) do
    build_loads_from_columns(columns, resource)
  end

  defp do_build_loads_from_view(%View{sections: sections, type: :grid}, resource) do
    build_loads_from_sections(sections, resource)
  end

  defp do_build_loads_from_view(%View{loads: loads, type: :render}, _resource) do
    List.wrap(loads)
  end

  defp do_build_loads_from_view(%View{fields: fields}, resource) when is_list(fields) do
    fields
    |> Enum.flat_map(fn field ->
      build_load_for_path(field.source, resource)
    end)
    |> Enum.uniq()
  end

  defp do_build_loads_from_view(_, _), do: []

  # Append the resource's attachment relationships when AshStorage is in use.
  # Soft dependency: when AshStorage isn't compiled in, this is a no-op.
  defp with_attachment_loads(loads, resource) do
    loads = List.wrap(loads)

    if Code.ensure_loaded?(AshStorage) and Code.ensure_loaded?(AshStorage.Info) and
         AshStorage in Spark.extensions(resource) do
      extras =
        resource
        |> AshStorage.Info.attachments()
        |> Enum.map(& &1.name)
        |> Enum.reject(&(&1 in loads))

      loads ++ extras
    else
      loads
    end
  rescue
    _ -> List.wrap(loads)
  end

  @spec build_loads_from_columns([map()] | map(), Ash.Resource.t()) :: [atom() | {atom(), any()}]
  def build_loads_from_columns(columns, resource) when is_map(columns) do
    columns
    |> Map.values()
    |> build_loads_from_columns(resource)
  end

  def build_loads_from_columns(columns, resource) when is_list(columns) do
    columns
    |> Enum.flat_map(fn col ->
      field_path = column_field_path(col)
      build_load_for_path(field_path, resource)
    end)
    |> Enum.uniq()
  end

  defp build_loads_from_sections(sections, resource) do
    sections
    |> Enum.flat_map(fn section ->
      field_loads =
        (section.fields || [])
        |> Enum.flat_map(fn field ->
          build_load_for_path(field.source, resource)
        end)

      rel_loads =
        (section.relationships || [])
        |> Enum.flat_map(&build_rel_load(&1, resource))

      field_loads ++ rel_loads
    end)
    |> Enum.uniq()
  end

  defp build_rel_load(%{fields: fields} = rel, _resource) when fields in [nil, []] do
    [rel.name]
  end

  defp build_rel_load(rel, resource) do
    nested_resource =
      case Ash.Resource.Info.relationship(resource, rel.name) do
        nil -> nil
        r -> r.destination
      end

    nested_loads =
      if nested_resource do
        Enum.flat_map(rel.fields, &build_load_for_path(&1.source, nested_resource))
      else
        []
      end

    case nested_loads do
      [] -> [rel.name]
      loads -> [{rel.name, loads}]
    end
  end

  @spec column_field_path(map() | {atom(), map()}) :: [atom()]
  def column_field_path({_name, col}) when is_map(col), do: column_field_path(col)

  def column_field_path(%{source: source}) when is_list(source),
    do: Enum.map(source, &ensure_atom/1)

  def column_field_path(%{name: name}) when is_atom(name), do: [name]
  def column_field_path(%{name: name}) when is_list(name), do: Enum.map(name, &ensure_atom/1)
  def column_field_path(%{field: field}) when is_atom(field), do: [field]
  def column_field_path(%{field: field}) when is_list(field), do: Enum.map(field, &ensure_atom/1)
  def column_field_path(%{field_atoms: atoms}) when is_list(atoms), do: atoms
  def column_field_path(_), do: []

  defp ensure_atom(a) when is_atom(a), do: a
  defp ensure_atom(s) when is_binary(s), do: String.to_existing_atom(s)

  @doc """
  Builds the load list for nested views within a parent view.
  Non-autonomous views (with relationship) contribute their relationship name.
  Autonomous/paginated nested views fetch their own data.
  """
  @spec nested_view_loads(View.t()) :: [atom() | {atom(), any()}]
  def nested_view_loads(%View{views: views}) when is_list(views) do
    Enum.flat_map(views, fn
      # Delegated views are fully autonomous — they load their own data
      %View{type: :delegated} ->
        []

      # Autonomous paginated views fetch their own data
      %View{pagination: pagination, relationship: rel}
      when not is_nil(rel) and pagination != :none ->
        []

      # Non-autonomous relationship views need their data loaded
      %View{relationship: rel} when not is_nil(rel) ->
        [rel]

      # Cross-resource views fetch their own data
      _ ->
        []
    end)
  end

  def nested_view_loads(_), do: []

  defp build_load_for_path([single], resource) do
    cond do
      Ash.Resource.Info.calculation(resource, single) -> [single]
      Ash.Resource.Info.aggregate(resource, single) -> [single]
      Ash.Resource.Info.relationship(resource, single) -> [single]
      true -> []
    end
  end

  defp build_load_for_path([first | rest], resource) do
    if Ash.Resource.Info.relationship(resource, first) do
      [build_nested_load(first, rest)]
    else
      []
    end
  end

  defp build_load_for_path([], _resource), do: []

  defp build_nested_load(field, []), do: field
  defp build_nested_load(field, [next | rest]), do: {field, build_nested_load(next, rest)}

  @doc """
  Resolve the input type for a resource field.

  Looks up the attribute or argument on the resource and infers the appropriate
  form input type. When `override_type` is `:default` or `nil`, the type is
  inferred from the Ash attribute. Otherwise the override is returned directly
  (with `:checkbox` promoted to `:checkbox_group` for array enums).
  """
  @spec resolve_field_type(Ash.Resource.t(), atom(), atom()) :: atom()
  def resolve_field_type(resource, field_name, override_type \\ :default)

  def resolve_field_type(resource, field_name, type) when type in [:default, nil] do
    case field_info(resource, field_name) do
      nil -> :text
      attr_info -> TypeInfer.infer_input_type(nil, attr_info)
    end
  end

  def resolve_field_type(resource, field_name, :checkbox) do
    case field_info(resource, field_name) do
      nil -> :checkbox
      attr_info -> if TypeInfer.array_enum_type?(attr_info), do: :checkbox_group, else: :checkbox
    end
  end

  def resolve_field_type(_resource, _field_name, type), do: type

  @doc """
  Get enum options for a resource field (Ash enums + one_of constraints).

  Returns a list of `{label, value}` tuples, or `nil` if the field is not an enum.
  """
  @spec enum_options_for(Ash.Resource.t(), atom()) :: [{String.t(), atom()}] | nil
  def enum_options_for(resource, field_name) do
    case field_info(resource, field_name) do
      nil -> nil
      attr_info -> TypeInfer.enum_options(attr_info.type, Map.get(attr_info, :constraints, []))
    end
  end

  @doc """
  Get attribute or argument info for a field on a resource.

  Checks attributes first, then falls back to all action arguments.
  """
  @spec field_info(Ash.Resource.t(), atom()) :: map() | nil
  def field_info(resource, field_name) do
    case Ash.Resource.Info.attribute(resource, field_name) do
      %{} = attr -> attr
      nil -> find_argument(resource, field_name)
    end
  end

  @doc """
  Get attribute or argument info for a field on a specific action.
  """
  @spec action_field_info(Ash.Resource.t(), atom(), atom()) :: map() | nil
  def action_field_info(resource, action_name, field_name) do
    case Ash.Resource.Info.attribute(resource, field_name) do
      %{} = attr ->
        attr

      nil ->
        case Ash.Resource.Info.action(resource, action_name) do
          %{arguments: args} -> Enum.find(args, &(&1.name == field_name))
          _ -> nil
        end
    end
  end

  @doc "Whether the field allows nil."
  @spec field_allow_nil?(Ash.Resource.t(), atom()) :: boolean()
  def field_allow_nil?(resource, field_name) do
    case field_info(resource, field_name) do
      nil -> true
      info -> Map.get(info, :allow_nil?, true)
    end
  end

  @doc "Humanized label for a field."
  @spec field_label(atom() | String.t()) :: String.t()
  def field_label(field_name) when is_atom(field_name) do
    field_name |> Atom.to_string() |> field_label()
  end

  def field_label(field_name) when is_binary(field_name) do
    field_name
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp find_argument(resource, field_name) do
    resource
    |> Ash.Resource.Info.actions()
    |> Enum.find_value(fn action ->
      Enum.find(action.arguments || [], &(&1.name == field_name))
    end)
  end

  @spec resource_by_path(Ash.Resource.t(), [atom() | binary()]) :: Ash.Resource.t()
  def resource_by_path(resource, []), do: resource

  def resource_by_path(resource, [relationship | rest]) do
    case Ash.Resource.Info.field(resource, relationship) do
      nil ->
        raise ArgumentError,
              "field #{inspect(relationship)} not found on #{inspect(resource)} " <>
                "while resolving path #{inspect([relationship | rest])}"

      %Ash.Resource.Aggregate{} ->
        resource

      %Ash.Resource.Calculation{} ->
        resource

      %Ash.Resource.Attribute{} ->
        resource

      %Ash.Resource.Relationships.BelongsTo{destination: destination} ->
        resource_by_path(destination, rest)

      %Ash.Resource.Relationships.HasOne{destination: destination} ->
        resource_by_path(destination, rest)

      %Ash.Resource.Relationships.HasMany{destination: destination} ->
        resource_by_path(destination, rest)

      %Ash.Resource.Relationships.ManyToMany{destination: destination} ->
        resource_by_path(destination, rest)
    end
  end
end
