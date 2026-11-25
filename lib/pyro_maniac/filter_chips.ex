defmodule PyroManiac.FilterChips do
  @moduledoc """
  The active filters of a viewer as chips: "Supplier: Malt Masters ×". A
  chip of a relationship filter (the foreign key of a `belongs_to`, or the
  primary key of a related record) shows the label of the record, not its
  ID, and links to it with the `link_to` of the column.

  The filter is an Ash filter input (the filter of the viewer): a map of
  fields, with operator maps, relationship maps, and `and`, `or`, `not`.
  Each predicate of the top-level conjunction is a chip. An `or` or a `not`
  is one chip of kind `:group`.

      chips = PyroManiac.FilterChips.chips(view, Brewery.Ingredient, %{"supplier_id" => %{"eq" => id}})
      chips = PyroManiac.FilterChips.load_labels(chips, actor: actor)
      filter = PyroManiac.FilterChips.remove(chips, hd(chips).id)

  The renderer removes a chip with a `patch` to the filter of `remove/2`.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.View.View

  defmodule Chip do
    @moduledoc """
    One chip.

    - `id`: the position of the chip, for `PyroManiac.FilterChips.remove/2`.
    - `kind`: `:predicate`, or `:group` for an `or`, a `not`, or an unknown
      field.
    - `path`: the path of the field. `operator`: the Ash operator (`:eq`,
      `:in`, ...). `value`: the value of the filter.
    - `label`: the label of the field (the column label, else the path).
    - `record`: `{resource, ids}` when the value is the ID of records.
      `value_label`: their labels, after `load_labels/2`.
    - `link_to`: the link (`PyroManiac.LinkTo`) of the records: the
      `link_to` of the column, or `nil`.
    - `filter`: the filter input of the chip alone.
    """
    @moduledoc group: "PyroManiac"

    defstruct [
      :id,
      :path,
      :operator,
      :value,
      :label,
      :value_label,
      :record,
      :link_to,
      :filter,
      kind: :predicate
    ]

    @type t :: %__MODULE__{}
  end

  @boolean_keys ~w(and or not)

  @doc """
  The chips of a filter input on `resource`. `view` gives the labels and the
  `link_to` of the columns (or `nil`).
  """
  @spec chips(View.t() | nil, Ash.Resource.t(), map() | nil) :: [Chip.t()]
  def chips(_view, _resource, nil), do: []

  def chips(view, resource, filter) when is_map(filter) do
    filter
    |> conjuncts()
    |> Enum.flat_map(&fragment_chips(&1, view, resource))
    |> Enum.with_index()
    |> Enum.map(fn {chip, index} -> %{chip | id: index} end)
  end

  # The fragments of the top-level conjunction: one map for each key, and
  # each item of `and`.
  defp conjuncts(filter) do
    filter
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.flat_map(fn {key, value} ->
      if to_string(key) == "and" and is_list(value),
        do: Enum.flat_map(value, &conjuncts/1),
        else: [%{key => value}]
    end)
  end

  defp fragment_chips(fragment, view, resource) do
    [{key, value}] = Map.to_list(fragment)

    if to_string(key) in @boolean_keys,
      do: [group_chip(fragment)],
      else: field_chips(resource, [], [key], value, view)
  end

  # `keys` are the keys of the filter input from the top (atoms or strings,
  # as given), so the filter of a chip has the same keys.
  defp field_chips(resource, prefix, keys, value, view) do
    case to_existing_atom(List.last(keys)) do
      nil ->
        [group_chip(nest(keys, value))]

      name ->
        name_chips(resource, prefix ++ [name], keys, value, view)
    end
  end

  defp name_chips(resource, path, keys, value, view) do
    name = List.last(path)

    cond do
      (relationship = Ash.Resource.Info.relationship(resource, name)) && is_map(value) ->
        Enum.flat_map(value, fn {key, nested} ->
          field_chips(relationship.destination, path, keys ++ [key], nested, view)
        end)

      Ash.Resource.Info.field(resource, name) && is_map(value) ->
        Enum.map(value, &operator_chip(&1, resource, path, keys, view))

      Ash.Resource.Info.field(resource, name) ->
        [predicate_chip(resource, path, :eq, value, view, nest(keys, value))]

      true ->
        [group_chip(nest(keys, value))]
    end
  end

  defp operator_chip({operator, operand}, resource, path, keys, view) do
    filter = nest(keys, %{operator => operand})
    predicate_chip(resource, path, to_operator(operator), operand, view, filter)
  end

  defp predicate_chip(resource, path, operator, value, view, filter) do
    {record, column} = record_and_column(resource, path, operator, value, view)

    %Chip{
      path: path,
      operator: operator,
      value: value,
      label: chip_label(column, path),
      record: record,
      link_to: chip_link(record, column),
      filter: filter
    }
  end

  # The value is the ID of records: the foreign key of a `belongs_to`, or the
  # primary key of a related record.
  defp record_and_column(resource, path, operator, value, view)
       when operator in [:eq, :in] and not is_nil(value) do
    name = List.last(path)
    prefix = Enum.drop(path, -1)
    ids = List.wrap(value)

    record =
      case belongs_to_for(resource, name) do
        %{destination: destination, name: relationship} ->
          {destination, prefix ++ [relationship]}

        nil ->
          if prefix != [] and Ash.Resource.Info.primary_key(resource) == [name],
            do: {resource, prefix},
            else: nil
      end

    case record do
      nil -> {nil, column_for(view, path, nil)}
      {destination, record_path} -> {{destination, ids}, column_for(view, path, record_path)}
    end
  end

  defp record_and_column(_resource, path, _operator, _value, view),
    do: {nil, column_for(view, path, nil)}

  # The column of the path; for a record, also a column of the relationship
  # or of a field of the related record (for example `[:supplier, :name]`).
  defp column_for(nil, _path, _record_path), do: nil

  defp column_for(%View{columns: columns}, path, record_path) do
    columns = columns || []

    Enum.find(columns, &(List.wrap(&1.source) == path)) ||
      (record_path &&
         (Enum.find(columns, &(List.wrap(&1.source) == record_path)) ||
            Enum.find(columns, &List.starts_with?(List.wrap(&1.source), record_path))))
  end

  # The link of the records of a chip: the `link_to` of the column.
  defp chip_link({_destination, _ids}, column),
    do: PyroManiac.Link.link(column && column.link_to)

  defp chip_link(nil, _column), do: nil

  defp chip_label(%{label: [_ | _] = label}, path),
    do: PyroManiac.Content.text(label) || chip_label(nil, path)

  defp chip_label(_column, path), do: Enum.map_join(path, " ", &PyroManiac.Info.field_label/1)

  defp group_chip(fragment), do: %Chip{kind: :group, label: "Custom filter", filter: fragment}

  defp belongs_to_for(resource, name) do
    Enum.find(
      Ash.Resource.Info.relationships(resource),
      &match?(%Ash.Resource.Relationships.BelongsTo{source_attribute: ^name}, &1)
    )
  end

  defp nest(keys, leaf) do
    keys
    |> Enum.reverse()
    |> Enum.reduce(leaf, fn key, acc -> %{key => acc} end)
  end

  defp to_operator(operator) when is_atom(operator), do: operator
  defp to_operator(operator) when is_binary(operator), do: to_existing_atom(operator)

  @doc """
  The filter input without the chip `id`: the filters of the other chips,
  joined with `and`. `%{}` without a chip.
  """
  @spec remove([Chip.t()], non_neg_integer()) :: map()
  def remove(chips, id) do
    case for(%Chip{id: chip_id, filter: filter} <- chips, chip_id != id, do: filter) do
      [] -> %{}
      [filter] -> filter
      filters -> %{"and" => filters}
    end
  end

  @doc """
  Sets the `value_label` of each chip with a `record`: the `default_label`
  of the records, read with the primary read action of the destination and
  the options (`actor`, `tenant`, `authorize?`). One read for each resource.
  A record that the actor cannot read keeps its ID as the label.
  """
  @spec load_labels([Chip.t()], keyword()) :: [Chip.t()]
  def load_labels(chips, opts \\ []) do
    labels =
      chips
      |> Enum.flat_map(fn
        %Chip{record: {resource, ids}} -> Enum.map(ids, &{resource, &1})
        _ -> []
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {resource, ids} ->
        {resource, read_labels(resource, Enum.uniq(ids), opts)}
      end)

    Enum.map(chips, fn
      %Chip{record: {resource, ids}} = chip ->
        resource_labels = Map.get(labels, resource, %{})

        %{
          chip
          | value_label:
              Enum.map_join(ids, ", ", &Map.get(resource_labels, to_string(&1), to_string(&1)))
        }

      chip ->
        chip
    end)
  end

  defp read_labels(resource, ids, opts) do
    with [key] <- Ash.Resource.Info.primary_key(resource),
         %{name: action} <- Ash.Resource.Info.primary_action(resource, :read),
         {:ok, records} <-
           resource
           |> Ash.Query.for_read(action, %{}, Keyword.take(opts, [:actor, :tenant]))
           |> Ash.Query.filter_input(%{key => %{"in" => ids}})
           |> Ash.Query.load(PyroManiac.Info.default_label_load(resource))
           |> Ash.read(Keyword.take(opts, [:actor, :tenant, :authorize?])) do
      Map.new(records, fn record ->
        {to_string(Map.get(record, key)), PyroManiac.Resource.Info.record_label(resource, record)}
      end)
    else
      _ -> %{}
    end
  end

  defp to_existing_atom(key) when is_atom(key), do: key

  defp to_existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp to_existing_atom(_key), do: nil
end
