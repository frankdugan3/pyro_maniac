defmodule PyroManiac.Card do
  @moduledoc """
  The cards of a page: its `:card` views (the single views), which show one
  record. A card has its own record tree (a card without nodes does not
  compile), in view mode for the read action of the view. An `action`
  without nodes in the card (`action [:create, :update]`) uses that tree as
  its form: **Edit** switches the card to the form of the update action in
  the same place. A card without a write action is in view mode only. A
  page can have several cards; one is primary. A `:grid` view shows each
  record with its own record tree, or with the primary card of the page
  (`card? true`).

      view :read do
        type :card
        primary? true
        presentation :modal
        action [:create, :update], :guard

        section :recipe do
          field :name, autofocus: true
          select :style
          select :status
          field :batch_count, only: [:read]
        end

        section :targets do
          field :target_abv
          field :target_og
          field :target_fg
          field :description, type: :textarea
        end
      end

      view :read do
        type :grid
        card? true
      end

  The cards, the grids, and the forms of the actions have the same nodes:
  `section`, `row`, `compound`, `field`, `select`, `combobox`, `input`,
  `related`, `attachments`, `workflow`, `tabs`, and `step`.

  ## The URL

  The card is in the URL of its page, so Back, a reload, and a shared link
  open the same record. A link from another page navigates to this URL.

  | Param | Meaning |
  |---|---|
  | `card=<id>` | the primary card |
  | `card=<view>:<id>` | another card of the page (the action of its view) |
  | `edit` | the card in edit mode |
  | `tab=<name>` | the open tab of the record tree |

  `param/3` and `parse_param/2` encode and decode `card`.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Form.{Attachments, Combobox, Field, Input, Related, Select, Tab, Tabs, Tree}
  alias PyroManiac.Info
  alias PyroManiac.Link
  alias PyroManiac.View.View

  @doc "The primary single view (the `:card`) of a page, or `nil`."
  @spec view(module()) :: View.t() | nil
  defdelegate view(page), to: Info, as: :primary_single_view

  @doc """
  The record tree of a view in view mode (its nodes for its read action),
  resolved. A grid with `card? true` has the nodes of the primary card
  before `tabs`, without `related` and `attachments`.
  """
  @spec tree(module() | View.t()) :: [struct()]
  def tree(%View{__tree__: tree}), do: tree || []

  def tree(page) when is_atom(page) do
    case view(page) do
      nil -> []
      card -> tree(card)
    end
  end

  @doc """
  The nodes of a tree that a card of a grid shows: the nodes before `tabs`,
  without `related` and `attachments`, in view mode.
  """
  @spec grid_tree([struct()]) :: [struct()]
  def grid_tree(tree) do
    tree
    |> Enum.take_while(&(not is_struct(&1, Tabs)))
    |> prune_records()
  end

  defp prune_records(nodes) when is_list(nodes) do
    nodes
    |> Enum.reject(&(is_struct(&1, Related) or is_struct(&1, Attachments)))
    |> Enum.map(&prune_key(&1, :fields))
  end

  defp prune_key(node, key) do
    case Map.get(node, key) do
      nodes when is_list(nodes) and nodes != [] -> Map.put(node, key, prune_records(nodes))
      _ -> node
    end
  end

  @doc """
  The actions of the primary card of a page (refer to
  `PyroManiac.Info.actions/2`): the actions that use the tree of the card
  (an update action switches the card to its form), and the actions with
  their own tree. `[]` for a card without a write action.
  """
  @spec actions(module()) :: [PyroManiac.Form.Action.t()]
  def actions(page) do
    case view(page) do
      nil -> []
      card -> Info.actions(page, card)
    end
  end

  @doc """
  The tabs of a tree: `[%{name:, label:, count:}]`, or `[]`. For a page,
  the tabs of its primary card in view mode. The tree of an action has the
  tabs of that action (in create mode, all the tabs).
  """
  @spec tabs(module() | [struct()]) :: [map()]
  def tabs(page) when is_atom(page), do: page |> tree() |> tabs()

  def tabs(tree) when is_list(tree) do
    case Tree.tabs(tree) do
      nil -> []
      tabs -> for tab <- tabs.fields, do: %{name: tab.name, label: tab.label, count: tab.count}
    end
  end

  @doc """
  The value of the `card` param for a record in the single view `view` of
  `page`: `"<id>"` for the primary single view, else `"<view>:<id>"` (the
  first action name of the view).
  """
  @spec param(module(), View.t(), term()) :: String.t()
  def param(page, %View{} = view, id) do
    if view == view(page), do: to_string(id), else: "#{hd(view.name)}:#{id}"
  end

  @doc """
  Decodes the `card` param of a page. Gives `{:ok, view, id}`, or `:error`
  for a name that is not a single view of the page.
  """
  @spec parse_param(module(), String.t()) :: {:ok, View.t(), String.t()} | :error
  def parse_param(page, value) when is_binary(value) do
    case String.split(value, ":", parts: 2) do
      [id] when id != "" ->
        case view(page) do
          nil -> :error
          view -> {:ok, view, id}
        end

      [name, id] when id != "" ->
        case Enum.find(Info.views_of_type(page, :card), &(to_string(hd(&1.name)) == name)) do
          nil -> :error
          view -> {:ok, view, id}
        end

      _ ->
        :error
    end
  end

  def parse_param(_page, _value), do: :error

  # The links of a page ----------------------------------------------------

  @doc """
  Each link of a page: `%{kind:, link:, destination:, resource:,
  record_path:, entity:, origin:}`.

  - `kind`: `:single` (the single view of a record of the relationship),
    `:list` (a list view of all the records of a relationship to many), or
    `:delegate` (the page of `related ... delegate_to`, in `page`).
  - `destination`: the resource of the linked records; `nil` when the
    source of the node has no relationship.
  - `resource` and `record_path`: the records are at `record_path` from a
    record of `resource`.
  """
  @spec links(module() | Spark.Dsl.t()) :: [map()]
  def links(page) do
    page_links(Info.resource(page), Info.views(page), Info.actions(page))
  end

  @doc """
  The links of the views and the actions of a page (refer to
  `links/1`). For the transformers, which have the entities but not the
  persisted views.
  """
  @spec page_links(Ash.Resource.t(), [struct()], [struct()]) :: [map()]
  def page_links(resource, views, forms) do
    view_links =
      Enum.flat_map(views, fn
        %View{} = view -> view_links(view, view.resource || resource)
        _ -> []
      end)

    form_links =
      Enum.flat_map(forms, fn
        %PyroManiac.Form.Action{fields: fields} = action ->
          form_links(fields, action.resource || resource, [:view, :action, action.name])

        _ ->
          []
      end)

    view_links ++ form_links
  end

  @doc "The links of one view (refer to `links/1`)."
  @spec view_links(View.t(), Ash.Resource.t()) :: [map()]
  def view_links(%View{} = view, resource) do
    origin = [:views, :view | List.wrap(List.first(List.wrap(view.name)))]

    column_links =
      Enum.flat_map(view.columns || [], fn column ->
        source_links(resource, column.source, column, origin ++ [:column, column.name])
      end)

    column_links ++ form_links(tree(view), resource, origin)
  end

  defp form_links(fields, resource, origin) do
    Enum.flat_map(Tree.all(fields), fn
      %Combobox{__relationship__: relationship} = combobox when not is_nil(relationship) ->
        record_path = combobox.__full_path__ ++ [relationship]
        node_links(resource, record_path, combobox, origin ++ [:combobox, combobox.name])

      %Field{"__read_only?__": true} = field ->
        field_origin = origin ++ [:field, field.name]
        level = Info.resource_by_path(resource, field.__full_path__)

        if Ash.Resource.Info.relationship(level, field.name),
          do: node_links(resource, field.__full_path__ ++ [field.name], field, field_origin),
          else: no_relationship_links(field, field_origin, [field.name])

      %Related{} = related ->
        related_links(
          related,
          resource,
          related.__full_path__,
          origin ++ [:related, related.name]
        )

      _entity ->
        []
    end)
  end

  # A column or a field: its record is the relationship of its source.
  defp source_links(resource, source, entity, origin) do
    case Link.record_path(resource, source) do
      nil -> no_relationship_links(entity, origin, source)
      record_path -> node_links(resource, record_path, entity, origin)
    end
  end

  # A `link_to` on a node without a relationship: the verifier names it.
  defp no_relationship_links(entity, origin, source) do
    for link <- Map.get(entity, :link_to) || [] do
      %{
        kind: :single,
        link: link,
        destination: nil,
        resource: nil,
        record_path: nil,
        source: source,
        entity: entity,
        origin: origin
      }
    end
  end

  # One record: a single link. Many records: a single link for each, and a
  # list link to all of them.
  defp node_links(resource, record_path, entity, origin) do
    case Link.link(Map.get(entity, :link_to)) do
      nil ->
        []

      link ->
        base = %{
          link: link,
          resource: resource,
          record_path: record_path,
          destination: Link.destination(resource, record_path),
          entity: entity,
          origin: origin
        }

        kinds = if Link.many?(resource, record_path), do: [:single, :list], else: [:single]
        Enum.map(kinds, &Map.put(base, :kind, &1))
    end
  end

  defp related_links(%Related{} = related, resource, path, origin) do
    record_path = path ++ [related.name]
    level = Info.resource_by_path(resource, path)

    case Ash.Resource.Info.relationship(level, related.name) do
      nil ->
        []

      %{destination: destination} ->
        delegate =
          if related.delegate_to do
            [
              %{
                kind: :delegate,
                page: related.delegate_to,
                link: nil,
                destination: destination,
                resource: resource,
                record_path: record_path,
                entity: related,
                origin: origin ++ [:delegate_to]
              }
            ]
          else
            []
          end

        delegate ++ node_links(resource, record_path, related, origin)
    end
  end

  # The paths of a tree -----------------------------------------------------

  @doc """
  The paths that a view loads from its resource for its record tree: each
  value of the tree (in view mode), the label of each linked record, the records of
  `related`, the counts, the `decoration` refs, and the files.
  """
  @spec paths(View.t(), Ash.Resource.t()) :: [Link.path()]
  def paths(%View{} = view, resource) do
    view
    |> tree()
    |> tree_paths(resource)
    |> Enum.uniq()
  end

  @doc "The paths that the nodes of a tree load (refer to `paths/2`)."
  @spec tree_paths([struct()], Ash.Resource.t()) :: [Link.path()]
  def tree_paths(tree, resource) do
    tree
    |> Tree.all()
    |> Enum.flat_map(&(node_paths(&1, resource) ++ content_paths(&1)))
  end

  # The fields that the expressions of `render` and `description` refer to.
  defp content_paths(node) do
    path = Map.get(node, :__full_path__) || []
    node |> PyroManiac.Content.refs() |> Enum.map(&(path ++ [&1]))
  end

  defp node_paths(%Combobox{__relationship__: relationship} = combobox, resource)
       when not is_nil(relationship) do
    record_path = combobox.__full_path__ ++ [relationship]
    value_path(resource, combobox) ++ Link.label_paths(resource, record_path)
  end

  defp node_paths(%module{name: name, __full_path__: path} = node, resource)
       when module in [Field, Select, Input, Combobox] do
    level = Info.resource_by_path(resource, path)
    decoration = Enum.map(Map.get(node, :__decoration_refs__) || [], &(path ++ [&1]))

    if Ash.Resource.Info.relationship(level, name),
      do: Link.label_paths(resource, path ++ [name]) ++ decoration,
      else: value_path(resource, node) ++ decoration
  end

  defp node_paths(%Related{} = related, resource),
    do: related_paths(related, resource, related.__full_path__)

  defp node_paths(%Attachments{name: name}, _resource), do: [[name]]

  defp node_paths(%PyroManiac.Form.Workflow{} = workflow, resource) do
    history = if workflow.history, do: [[workflow.history]], else: []
    Enum.map(PyroManiac.Workflow.loads(resource), &[&1]) ++ history
  end

  defp node_paths(%Tab{count: count}, _resource) when not is_nil(count), do: [[count]]
  defp node_paths(_node, _resource), do: []

  defp related_paths(%Related{} = related, resource, path) do
    record_path = path ++ [related.name]
    count = if related.count, do: [path ++ [related.count]], else: []

    records =
      cond do
        related.delegate_to ->
          []

        related.type in [:count, :badge] and related.fields == [] ->
          [record_path]

        true ->
          fields = Enum.map(related.fields, &(record_path ++ List.wrap(&1.source)))
          [record_path | fields] ++ related_label_paths(related, resource, record_path)
      end

    count ++ records
  end

  # Records without fields show their labels; records with fields show them
  # when each record is a link.
  defp related_label_paths(related, resource, record_path) do
    if related.fields == [] or Link.link(related.link_to),
      do: Link.label_paths(resource, record_path),
      else: []
  end

  # A value that the record has: not an argument of the action.
  defp value_path(resource, %{name: name, __full_path__: path}) do
    level = Info.resource_by_path(resource, path)

    if Ash.Resource.Info.field(level, name),
      do: [path ++ [name]],
      else: []
  end

  @doc """
  The fields of **Show all fields**: the exposed fields of the read action of
  the card (attributes, calculations, and aggregates) that its tree does not
  show, in the order of the resource.
  """
  @spec extra_fields(module()) :: [atom()]
  def extra_fields(page) do
    case view(page) do
      nil ->
        []

      %View{} = card ->
        resource = Info.resource(page)
        action = card.read_action || hd(card.name)
        shown = MapSet.new(paths(card, resource))

        exposed =
          case PyroManiac.Resource.Info.exposed(resource, action) do
            nil -> []
            expose -> PyroManiac.Surface.top_level(expose.loads)
          end

        for name <- exposed,
            is_nil(Ash.Resource.Info.relationship(resource, name)),
            not MapSet.member?(shown, [name]),
            do: name
    end
  end
end
