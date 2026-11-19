defmodule PyroManiac.Dsl.Expression do
  @moduledoc false

  # Helpers for the Ash expressions of the DSL: `visible?`, the `filter` and the
  # `argument` values of a combobox, and `tone`.
  #
  # Ash does not fill a `^context(...)` template in a filter that is added to
  # a query (tested 2026-11-18: AshSql raises "Unsupported expression").
  # Thus PyroManiac fills the templates itself with `Ash.Expr.fill_template/2`.
  # That function is `@doc false`, but ash_postgres, ash_sql, and ash_typst
  # call it. `fill/2` is the only caller in PyroManiac.

  @search_template {:_context, [:pyro_maniac, :search]}

  @doc "Whether the term is an expression (not a function, not nil)."
  def expression?(nil), do: false
  def expression?(term) when is_function(term), do: false
  def expression?(_), do: true

  @doc "The template tuples in a term, depth first."
  def templates(term), do: term |> collect([]) |> Enum.reverse()

  defp collect({:_arg, _} = t, acc), do: [t | acc]
  defp collect({:_actor, _} = t, acc), do: [t | acc]
  defp collect({:_context, _} = t, acc), do: [t | acc]

  defp collect(%_{} = struct, acc),
    do: struct |> Map.from_struct() |> Map.values() |> collect(acc)

  defp collect(%{} = map, acc), do: map |> Map.values() |> collect(acc)
  defp collect(list, acc) when is_list(list), do: Enum.reduce(list, acc, &collect/2)

  defp collect(tuple, acc) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> collect(acc)

  defp collect(_other, acc), do: acc

  @doc "The names of the `^arg(name)` templates."
  def arg_names(term) do
    for {:_arg, name} <- templates(term), uniq: true, do: name
  end

  @doc "The names of the `^input(name)` templates."
  def input_names(term) do
    for {:_context, [:pyro_maniac, :inputs, name]} <- templates(term), uniq: true, do: name
  end

  @doc "Whether the term uses `^search()`."
  def uses_search?(term), do: @search_template in templates(term)

  @doc """
  Fills the templates. Options: `:actor`, `:args` (a map), `:search` (the
  typed text), `:inputs` (a map of input values), `:tenant`.
  """
  def fill(term, opts) do
    context = %{
      pyro_maniac: %{
        search: Keyword.get(opts, :search, ""),
        inputs: Keyword.get(opts, :inputs, %{})
      }
    }

    Ash.Expr.fill_template(term,
      actor: Keyword.get(opts, :actor),
      tenant: Keyword.get(opts, :tenant),
      args: Keyword.get(opts, :args, %{}),
      context: context
    )
  end

  @doc """
  Parses an expression against a resource, with neutral values for the
  templates, to validate its references at compile time. Returns
  `{:ok, refs}` (the `Ash.Query.Ref`s, without the refs in `parent(...)`)
  or `{:error, message}`.

  Option `:parent`: the resource one level up, for `parent(...)`.
  """
  def parse_refs(resource, term, opts \\ []) do
    with {:ok, refs, _parent_refs} <- parse_all_refs(resource, term, opts[:parent]) do
      {:ok, refs}
    end
  end

  defp parse_all_refs(resource, term, parent) do
    args = Map.new(arg_names(term), &{&1, nil})
    inputs = Map.new(input_names(term), &{&1, nil})
    filled = fill(term, args: args, inputs: inputs, search: "")
    context = if parent, do: %{parent_stack: [parent]}, else: %{}

    case Ash.Filter.parse(resource, filled, context) do
      {:ok, %Ash.Filter{expression: expression}} ->
        parent_refs =
          expression
          |> Ash.Filter.flat_map(fn
            %Ash.Query.Parent{expr: parent_expression} -> [parent_expression]
            _other -> []
          end)
          |> Enum.flat_map(&Ash.Filter.list_refs/1)

        {:ok, Ash.Filter.list_refs(expression), parent_refs}

      {:ok, nil} ->
        {:ok, [], []}

      {:error, error} ->
        {:error, Exception.message(Ash.Error.to_ash_error(error))}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  @doc """
  Validates a `visible?` expression or a `tone` expression. With
  `in_memory_only?: true` (the default), each reference is an attribute,
  because the expression is evaluated in memory with no query. With
  `in_memory_only?: false`, a reference can also be a calculation or an
  aggregate (they are loaded). A relationship path is always an error.

  Option `:parent`: the resource one level up. `parent(field)` refers to
  its attributes (always in memory). Without it, `parent(...)` is an error.

  Returns `{:ok, names}` or `{:error, message}`. A name in `parent(...)` is
  `{:parent, name}`.
  """
  def validate_refs(resource, term, opts \\ []) do
    in_memory_only? = Keyword.get(opts, :in_memory_only?, true)
    parent = Keyword.get(opts, :parent)

    with {:ok, refs, parent_refs} <- parse_all_refs(resource, term, parent),
         :ok <- check_parent(parent_refs, parent),
         :ok <- check_refs(refs, in_memory_only?),
         :ok <- check_refs(parent_refs, true) do
      names = Enum.map(refs, &Ash.Query.Ref.name/1)
      parent_names = Enum.map(parent_refs, &{:parent, Ash.Query.Ref.name(&1)})
      {:ok, Enum.uniq(names ++ parent_names)}
    end
  end

  defp check_parent([_ | _], nil),
    do: {:error, "it uses `parent(...)`, but there is no level above it (no nested form)"}

  defp check_parent(_parent_refs, _parent), do: :ok

  defp check_refs(refs, in_memory_only?) do
    Enum.find_value(refs, :ok, fn ref ->
      case check_ref(ref, in_memory_only?) do
        :ok -> nil
        error -> error
      end
    end)
  end

  defp check_ref(%Ash.Query.Ref{relationship_path: [_ | _] = path}, _in_memory_only?),
    do:
      {:error,
       "it refers to the relationship path #{inspect(path)}. The expression is evaluated in memory, " <>
         "and relationships are not loaded for it"}

  defp check_ref(%Ash.Query.Ref{attribute: %Ash.Resource.Attribute{}}, _), do: :ok

  defp check_ref(%Ash.Query.Ref{attribute: attribute}, true),
    do:
      {:error,
       "it refers to #{inspect(Ash.Query.Ref.name(%Ash.Query.Ref{attribute: attribute}))}, which is not an attribute. The expression is evaluated in memory, with no query"}

  defp check_ref(_ref, false), do: :ok
end
