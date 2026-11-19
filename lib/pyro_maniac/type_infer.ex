defmodule PyroManiac.TypeInfer do
  @moduledoc """
  Type inference and input formatting for PyroManiac form components.

  Provides type predicates, input type inference for Form and BulkForm contexts,
  and HTML input value formatting (ISO 8601 for date/datetime-local inputs).
  """

  @doc "Returns true if the Ash type is boolean."
  def boolean_type?(Ash.Type.Boolean), do: true
  def boolean_type?(:boolean), do: true
  def boolean_type?(_), do: false

  @doc "Returns true if the Ash type is a date."
  def date_type?(Ash.Type.Date), do: true
  def date_type?(:date), do: true
  def date_type?(_), do: false

  @doc "Returns true if the Ash type is a UTC/zoned datetime variant."
  def datetime_type?(Ash.Type.DateTime), do: true
  def datetime_type?(:datetime), do: true
  def datetime_type?(Ash.Type.UtcDatetime), do: true
  def datetime_type?(:utc_datetime), do: true
  def datetime_type?(Ash.Type.UtcDatetimeUsec), do: true
  def datetime_type?(:utc_datetime_usec), do: true
  def datetime_type?(:timestamptz_usec), do: true

  @ash_postgres_timestamptz_usec Module.concat([:AshPostgres, :TimestamptzUsec])
  if Code.ensure_loaded?(@ash_postgres_timestamptz_usec) do
    def datetime_type?(unquote(@ash_postgres_timestamptz_usec)), do: true
  end

  def datetime_type?(_), do: false

  @doc "Returns true if the Ash type is a naive (timezone-less) datetime."
  def naive_datetime_type?(Ash.Type.NaiveDatetime), do: true
  def naive_datetime_type?(:naive_datetime), do: true
  def naive_datetime_type?(_), do: false

  @doc "Returns true if the Ash type is a time-of-day."
  def time_type?(Ash.Type.Time), do: true
  def time_type?(:time), do: true
  def time_type?(Ash.Type.TimeUsec), do: true
  def time_type?(:time_usec), do: true
  def time_type?(_), do: false

  @doc "Returns true if the Ash type is an integer."
  def integer_type?(Ash.Type.Integer), do: true
  def integer_type?(:integer), do: true
  def integer_type?(_), do: false

  @doc "Returns true if the Ash type is a float or decimal."
  def float_type?(Ash.Type.Float), do: true
  def float_type?(:float), do: true
  def float_type?(Ash.Type.Decimal), do: true
  def float_type?(:decimal), do: true
  def float_type?(_), do: false

  @doc "Returns true if the Ash type is numeric (integer, float, or decimal)."
  def numeric_type?(type), do: integer_type?(type) || float_type?(type)

  @doc """
  Returns true if the Ash type is an interval/duration: `:interval`, or an
  `Ash.Type` module that stores an interval (`storage_type/1` is
  `:interval`), for example an application interval type.
  """
  def interval_type?(:interval), do: true

  def interval_type?(type) when is_atom(type) and not is_nil(type) do
    Ash.Type.ash_type?(type) and Ash.Type.storage_type(type, []) == :interval
  rescue
    _error -> false
  end

  def interval_type?(_), do: false

  @doc "Returns true if the Ash type is a long text type."
  def text_type?(Ash.Type.String), do: false
  def text_type?(:string), do: false
  def text_type?(Ash.Type.Text), do: true
  def text_type?(:text), do: true
  def text_type?(_), do: false

  @doc """
  The closed set of values of a type with its constraints, or `nil`.

  Each value is a map `%{value:, label:, description:}`, in the order of the
  type. The sources, in order:

  1. A `one_of` constraint.
  2. A `one_of` in the `items` constraints of an `{:array, type}`.
  3. An `Ash.Type.NewType`: its own constraints (`subtype_constraints/0`),
     merged with the given constraints, then rules 1 and 2 for its
     `subtype_of/0`.
  4. An `Ash.Type.Enum` (`values/0`, with `label/1` and `description/1`).

  ## Examples

      iex> PyroManiac.TypeInfer.closed_values(:atom, one_of: [:open, :closed_now])
      [%{value: :open, label: "open", description: nil}, %{value: :closed_now, label: "closed now", description: nil}]

      iex> PyroManiac.TypeInfer.closed_values({:array, :atom}, items: [one_of: [:a]])
      [%{value: :a, label: "a", description: nil}]

      iex> PyroManiac.TypeInfer.closed_values(:string, [])
      nil
  """
  @spec closed_values(term(), keyword()) :: [map()] | nil
  def closed_values(type, constraints \\ [])

  def closed_values(type, constraints) when is_list(constraints) do
    do_closed_values(normalize_type(type), constraints)
  end

  def closed_values(type, _constraints), do: closed_values(type, [])

  defp do_closed_values({:array, inner}, constraints) do
    item_constraints = Keyword.get(constraints, :items, [])

    item_constraints =
      case Keyword.fetch(constraints, :one_of) do
        {:ok, values} -> Keyword.put_new(item_constraints, :one_of, values)
        :error -> item_constraints
      end

    do_closed_values(normalize_type(inner), item_constraints)
  end

  defp do_closed_values(type, constraints) do
    cond do
      is_list(constraints[:one_of]) and constraints[:one_of] != [] ->
        Enum.map(constraints[:one_of], &option(type, &1))

      new_type?(type) ->
        merged = Keyword.merge(type.subtype_constraints(), constraints)
        do_closed_values(normalize_type(Ash.Type.NewType.subtype_of(type)), merged)

      custom_enum?(type) ->
        Enum.map(type.values(), &option(type, &1))

      true ->
        nil
    end
  end

  defp option(type, value) do
    %{value: value, label: enum_label(type, value), description: enum_description(type, value)}
  end

  defp normalize_type({:array, inner}), do: {:array, inner}
  defp normalize_type(type) when is_atom(type), do: Ash.Type.get_type(type)
  defp normalize_type(type), do: type

  defp new_type?(type) when is_atom(type) do
    Code.ensure_loaded?(type) and Ash.Type.NewType.new_type?(type) and
      function_exported?(type, :subtype_constraints, 0)
  end

  defp new_type?(_), do: false

  defp enum_description(type, value) when is_atom(type) do
    if custom_enum?(type) and function_exported?(type, :description, 1),
      do: type.description(value)
  end

  defp enum_description(_, _), do: nil

  @doc "Returns true if the attribute info has a closed set of values."
  def enum_type?(attr_info) do
    closed_values(attr_info.type, Map.get(attr_info, :constraints) || []) != nil
  end

  @doc "Returns true if the attribute info is an array with a closed set of values."
  def array_enum_type?(%{type: {:array, _}} = attr_info), do: enum_type?(attr_info)
  def array_enum_type?(_), do: false

  @doc "Returns true if the type has a closed set of values."
  def has_enum_values?(type, constraints), do: closed_values(type, constraints || []) != nil

  @doc "Returns the closed set of values of a type, or nil."
  def enum_values(type, constraints \\ []) do
    case closed_values(type, constraints || []) do
      nil -> nil
      options -> Enum.map(options, & &1.value)
    end
  end

  @doc """
  Infer the input type for a Form field.

  Returns atoms like `:boolean`, `:select`, `:number`, `:date`, `:datetime`,
  `:naive_datetime`, `:time`, or `:text`. Array-of-enum is resolved as
  `:select` (the `multiple?` flag on the field carries the multi-valued bit).
  """
  def infer_input_type(_field, nil), do: :text

  def infer_input_type(field, attr_info) do
    cond do
      boolean_type?(attr_info.type) -> :boolean
      array_enum_type?(attr_info) or enum_type?(attr_info) -> :select
      true -> temporal_or_number_type(attr_info.type) || infer_from_field_name(field)
    end
  end

  defp temporal_or_number_type(type) do
    cond do
      numeric_type?(type) -> :number
      date_type?(type) -> :date
      naive_datetime_type?(type) -> :naive_datetime
      datetime_type?(type) -> :datetime
      time_type?(type) -> :time
      interval_type?(type) -> :interval
      true -> nil
    end
  end

  @doc """
  Determine the input type for a BulkForm field.

  Returns atoms like `:checkbox`, `:select`, `:textarea`, `:number`,
  `:date`, `:datetime`, or `:text`.
  """
  def determine_bulk_input_type(%{constraints: constraints, type: type}) do
    cond do
      boolean_type?(type) -> :checkbox
      has_enum_values?(type, constraints) -> :select
      text_type?(type) -> :textarea
      numeric_type?(type) -> :number
      date_type?(type) -> :date
      datetime_type?(type) -> :datetime
      true -> :text
    end
  end

  @doc "Format a date value for an HTML `<input type=\"date\">` (ISO 8601)."
  def format_date_for_input(nil), do: ""
  def format_date_for_input(%Date{} = date), do: Date.to_iso8601(date)
  def format_date_for_input(value), do: to_string(value)

  @doc "Format a datetime value for an HTML `<input type=\"datetime-local\">` (ISO 8601, truncated to minutes)."
  def format_datetime_for_input(nil), do: ""

  def format_datetime_for_input(%DateTime{} = dt) do
    dt |> DateTime.to_naive() |> NaiveDateTime.to_iso8601() |> String.slice(0, 16)
  end

  def format_datetime_for_input(%NaiveDateTime{} = dt) do
    dt |> NaiveDateTime.to_iso8601() |> String.slice(0, 16)
  end

  def format_datetime_for_input(value), do: to_string(value)

  @doc "Format a datetime value as a full UTC ISO 8601 string (for hidden input backing the .PyroDatetime hook)."
  def format_utc_for_input(nil), do: ""

  def format_utc_for_input(%DateTime{} = dt),
    do: dt |> DateTime.truncate(:millisecond) |> DateTime.to_iso8601()

  def format_utc_for_input(%NaiveDateTime{} = dt),
    do: (dt |> NaiveDateTime.truncate(:millisecond) |> NaiveDateTime.to_iso8601()) <> "Z"

  def format_utc_for_input(value), do: to_string(value)

  @base_filter_types %{
    :atom => :enum,
    :boolean => :boolean,
    :date => :date,
    :datetime => :utc_datetime,
    :decimal => :decimal,
    :float => :decimal,
    :integer => :integer,
    :timestamptz_usec => :utc_datetime,
    :utc_datetime => :utc_datetime,
    :utc_datetime_usec => :utc_datetime,
    :uuid => :string,
    Ash.Type.Atom => :enum,
    Ash.Type.Boolean => :boolean,
    Ash.Type.Date => :date,
    Ash.Type.DateTime => :utc_datetime,
    Ash.Type.Decimal => :decimal,
    Ash.Type.Float => :decimal,
    Ash.Type.Integer => :integer,
    Ash.Type.UUID => :string,
    Ash.Type.UtcDatetime => :utc_datetime,
    Ash.Type.UtcDatetimeUsec => :utc_datetime
  }

  @filter_types (if Code.ensure_loaded?(@ash_postgres_timestamptz_usec) do
                   Map.put(@base_filter_types, @ash_postgres_timestamptz_usec, :utc_datetime)
                 else
                   @base_filter_types
                 end)

  @doc "Get the display label for an enum value given its type."
  def enum_label(type, value) when is_atom(type) and is_atom(value) do
    if Code.ensure_loaded?(type) && function_exported?(type, :label, 1) do
      type.label(value)
    else
      fallback_label(value)
    end
  end

  def enum_label(_, value), do: fallback_label(value)

  @doc "Get `{label, value}` options for a closed set of values (see `closed_values/2`)."
  def enum_options(type, constraints \\ []) do
    case closed_values(type, constraints || []) do
      nil -> nil
      options -> Enum.map(options, &{&1.label, &1.value})
    end
  end

  @doc false
  def fallback_label(value) when is_atom(value) do
    value |> Atom.to_string() |> String.replace("_", " ")
  end

  def fallback_label(value) when is_binary(value) do
    String.replace(value, "_", " ")
  end

  def fallback_label(value), do: to_string(value)

  @doc "Map an Ash type to a filter input type atom."
  def filter_type(type, constraints \\ [])

  def filter_type(type, constraints) when is_atom(type) do
    if has_enum_values?(type, constraints) do
      :enum
    else
      Map.get(@filter_types, type, :string)
    end
  end

  def filter_type({:array, _}, _), do: :string
  def filter_type(_, _), do: :string

  defp custom_enum?(type) when is_atom(type) do
    Code.ensure_loaded?(type) && function_exported?(type, :values, 0)
  end

  defp custom_enum?({:array, type}) when is_atom(type), do: custom_enum?(type)
  defp custom_enum?(_), do: false

  defp infer_from_field_name(%{__struct__: Phoenix.HTML.FormField, field: name})
       when is_atom(name) do
    name_str = Atom.to_string(name)

    cond do
      String.ends_with?(name_str, "_at") -> :datetime
      String.ends_with?(name_str, "_date") -> :date
      String.ends_with?(name_str, "_on") -> :date
      name in [:email, :email_address] -> :email
      name in [:password, :password_confirmation] -> :password
      true -> :text
    end
  end

  defp infer_from_field_name(_), do: :text
end
