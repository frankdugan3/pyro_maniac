defmodule PyroManiac.Form do
  @moduledoc """
  Runtime functions of the form DSL that all renderers use, so that the
  renderers agree: the visibility of an entity (`visible?`) and the search of a
  `combobox`.
  """
  @moduledoc group: "PyroManiac"

  require Ash.Expr
  require Logger

  alias PyroManiac.Dsl.Expression
  alias PyroManiac.Form.Combobox

  @doc """
  Whether an entity is visible: its `visible?` expression, evaluated in memory
  with the changeset of its form level and the actor.

  The record is the data of the changeset with the attribute changes
  applied. `^arg(:name)` gets the arguments of the changeset. `true` shows
  the entity, `false` and `nil` hide it. A result that is not known shows
  it (and logs a warning): a hidden input that must be visible is a data
  entry error that the user cannot see.

  `source` is an `Ash.Changeset`, or a map with a `:source` changeset (for
  example an `AshPhoenix.Form`).

  Options:

    * `:parent` - the changeset (or a map with a `:source` changeset) of the
      form one level up. `parent(field)` in the expression refers to its
      record. Without it, `parent(...)` is not known, and the entity shows.
  """
  @spec visible?(map(), Ash.Changeset.t() | map() | nil, term(), keyword()) :: boolean()
  def visible?(entity, source, actor, opts \\ [])

  def visible?(%{visible?: nil}, _source, _actor, _opts), do: true

  def visible?(entity, %{source: %Ash.Changeset{} = changeset}, actor, opts),
    do: visible?(entity, changeset, actor, opts)

  def visible?(%{visible?: condition}, %Ash.Changeset{} = changeset, actor, opts) do
    parent = parent_changeset(opts[:parent])
    filled = Expression.fill(condition, actor: actor, args: changeset.arguments)

    case Ash.Expr.eval(filled,
           record: applied_record(changeset),
           parent: parent && applied_record(parent),
           resource: changeset.resource,
           context: %{parent_stack: List.wrap(parent && parent.resource)},
           actor: actor,
           unknown_on_unknown_refs?: true
         ) do
      {:ok, value} when value in [false, nil] ->
        false

      {:ok, _value} ->
        true

      other ->
        Logger.warning(
          "PyroManiac: the `visible?` expression #{inspect(condition)} gave #{inspect(other)}. " <>
            "The entity is shown."
        )

        true
    end
  end

  def visible?(_entity, _source, _actor, _opts), do: true

  defp parent_changeset(%Ash.Changeset{} = changeset), do: changeset
  defp parent_changeset(%{source: %Ash.Changeset{} = changeset}), do: changeset
  defp parent_changeset(_other), do: nil

  # The data of the changeset with the attribute changes applied.
  defp applied_record(changeset) do
    case Ash.Changeset.apply_attributes(changeset, force?: true) do
      {:ok, record} -> record
      _ -> changeset.data
    end
  end

  @doc """
  Builds the query of a combobox. `search` is the typed text. `inputs` is a
  map of the values of the inputs at the same level (atom or string keys).

  The query uses `read_action`, the filled `argument` values, the `search`
  filter, the filled `filter`, `sort`, and `limit`. In free-text mode, it
  gets the different values of `value_key` that are not `nil`.
  """
  @spec combobox_query(Combobox.t(), String.t() | nil, map(), term()) :: Ash.Query.t()
  def combobox_query(%Combobox{} = combobox, search, inputs, scope) do
    search = search |> to_string() |> String.trim()
    {actor, tenant} = actor_and_tenant(scope)

    fill_opts = [
      actor: actor,
      tenant: tenant,
      search: search,
      inputs: input_values(combobox, inputs)
    ]

    arguments =
      Map.new(combobox.arguments, &{&1.name, Expression.fill(&1.value, fill_opts)})

    combobox.__resource__
    |> Ash.Query.for_read(combobox.read_action, arguments, scope_opts(scope))
    |> search_filter(combobox.search, search)
    |> extra_filter(combobox.filter, fill_opts)
    |> Ash.Query.sort(combobox.sort)
    |> Ash.Query.limit(combobox.limit)
    |> mode_query(combobox)
  end

  @doc """
  Runs `combobox_query/4` and returns the options as
  `[%{label: String.t(), value: String.t()}]`. Returns `[]` if the read
  fails (and logs a warning).
  """
  @spec combobox_options(Combobox.t(), String.t() | nil, map(), term()) :: [map()]
  def combobox_options(%Combobox{} = combobox, search, inputs, scope) do
    query = combobox_query(combobox, search, inputs, scope)

    case Ash.read(query, scope_opts(scope)) do
      {:ok, records} ->
        records
        |> Enum.map(fn record ->
          value = Map.get(record, combobox.value_key)
          label = Map.get(record, combobox.label_key)
          {label, value}
        end)
        |> Enum.reject(fn {_label, value} -> is_nil(value) end)
        |> Enum.map(fn {label, value} -> %{label: to_string(label), value: to_string(value)} end)
        |> Enum.uniq_by(& &1.value)

      {:error, error} ->
        Logger.warning(
          "PyroManiac: combobox #{inspect(combobox.name)} search failed: #{inspect(error)}"
        )

        []
    end
  end

  @doc """
  The label of the selected value of a combobox. In free-text mode, the
  label is the value. In select mode, it reads the record. Returns `nil` if
  there is no such record.
  """
  @spec combobox_label(Combobox.t(), term(), term()) :: String.t() | nil
  def combobox_label(_combobox, value, _scope) when value in [nil, ""], do: nil
  def combobox_label(%Combobox{__mode__: :free_text}, value, _scope), do: to_string(value)

  def combobox_label(%Combobox{} = combobox, value, scope) do
    combobox.__resource__
    |> Ash.Query.do_filter([{combobox.value_key, value}])
    |> Ash.Query.load([combobox.label_key])
    |> Ash.Query.limit(1)
    |> Ash.read(scope_opts(scope))
    |> case do
      {:ok, [record]} -> record |> Map.get(combobox.label_key) |> to_string()
      _ -> nil
    end
  rescue
    _ -> nil
  end

  # The typed text matches without regard to case: each field is cast to a
  # `:ci_string`.
  defp search_filter(query, fields, search)
       when is_list(fields) and fields != [] and search != "" do
    condition =
      fields
      |> Enum.map(fn field ->
        Ash.Expr.expr(contains(type(^Ash.Expr.ref(field), :ci_string), ^search))
      end)
      |> Enum.reduce(fn condition, acc -> Ash.Expr.expr(^acc or ^condition) end)

    Ash.Query.do_filter(query, condition)
  end

  defp search_filter(query, _fields, _search), do: query

  defp extra_filter(query, nil, _fill_opts), do: query

  defp extra_filter(query, filter, fill_opts),
    do: Ash.Query.do_filter(query, Expression.fill(filter, fill_opts))

  defp mode_query(query, %Combobox{__mode__: :free_text, value_key: key}) do
    query
    |> Ash.Query.do_filter(not: [{key, [is_nil: true]}])
    |> Ash.Query.distinct([key])
    |> Ash.Query.select([key])
  end

  defp mode_query(query, %Combobox{label_key: label_key}), do: Ash.Query.load(query, [label_key])

  defp input_values(%Combobox{__inputs__: names}, inputs) do
    inputs = inputs || %{}

    Map.new(names, fn name ->
      value = Map.get(inputs, name, Map.get(inputs, Atom.to_string(name)))
      {name, empty_to_nil(value)}
    end)
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp scope_opts(nil), do: []
  defp scope_opts(scope), do: [scope: scope]

  @doc false
  def actor_and_tenant(nil), do: {nil, nil}

  def actor_and_tenant(scope) do
    opts = Ash.Scope.to_opts(scope)
    {Keyword.get(opts, :actor), Keyword.get(opts, :tenant)}
  rescue
    _ -> {nil, nil}
  end
end
