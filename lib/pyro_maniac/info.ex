defmodule PyroManiac.Info do
  @moduledoc """
  Helpers to introspect `PyroManiac` modules. Intended for use in components that automatically build UI from resource configuration.
  """

  alias PyroManiac.Form.{Action, BulkAction, Tree}
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

  @doc """
  The page title: `title`, else the plural name of the resource (or its
  short name), humanized.
  """
  @spec title(PyroManiac.t()) :: String.t() | nil
  def title(pyro_maniac) do
    case Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :title) do
      nil -> default_title(resource(pyro_maniac))
      title -> title
    end
  end

  defp default_title(nil), do: nil

  defp default_title(resource) do
    name = Ash.Resource.Info.plural_name(resource) || Ash.Resource.Info.short_name(resource)
    PyroManiac.Dsl.Transformers.default_label(name)
  end

  @doc """
  The description of the page: its `description` entities (a text, and
  implementations for some renderers). Refer to
  `PyroManiac.Content.resolve/2`.
  """
  @spec description(PyroManiac.t()) :: [PyroManiac.Description.t()]
  def description(pyro_maniac) do
    pyro_maniac
    |> Spark.Dsl.Extension.get_entities([:page])
    |> Enum.filter(&is_struct(&1, PyroManiac.Description))
  end

  @doc """
  The module is a page: it has a `page` section, with a `route`. A module
  without it declares views and searches that the pages reuse.
  """
  @spec page?(module()) :: boolean()
  def page?(module) do
    Spark.Dsl.is?(module, PyroManiac) and
      Spark.Dsl.Extension.get_persisted(module, :page?, false)
  end

  @doc "The route of the page (`page do route ... end`), or nil if the module is not a page."
  @spec route(PyroManiac.t()) :: String.t() | nil
  def route(pyro_maniac) do
    Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :route, nil)
  end

  @doc """
  The width of the views of the page (`PyroManiac.Dsl.Type.width/0`):
  `width` of the `page` section, else `:full`.
  """
  @spec width(PyroManiac.t()) :: atom()
  def width(pyro_maniac),
    do: Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :width, :full)

  @doc """
  The width of a view of the page: the `width` of the view, else `:record`
  for a `:card` that opens in a modal or a drawer (the width of the modal or
  the drawer), else the width of the page (`width/1`).
  """
  @spec view_width(PyroManiac.t(), View.t()) :: atom()
  def view_width(_pyro_maniac, %View{width: width}) when not is_nil(width), do: width

  def view_width(_pyro_maniac, %View{type: :card, presentation: presentation})
      when presentation in [:modal, :drawer],
      do: :record

  def view_width(pyro_maniac, %View{}), do: width(pyro_maniac)

  @doc """
  The width of the dialog of an action (its own tree, a modal or a drawer):
  the `width` of the action, else `:record`.
  """
  @spec action_width(PyroManiac.Form.Action.t()) :: atom()
  def action_width(%PyroManiac.Form.Action{width: nil}), do: :record
  def action_width(%PyroManiac.Form.Action{width: width}), do: width

  @doc "Whether the user builds filters (the advanced filter view)."
  @spec custom_filters?(PyroManiac.t()) :: boolean()
  def custom_filters?(pyro_maniac),
    do: Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :custom_filters?, false)

  @doc """
  Where the filters that a user builds are saved: `:client`, a resource with
  `PyroManiac.FilterPresets`, or `nil`.
  """
  @spec filter_storage(PyroManiac.t()) :: :client | module() | nil
  def filter_storage(pyro_maniac),
    do: Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :filter_storage, nil)

  @doc "Whether a user can share a saved filter."
  @spec shared_filters?(PyroManiac.t()) :: boolean()
  def shared_filters?(pyro_maniac),
    do: Spark.Dsl.Extension.get_opt(pyro_maniac, [:page], :shared_filters?, false)

  @doc """
  The decorations that the DSL accepts: `config :pyro_maniac, decorations:
  [...]` (compile time), else `default_decorations/0`. A renderer maps each
  one to a style.
  """
  @spec decorations() :: [atom()]
  def decorations, do: PyroManiac.Dsl.Type.decorations()

  @doc "The default decorations: `[:neutral, :info, :success, :warning, :danger]`."
  @spec default_decorations() :: [atom()]
  def default_decorations, do: PyroManiac.Dsl.Type.default_decorations()

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
  Returns all top-level view entities, in the order of the DSL.
  """
  @spec views(PyroManiac.t()) :: [View.t()]
  def views(pyro_maniac) do
    Spark.Dsl.Extension.get_persisted(pyro_maniac, :views, [])
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
  The primary single view of a page (a `:card`): the view of one record
  that a link to the page opens. Refer to `PyroManiac.Card`.
  """
  @spec primary_single_view(PyroManiac.t()) :: View.t() | nil
  def primary_single_view(pyro_maniac) do
    Spark.Dsl.Extension.get_persisted(pyro_maniac, :__primary_single_view__, nil)
  end

  @doc """
  The primary list view of a page: its primary list-only view, else its
  primary single view (a `:card` shows one card for each record).
  """
  @spec primary_list_view(PyroManiac.t()) :: View.t() | nil
  def primary_list_view(pyro_maniac) do
    Spark.Dsl.Extension.get_persisted(pyro_maniac, :__primary_list_view__, nil)
  end

  @doc """
  The single views (`:card`) or the list views of a page whose name has
  `name`. `kind` is `:single` or `:list`.
  """
  @spec named_views(PyroManiac.t(), :single | :list, atom()) :: [View.t()]
  def named_views(pyro_maniac, kind, name) do
    types = if kind == :single, do: View.single_types(), else: View.list_types()

    pyro_maniac
    |> views()
    |> Enum.filter(&(&1.type in types and name in &1.name))
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

  @doc """
  The first action entity of a page with the name `action_name` (refer to
  `actions/1`): the action of a card first.
  """
  @spec action_for(PyroManiac.t(), atom()) :: Action.t() | nil
  def action_for(pyro_maniac, action_name) do
    pyro_maniac
    |> actions()
    |> Enum.find(&(&1.name == action_name))
  end

  @doc """
  The first action entity of a page with the name `action_name`, scoped to
  a resource (refer to `actions_for_resource/2`).
  """
  @spec action_for(PyroManiac.t(), atom(), atom()) :: Action.t() | nil
  def action_for(pyro_maniac, action_name, target_resource) do
    pyro_maniac
    |> actions_for_resource(target_resource)
    |> Enum.find(&(&1.name == action_name))
  end

  @doc """
  The actions of the views of a page (`action`, the `action` of a column,
  `edit_columns`), each with its expanded form: one entity for each action
  name and view (`__view__`), the actions of the cards first.
  """
  @spec actions(PyroManiac.t()) :: [Action.t()]
  def actions(pyro_maniac) do
    pyro_maniac
    |> Spark.Dsl.Extension.get_entities([:forms])
    |> Enum.filter(&match?(%Action{}, &1))
    |> Enum.sort_by(&if(match?({_, :card}, &1.__view__), do: 0, else: 1))
  end

  @doc "The actions of one view of a page (refer to `actions/1`)."
  @spec actions(PyroManiac.t(), View.t()) :: [Action.t()]
  def actions(pyro_maniac, %View{} = view) do
    key = {List.first(view.name), view.type}
    pyro_maniac |> actions() |> Enum.filter(&(&1.__view__ == key))
  end

  @doc """
  The action entities of a page scoped to a resource.

  When `target_resource` is the resource of the page (or `nil`), the
  actions without a `resource` option. Otherwise the actions whose
  `resource` is `target_resource` (the cross-resource actions).
  """
  @spec actions_for_resource(PyroManiac.t(), atom()) :: [Action.t()]
  def actions_for_resource(pyro_maniac, target_resource) do
    primary = resource(pyro_maniac)

    pyro_maniac
    |> actions()
    |> Enum.filter(fn action ->
      if is_nil(target_resource) or target_resource == primary do
        is_nil(action.resource)
      else
        action.resource == target_resource
      end
    end)
  end

  @doc """
  The first action entity of a page on its resource whose Ash action has
  the type `action_type` (`:create` or `:update`).
  """
  @spec action_for_type(PyroManiac.t(), :create | :update) :: map() | nil
  def action_for_type(pyro_maniac, action_type) do
    case resource(pyro_maniac) do
      nil ->
        nil

      resource ->
        pyro_maniac
        |> actions()
        |> Enum.find(fn action ->
          is_nil(action.resource) &&
            match?(%{type: ^action_type}, Ash.Resource.Info.action(resource, action.name))
        end)
    end
  end

  @doc """
  The first action entity of a page whose Ash action has the type
  `action_type`, scoped to a resource.

  When `target_resource` is the resource of the page (or `nil`), the same
  as `action_for_type/2`. Otherwise the actions whose `resource` is
  `target_resource`.
  """
  @spec action_for_type(PyroManiac.t(), :create | :update, atom()) :: map() | nil
  def action_for_type(pyro_maniac, action_type, target_resource) do
    primary = resource(pyro_maniac)

    if is_nil(target_resource) or target_resource == primary do
      action_for_type(pyro_maniac, action_type)
    else
      pyro_maniac
      |> actions_for_resource(target_resource)
      |> Enum.find(fn action ->
        match?(%{type: ^action_type}, Ash.Resource.Info.action(target_resource, action.name))
      end)
    end
  end

  @doc """
  The bulk actions of the list views of a page, each with its view
  (`__view__`).
  """
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
  Builds the list of relationship loads required by the nested forms of an
  action: each distinct full path of a section, a step, or an input.
  """
  @spec loads_for_form(Action.t()) :: [atom() | {atom(), any()}]
  def loads_for_form(%Action{fields: fields}) do
    fields
    |> Tree.all()
    |> Enum.map(&(Map.get(&1, :__full_path__) || []))
    |> Enum.reject(&(&1 == []))
    |> Enum.uniq()
    |> Enum.map(&nest_load(&1, []))
  end

  def loads_for_form(_), do: []

  @doc """
  All inputs of the form of an action (`field`, `combobox`, `select`,
  `input`), in DSL order, through each section, tab, step, row, and
  compound.
  """
  @spec form_fields(Action.t() | BulkAction.t()) :: [struct()]
  def form_fields(%{fields: fields}), do: Tree.inputs(fields)

  @doc """
  The layout of the form of an action as a plain tree of maps, for renderers that
  are not in Elixir (for example AshTypescript extensions). It has no
  functions and no structs, so it encodes as JSON. For `visible?`, a node has
  `depends_on` (the attributes and arguments that the expression refers
  to, and `%{parent: name}` for a `parent(name)` reference); the server
  evaluates the expression.
  """
  @spec form_layout(Action.t() | BulkAction.t()) :: map()
  def form_layout(%{fields: fields} = action) do
    %{
      kind: :form,
      name: action.name,
      label: action.label,
      max_columns: action.max_columns,
      children: Enum.map(fields, &layout_node/1)
    }
  end

  defp layout_dependency({:parent, name}), do: %{parent: name}
  defp layout_dependency(name), do: name

  defp layout_node(%module{} = entity) do
    kind =
      module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.to_existing_atom()

    base = %{
      kind: kind,
      path: Map.get(entity, :__full_path__, []),
      depends_on: entity |> Map.get(:__depends_on__, []) |> Enum.map(&layout_dependency/1),
      conditional?: Map.get(entity, :visible?) != nil
    }

    layout =
      entity
      |> Map.take([
        :name,
        :label,
        :description,
        :size,
        :type,
        :density,
        :max_columns,
        :collapsible?,
        :collapsed?,
        :show_labels?,
        :autofocus,
        :prompt,
        :only,
        :count,
        :presentation,
        :limit,
        :empty_text,
        :delegate_to
      ])
      |> Map.reject(fn {_key, value} -> is_function(value) end)

    extra = entity |> layout_required() |> Map.merge(layout_extra(entity))

    children =
      if Tree.container?(entity),
        do: %{children: Enum.map(Tree.children(entity), &layout_node/1)},
        else: %{}

    base |> Map.merge(layout) |> Map.merge(extra) |> Map.merge(children)
  end

  defp layout_required(%{"__read_only?__": true}), do: %{}
  defp layout_required(%{"__allow_nil?__": allow_nil?}), do: %{required?: not allow_nil?}
  defp layout_required(_entity), do: %{}

  defp layout_extra(entity) do
    [:options, :read_only?, :relationship, :link_to, :decoration, :fields]
    |> Enum.reduce(%{}, fn key, acc ->
      case layout_value(key, entity) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp layout_value(:options, %{__enum_options__: [_ | _] = options}), do: options
  defp layout_value(:read_only?, %{"__read_only?__": true}), do: true
  defp layout_value(:relationship, %{__relationship__: relationship}), do: relationship

  defp layout_value(:link_to, %{link_to: [_ | _] = links}),
    do: Enum.map(links, &Map.take(&1, [:page, :single_view, :list_view]))

  defp layout_value(:decoration, %{decoration: decoration}) when is_atom(decoration),
    do: decoration

  defp layout_value(:fields, %PyroManiac.Form.Related{fields: [_ | _] = fields}),
    do: Enum.map(fields, &%{name: &1.name, label: &1.label, source: &1.source})

  defp layout_value(_key, _entity), do: nil

  defp nest_load([single], []), do: single
  defp nest_load([single], children), do: {single, children}
  defp nest_load([head | tail], children), do: {head, [nest_load(tail, children)]}

  @doc """
  Builds the list of loads required to render a view.

  Combines:

  * The relationship / calculation / aggregate loads implied by the view's
    columns (`:data_table`), record tree (the other types), or explicit
    `loads:` (`:render`).
  * The view's `ensure_loaded` load statement, so those fields are always
    loaded regardless of the view's columns or record tree.
  * The calculations and aggregates that the `decoration` and content
    expressions of the columns, and the `confirm` expressions of the
    actions and bulk actions, refer to.
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
    |> with_expression_loads(view, resource)
    |> with_link_loads(view, resource)
    |> with_attachment_loads(resource)
  end

  @doc """
  The paths that the links of a view load: for each column, field, and
  `related` of a section with a `link_to`, the label of the linked record
  (refer to `PyroManiac.Link.label_paths/2`).
  """
  @spec link_paths(View.t(), Ash.Resource.t()) :: [[atom()]]
  def link_paths(%View{} = view, resource) do
    view
    |> PyroManiac.Card.view_links(resource)
    |> Enum.flat_map(fn
      %{kind: :single, record_path: [_ | _] = record_path, resource: from} ->
        PyroManiac.Link.label_paths(from, record_path)

      _link ->
        []
    end)
    |> Enum.uniq()
  end

  def link_paths(_view, _resource), do: []

  defp with_link_loads(loads, %View{} = view, resource) do
    link_loads = view |> link_paths(resource) |> Enum.flat_map(&build_load_for_path(&1, resource))
    Enum.uniq(List.wrap(loads) ++ link_loads)
  end

  defp with_link_loads(loads, _view, _resource), do: loads

  # The calculations and aggregates that the `decoration` and content
  # expressions of the columns, and the `confirm` expressions of the actions,
  # refer to.
  defp with_expression_loads(loads, %View{} = view, resource) do
    column_refs =
      Enum.flat_map(
        view.columns || [],
        &((Map.get(&1, :__decoration_refs__) || []) ++ PyroManiac.Content.refs(&1))
      )

    confirm_refs =
      Enum.flat_map(
        (view.actions || []) ++ (view.bulk_actions || []),
        &confirm_refs(&1, resource)
      )

    refs =
      (column_refs ++ confirm_refs)
      |> Enum.uniq()
      |> Enum.filter(fn name ->
        match?(
          %struct{} when struct in [Ash.Resource.Calculation, Ash.Resource.Aggregate],
          Ash.Resource.Info.field(resource, name)
        )
      end)

    Enum.uniq(List.wrap(loads) ++ refs)
  end

  defp with_expression_loads(loads, _view, _resource), do: loads

  defp confirm_refs(%{confirm: confirm}, resource)
       when not is_nil(confirm) and not is_binary(confirm) do
    case PyroManiac.Dsl.Expression.validate_refs(resource, confirm, in_memory_only?: false) do
      {:ok, names} -> names
      {:error, _message} -> []
    end
  end

  defp confirm_refs(_action, _resource), do: []

  defp merge_ensure_loaded(loads, %View{ensure_loaded: [_ | _] = ensure_loaded}) do
    Enum.uniq(loads ++ ensure_loaded)
  end

  defp merge_ensure_loaded(loads, _view), do: loads

  defp do_build_loads_from_view(%View{columns: columns, type: :data_table}, resource) do
    build_loads_from_columns(columns, resource)
  end

  defp do_build_loads_from_view(%View{type: type} = view, resource)
       when type in [:grid, :card, :list, :kanban, :calendar, :gantt, :timeline] do
    view
    |> PyroManiac.Card.paths(resource)
    |> Enum.flat_map(&build_load_for_path(&1, resource))
    |> Enum.uniq()
  end

  defp do_build_loads_from_view(%View{loads: loads, type: :render}, _resource) do
    List.wrap(loads)
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
