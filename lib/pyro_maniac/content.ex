defmodule PyroManiac.Content do
  @moduledoc """
  The content that a node shows: `render`, `description`, and the `label` of
  a column. Each one is a portable value, with optional implementations for
  each renderer:

      column :status do
        label "Status"
        render expr(if status == :active, do: "Active", else: "Not active")
        render PyroManiac.LiveView, BreweryWeb.Cells.Status
      end

  - `"text"`: the literal text, for every renderer.
  - `expr(...)`: an Ash expression on the record, for every renderer.
  - `Renderer, implementation`: the implementation for one renderer. It
    overrides the text or the expression for that renderer.

  A node has at most one text or expression, and one implementation for
  each renderer. A node with a text or an expression satisfies every
  renderer. Refer to `resolve/2`.
  """
  @moduledoc group: "PyroManiac"

  @typedoc "One `render`, `description`, or `label` entity."
  @type t :: %{
          required(:renderer) => module() | nil,
          required(:implementation) => term(),
          required(:kind) => :text | :expr | :impl | :inherit,
          optional(atom()) => term()
        }

  @doc false
  def schema do
    [
      renderer: [
        doc:
          "The renderer library (for example `PyroManiac.LiveView`), or, alone, the portable value: a string or an Ash expression.",
        required: true,
        type: :any
      ],
      implementation: [
        doc: "The implementation for the renderer. The renderer validates it.",
        type: :any
      ]
    ]
  end

  @doc false
  def private_fields do
    [
      kind: [
        doc:
          "`:text`, `:expr`, or `:impl` (an implementation for one renderer). Set by the entity.",
        type: :atom
      ],
      __refs__: [
        default: [],
        doc: "The fields that an expression refers to. Set by the transformer.",
        type: {:list, :atom}
      ]
    ]
  end

  @doc false
  # One argument is the portable value; two are a renderer and its
  # implementation.
  def normalize(%{renderer: value, implementation: nil} = entity) when is_binary(value),
    do: {:ok, %{entity | renderer: nil, implementation: value, kind: :text}}

  def normalize(%{renderer: :inherit, implementation: nil} = entity),
    do: {:ok, %{entity | renderer: nil, implementation: :inherit, kind: :inherit}}

  def normalize(%{renderer: value, implementation: nil}) when is_atom(value),
    do:
      {:error,
       "#{inspect(value)} is a renderer without an implementation. Give the implementation " <>
         "(`#{inspect(value)}, <implementation>`), a string, or an Ash expression"}

  def normalize(%{renderer: value, implementation: nil} = entity),
    do: {:ok, %{entity | renderer: nil, implementation: value, kind: :expr}}

  def normalize(%{renderer: renderer} = entity) when is_atom(renderer),
    do: {:ok, %{entity | kind: :impl}}

  def normalize(_entity),
    do: {:error, "the renderer of an implementation is a module, for example PyroManiac.LiveView"}

  @doc """
  The content for `renderer`: `{:impl, implementation}` (its own
  implementation), else `{:text, string}` or `{:expr, expression}` (the
  portable value), else `nil`.
  """
  @spec resolve([t()] | nil, module()) :: {:impl | :text | :expr, term()} | nil
  def resolve(entries, renderer) do
    case Enum.find(entries || [], &(&1.kind == :impl and &1.renderer == renderer)) do
      nil -> portable(entries)
      entry -> {:impl, entry.implementation}
    end
  end

  @doc "The portable value: `{:text, string}`, `{:expr, expression}`, or `nil`."
  @spec portable([t()] | nil) :: {:text | :expr, term()} | nil
  def portable(entries) do
    Enum.find_value(entries || [], fn
      %{kind: kind, implementation: value} when kind in [:text, :expr] -> {kind, value}
      _entry -> nil
    end)
  end

  @doc "The text of a node, or `nil` (no text, an expression, or implementations only)."
  @spec text([t()] | String.t() | nil) :: String.t() | nil
  def text(text) when is_binary(text), do: text

  def text(entries) when is_list(entries) do
    case portable(entries) do
      {:text, text} -> text
      _other -> nil
    end
  end

  def text(_entries), do: nil

  @doc "The fields that the expressions of the content of an entity refer to."
  @spec refs(struct()) :: [atom()]
  def refs(entity) do
    [:render, :description, :label]
    |> Enum.flat_map(&List.wrap(Map.get(entity, &1)))
    |> Enum.filter(&is_map/1)
    |> Enum.flat_map(&(Map.get(&1, :__refs__) || []))
    |> Enum.uniq()
  end

  @doc false
  def default_text(module, text),
    do: struct(module, renderer: nil, implementation: text, kind: :text)

  @doc false
  # Validates the expressions of the content of an entity against
  # `resource`, and records their refs. Gives `{:ok, entity}` or
  # `{:error, key, message}`.
  def resolve_refs(entity, resource) do
    Enum.reduce_while([:render, :description, :label], {:ok, entity}, fn key, {:ok, acc} ->
      case resolve_key(acc, key, resource) do
        {:ok, acc} -> {:cont, {:ok, acc}}
        error -> {:halt, error}
      end
    end)
  end

  defp resolve_key(entity, key, resource) do
    with [%{kind: _} | _] = entries <- Map.get(entity, key),
         {:ok, entries} <- resolve_entries(entries, resource) do
      {:ok, Map.put(entity, key, entries)}
    else
      {:error, message} -> {:error, key, message}
      _no_content -> {:ok, entity}
    end
  end

  defp resolve_entries(entries, resource) do
    Enum.reduce_while(entries, {:ok, []}, fn
      %{kind: :expr, implementation: expression} = entry, {:ok, acc} ->
        case PyroManiac.Dsl.Expression.validate_refs(resource, expression, in_memory_only?: false) do
          {:ok, names} -> {:cont, {:ok, acc ++ [%{entry | __refs__: names}]}}
          {:error, message} -> {:halt, {:error, message}}
        end

      entry, {:ok, acc} ->
        {:cont, {:ok, acc ++ [entry]}}
    end)
  end

  @doc false
  # `:inherit` entries take `text` (the description of the source), or go.
  def inherit(entries, text) do
    Enum.flat_map(entries || [], fn
      %{kind: :inherit} = entry when is_binary(text) and text != "" ->
        [%{entry | kind: :text, implementation: text}]

      %{kind: :inherit} ->
        []

      entry ->
        [entry]
    end)
  end

  @doc """
  The content for `renderer` with a record: `{:impl, implementation}`, or
  `{:value, value}` (the text, or the value of the expression on `record`),
  or `nil`.
  """
  @spec value([t()] | nil, module(), struct() | nil, term()) :: {:impl | :value, term()} | nil
  def value(entries, renderer, record, actor \\ nil) do
    case resolve(entries, renderer) do
      {:impl, implementation} -> {:impl, implementation}
      {:text, text} -> {:value, text}
      {:expr, expression} -> {:value, eval(expression, record, actor)}
      nil -> nil
    end
  end

  defp eval(_expression, nil, _actor), do: nil

  defp eval(expression, %resource{} = record, actor) do
    filled = PyroManiac.Dsl.Expression.fill(expression, actor: actor)

    case Ash.Expr.eval(filled,
           record: record,
           resource: resource,
           actor: actor,
           unknown_on_unknown_refs?: true
         ) do
      {:ok, value} -> value
      _ -> nil
    end
  rescue
    _ -> nil
  end
end
