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

  @doc "Returns true if the Ash type is a datetime variant."
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

  @doc "Returns true if the Ash type is an interval/duration."
  def interval_type?(:interval), do: true
  def interval_type?(_), do: false

  @doc "Returns true if the Ash type is a long text type."
  def text_type?(Ash.Type.String), do: false
  def text_type?(:string), do: false
  def text_type?(Ash.Type.Text), do: true
  def text_type?(:text), do: true
  def text_type?(_), do: false

  @doc "Returns true if the attribute info represents an enum."
  def enum_type?(attr_info) do
    has_one_of_constraint?(attr_info) || custom_enum?(attr_info.type)
  end

  @doc "Returns true if the attribute info represents an array enum."
  def array_enum_type?(%{type: {:array, _}} = attr_info), do: enum_type?(attr_info)
  def array_enum_type?(_), do: false

  @doc "Returns true if the type has enum values (one_of constraint or custom enum)."
  def has_enum_values?(type, constraints) do
    constraints[:one_of] != nil ||
      (is_atom(type) && Code.ensure_loaded?(type) && function_exported?(type, :values, 0))
  end

  @doc "Returns enum values for a type, or nil. Accepts optional constraints."
  def enum_values(type, constraints \\ [])

  def enum_values(type, constraints) when is_atom(type) do
    case Keyword.get(constraints, :one_of) do
      values when is_list(values) and values != [] -> values
      _ -> if custom_enum?(type), do: type.values()
    end
  end

  def enum_values(_, _), do: nil

  @doc """
  Infer the input type for a Form field.

  Returns atoms like `:boolean_radio`, `:multi_select`, `:select`, `:number`,
  `:date`, `:datetime`, or `:text`.
  """
  def infer_input_type(_field, nil), do: :text

  def infer_input_type(field, attr_info) do
    cond do
      boolean_type?(attr_info.type) -> :boolean_radio
      array_enum_type?(attr_info) -> :multi_select
      enum_type?(attr_info) -> :select
      numeric_type?(attr_info.type) -> :number
      date_type?(attr_info.type) -> :date
      datetime_type?(attr_info.type) -> :datetime
      interval_type?(attr_info.type) -> :interval
      true -> infer_from_field_name(field)
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

  @doc "Get `{label, value}` options for an enum type or `one_of` constraint."
  def enum_options(type, constraints \\ [])

  def enum_options({:array, inner}, constraints) when is_atom(inner),
    do: enum_options(inner, constraints)

  def enum_options(type, constraints) do
    cond do
      values = constraints[:one_of] ->
        Enum.map(values, fn v -> {fallback_label(v), v} end)

      is_atom(type) && Code.ensure_loaded?(type) && function_exported?(type, :values, 0) ->
        Enum.map(type.values(), fn v -> {enum_label(type, v), v} end)

      true ->
        nil
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
    if Keyword.has_key?(constraints, :one_of) do
      :enum
    else
      Map.get_lazy(@filter_types, type, fn -> filter_type_for_atom(type) end)
    end
  end

  def filter_type({:array, _}, _), do: :string
  def filter_type(_, _), do: :string

  defp filter_type_for_atom(type) do
    if custom_enum?(type), do: :enum, else: :string
  end

  defp has_one_of_constraint?(attr_info) do
    attr_info.constraints[:one_of] != nil
  end

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
