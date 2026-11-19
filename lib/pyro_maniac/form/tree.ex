defmodule PyroManiac.Form.Tree do
  @moduledoc """
  Traversal of the entity tree of a form: `action`, `bulk_action`, `step`,
  `group`, `row`, `compound`, and the inputs (`field`, `combobox`,
  `select`, `input`).

  All walkers of PyroManiac and of the renderers use these functions, so that
  a new entity is added in one place.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Form.{
    Action,
    BulkAction,
    Combobox,
    Compound,
    Field,
    Group,
    Input,
    Row,
    Select,
    Step
  }

  @inputs [Field, Combobox, Select, Input]
  @containers [Action, BulkAction, Step, Group, Row, Compound]

  @doc "The modules of the input entities."
  def input_modules, do: @inputs

  @doc "Whether the entity is an input."
  def input?(%module{}) when module in @inputs, do: true
  def input?(_), do: false

  @doc "Whether the entity contains other entities."
  def container?(%module{}) when module in @containers, do: true
  def container?(_), do: false

  @doc "The children of an entity. `[]` for an input."
  def children(%module{fields: fields}) when module in @containers, do: fields || []
  def children(_), do: []

  @doc "Replaces the children of a container."
  def put_children(%module{} = container, children) when module in @containers,
    do: %{container | fields: children}

  @doc """
  All inputs in DSL order, through each container.
  """
  def inputs(nodes) do
    nodes
    |> List.wrap()
    |> Enum.flat_map(fn node ->
      if input?(node), do: [node], else: inputs(children(node))
    end)
  end

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
