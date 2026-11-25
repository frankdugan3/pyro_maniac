defmodule PyroManiac.Form.Tree do
  @moduledoc """
  Traversal of a record tree: the nodes of a view, an `action`, or a
  `bulk_action`: `step`, `tabs`, `tab`, `section`, `row`, `compound`, the
  inputs (`field`, `combobox`, `select`, `input`), and the other leaves
  (`related`, `attachments`, `workflow`).

  One tree serves the read action of its view (view mode: each leaf shows
  its value) and each write action that uses it (an input shows its input,
  and the other leaves, a read-only `field` or `related`, show their
  value). A node with `only [names]` is in those actions only
  (`for_action/2`, `in_action?/2`).

  All walkers of PyroManiac and of the renderers use these functions, so that
  a new entity is added in one place.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Form.{
    Action,
    Attachments,
    BulkAction,
    Combobox,
    Compound,
    Field,
    Input,
    Related,
    Row,
    Section,
    Select,
    Step,
    Tab,
    Tabs,
    Workflow
  }

  @inputs [Field, Combobox, Select, Input]
  @leaves @inputs ++ [Related, Attachments, Workflow]
  @containers [Action, BulkAction, Step, Tabs, Tab, Section, Row, Compound]

  @doc "The modules of the input entities."
  def input_modules, do: @inputs

  @doc """
  Whether the entity is an input of the action: a `field`, `combobox`,
  `select`, or `input` that is not read-only.
  """
  def input?(%module{"__read_only?__": true}) when module in @inputs, do: false
  def input?(%module{}) when module in @inputs, do: true
  def input?(_), do: false

  @doc """
  Whether the entity shows one value of the record: an input, or a read-only
  `field`.
  """
  def value?(%module{}) when module in @inputs, do: true
  def value?(_), do: false

  @doc """
  Whether the entity is a read-only `field`, `select`, `combobox`, or
  `input` (not an input of the action).
  """
  def read_only?(%module{"__read_only?__": read_only?}) when module in @inputs,
    do: read_only?

  def read_only?(_), do: false

  @doc "Whether the entity is a leaf: a value, `related`, or `attachments`."
  def leaf?(%module{}) when module in @leaves, do: true
  def leaf?(_), do: false

  @doc "Whether the entity contains other entities."
  def container?(%module{}) when module in @containers, do: true
  def container?(_), do: false

  @doc "The children of an entity. `[]` for a leaf."
  def children(%module{fields: fields}) when module in @containers, do: fields || []
  def children(_), do: []

  @doc "Replaces the children of a container."
  def put_children(%module{} = container, children) when module in @containers,
    do: %{container | fields: children}

  @doc """
  The nodes of one action: removes each node whose `only` does not name the
  action, with its children. The read action of a view is its view mode.
  """
  @spec for_action(term(), atom()) :: term()
  def for_action(nodes, action) when is_list(nodes) do
    nodes
    |> Enum.filter(&in_action?(&1, action))
    |> Enum.map(&for_action(&1, action))
  end

  def for_action(node, action) do
    if container?(node),
      do: put_children(node, for_action(children(node), action)),
      else: node
  end

  @doc "Whether a node is in an action (its `only` is `nil` or names the action)."
  def in_action?(node, action) do
    case Map.get(node, :only) do
      nil -> true
      only -> action in List.wrap(only)
    end
  end

  @doc """
  The inputs of a tree, in DSL order, through each container: no read-only
  field.
  """
  def inputs(nodes) do
    nodes
    |> List.wrap()
    |> all()
    |> Enum.filter(&input?/1)
  end

  @doc """
  All value leaves (inputs and read-only fields) in DSL order, in both modes.
  """
  def values(nodes), do: nodes |> all() |> Enum.filter(&value?/1)

  @doc "All leaves (values, `related`, `attachments`) in DSL order, in both modes."
  def leaves(nodes), do: nodes |> all() |> Enum.filter(&leaf?/1)

  @doc "The `tabs` of the top level, or `nil`."
  def tabs(nodes), do: nodes |> List.wrap() |> Enum.find(&is_struct(&1, Tabs))

  @doc """
  All entities in DSL order (depth first, the parent before its children).
  """
  def all(nodes) do
    nodes
    |> List.wrap()
    |> Enum.flat_map(fn node -> [node | all(children(node))] end)
  end

  @doc """
  Reduces over all entities, depth first, the parent before its children.
  """
  def reduce(nodes, acc, fun) do
    nodes
    |> all()
    |> Enum.reduce(acc, fun)
  end

  @doc """
  Maps each entity, depth first. `fun` gets the entity after its children
  are mapped.
  """
  def map(nodes, fun) when is_list(nodes), do: Enum.map(nodes, &map(&1, fun))

  def map(node, fun) do
    node =
      if container?(node),
        do: put_children(node, map(children(node), fun)),
        else: node

    fun.(node)
  end

  @doc """
  Maps each entity with an accumulator that the parent gives to its
  children (for example the path). `fun` gets the entity and the
  accumulator, and returns `{entity, accumulator for the children}`.
  """
  def map_down(nodes, acc, fun) when is_list(nodes),
    do: Enum.map(nodes, &map_down(&1, acc, fun))

  def map_down(node, acc, fun) do
    {node, child_acc} = fun.(node, acc)

    if container?(node),
      do: put_children(node, map_down(children(node), child_acc, fun)),
      else: node
  end
end
