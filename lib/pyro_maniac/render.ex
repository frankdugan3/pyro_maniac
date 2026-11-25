defmodule PyroManiac.Render do
  @moduledoc """
  A custom render of a node: `render "text"` or `render expr(...)` for every
  renderer, and `render Renderer, implementation` for one renderer (it
  overrides the text or the expression). A node has at most one text or
  expression, and one `render` for each renderer, so a page can have more
  than one renderer. Refer to `PyroManiac.Content`.

  The inputs of a form (`field`, `select`, `combobox`, `input`) take
  `render Renderer, implementation` only.

      field :status do
        render PyroManiac.LiveView, BreweryWeb.Components.StatusBadge
        render PyroManiac.Solid, "~/components/StatusBadge"
      end

  - `renderer`: the renderer library (for example `PyroManiac.LiveView`).
    Not a compile-time dependency.
  - `implementation`: any term. The renderer validates it (a module for
    LiveView, an import path for Solid, a tuple of a module and its
    options, ...). Not a bare keyword list: the DSL reads a keyword list at
    the end as the options of `render`. Wrap it: `{BreweryWeb.Components.StatusBadge,
    props: [size: :sm]}`.

  The implementation renders the whole node. A node with more than one part
  (the button and the content of an extra action) has one implementation
  that renders all of them.

  PyroManiac checks that a node has at most one text or expression, and
  one `render` for each renderer. Each renderer is an extension of the
  page. Its verifier checks that each node with `render` entities and no
  text or expression has one for this renderer, and validates the
  implementation (`verify/3`).
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :render,
    args: [:renderer, {:optional, :implementation}],
    describe:
      "A custom render of the node: a text or an Ash expression for every renderer, or an implementation for one renderer.",
    no_depend_modules: [:renderer, :implementation],
    schema: PyroManiac.Content.schema(),
    private_fields: PyroManiac.Content.private_fields(),
    transform: {PyroManiac.Content, :normalize, []}

  alias PyroManiac.Form.{Action, BulkAction, Tree}
  alias PyroManiac.View.View

  @typedoc """
  A node with `render` entities: the entity, its path in the DSL, a label for
  the errors, and the `render` entities.
  """
  @type rendered :: %{entity: struct(), origin: [atom()], label: String.t(), renders: [t()]}

  @doc "The implementation of `renderer` in the `render` entities of a node, or `nil`."
  @spec implementation([t()] | nil, module()) :: term() | nil
  def implementation(renders, renderer) do
    Enum.find_value(renders || [], fn
      %{kind: :impl, renderer: ^renderer, implementation: impl} -> impl
      _render -> nil
    end)
  end

  @doc """
  The render of a node for `renderer`: its implementation, else the text
  or the expression (refer to `PyroManiac.Content.resolve/2`).
  """
  @spec resolve([t()] | nil, module()) :: {:impl | :text | :expr, term()} | nil
  defdelegate resolve(renders, renderer), to: PyroManiac.Content

  @doc """
  The nodes of a page with `render` entities: the views and their columns,
  record trees, and extra actions; the nodes of the actions; the
  extra actions of the page; and the description of the page (the
  `description` entities of the `page` section).
  """
  @spec nodes(Spark.Dsl.t() | module()) :: [rendered()]
  def nodes(page) do
    views = Spark.Dsl.Extension.get_entities(page, [:views])
    forms = Spark.Dsl.Extension.get_entities(page, [:forms])
    page_entities = Spark.Dsl.Extension.get_entities(page, [:page])
    nodes(views, forms, page_entities)
  end

  @doc "The nodes with `render` entities of the entities of a page (refer to `nodes/1`)."
  @spec nodes([struct()], [struct()], [struct()]) :: [rendered()]
  def nodes(views, forms, page_entities) do
    {page_renders, page_entities} =
      Enum.split_with(page_entities, &is_struct(&1, PyroManiac.Description))

    view_nodes = Enum.flat_map(views, &view_nodes/1)

    form_nodes =
      for %module{} = action <- forms,
          module in [Action, BulkAction],
          node <- Tree.all(action.fields || []),
          do: {node, [:forms, :action, action.name]}

    page_nodes = Enum.map(page_entities, &{&1, [:page]})

    nodes =
      for {entity, origin} <- view_nodes ++ form_nodes ++ page_nodes,
          key <- [:render, :description, :label],
          renders = Map.get(entity, key),
          is_list(renders),
          key == :render or Enum.any?(renders, &match?(%{kind: :impl}, &1)),
          renders != [] do
        name = List.wrap(Map.get(entity, :name))

        %{
          entity: entity,
          origin: origin ++ name ++ if(key == :render, do: [], else: [key]),
          label: inspect(entity.__struct__) <> if(key == :render, do: "", else: " #{key}"),
          renders: renders
        }
      end

    description_node(page_renders) ++ nodes
  end

  defp description_node(renders) do
    if Enum.any?(renders, &(&1.kind == :impl)),
      do: [
        %{
          entity: hd(renders),
          origin: [:page, :description],
          label: "the page description",
          renders: renders
        }
      ],
      else: []
  end

  defp view_nodes(%View{} = view) do
    origin = [:views, :view, List.first(view.name)]

    [{view, [:views, :view]}] ++
      Enum.map(
        (view.columns || []) ++ Tree.all(view.fields || []) ++ (view.extra_actions || []),
        &{&1, origin}
      )
  end

  defp view_nodes(_view), do: []

  @doc """
  For the verifier of a renderer: each node with a `render` and no text or
  expression has one for `renderer`, and `validate` accepts its
  implementation. `validate` gives
  `:ok` or `{:error, reason}`.

  Gives `:ok`, or `{:error, Spark.Error.DslError}` for the first node that
  fails.
  """
  @spec verify(Spark.Dsl.t(), module(), (term() -> :ok | {:error, String.t()})) ::
          :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl, renderer, validate) do
    module = Spark.Dsl.Extension.get_persisted(dsl, :module)

    dsl
    |> nodes()
    |> Enum.find_value(:ok, fn node ->
      verify_node(node, implementation(node.renders, renderer), renderer, validate, module)
    end)
  end

  # A text or an expression satisfies a renderer without an implementation.
  defp verify_node(node, nil, renderer, validate, module) do
    if PyroManiac.Content.portable(node.renders),
      do: nil,
      else: missing_implementation(node, renderer, validate, module)
  end

  defp verify_node(node, implementation, _renderer, validate, module) do
    case validate.(implementation) do
      :ok -> nil
      {:error, reason} -> error(module, node, reason, "fix the implementation of the `render`")
    end
  end

  defp missing_implementation(node, renderer, _validate, module) do
    error(
      module,
      node,
      "#{node.label} has a `render` for #{inspect(Enum.map(node.renders, & &1.renderer))}, " <>
        "but not for #{inspect(renderer)}",
      "add `render #{inspect(renderer)}, <implementation>`"
    )
  end

  defp error(module, node, why, fix) do
    {:error,
     PyroManiac.Dsl.Error.build(
       module: module,
       location: Spark.Dsl.Entity.anno(node.entity),
       path: node.origin,
       why: why,
       fix: fix
     )}
  end
end
