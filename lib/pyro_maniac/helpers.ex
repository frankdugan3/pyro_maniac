defmodule PyroManiac.Helpers do
  @moduledoc """
  Shared helpers used to implement your own PyroManiac components.
  """

  @doc """
  Stringifies the column sorting for storage in a url param.
  """
  def encode_sort(sort) do
    sort
    |> List.wrap()
    |> Enum.map_join(",", fn
      nil -> ""
      k when is_atom(k) -> "#{k}"
      k when is_binary(k) -> k
      {_k, nil} -> ""
      {k, :asc} -> "#{k}"
      {k, :asc_nils_last} -> "#{k}"
      {k, :asc_nils_first} -> "++#{k}"
      {k, :desc} -> "-#{k}"
      {k, :desc_nils_first} -> "-#{k}"
      {k, :desc_nils_last} -> "--#{k}"
    end)
  end

  @doc """
  Toggles the column sorting.
  """
  def toggle_sort(sort, sort_key, opts \\ %{}) do
    do_toggle_sort(sort, [], %{
      key: sort_key,
      multiple?: Map.get(opts, :multiple?, false),
      toggle_nil?: Map.get(opts, :toggle_nil?, false),
      toggled?: false
    })
  end

  @doc """
  Toggles sort directly on the sort param string.

  This avoids issues with Ash calculation expressions that can't be easily
  stringified. Works with field paths like "type.label".

  ## Examples

      iex> toggle_sort_param("name", "code", %{})
      "code"

      iex> toggle_sort_param("code", "code", %{})
      "-code"

      iex> toggle_sort_param("-code", "code", %{})
      "code"

      iex> toggle_sort_param("name", "code", %{multiple?: true})
      "name,code"
  """
  def toggle_sort_param(current_param, field_path, opts \\ %{})

  def toggle_sort_param(current_param, field_path, opts) when is_binary(current_param) do
    multiple? = Map.get(opts, :multiple?, false)
    toggle_nil? = Map.get(opts, :toggle_nil?, false)

    current_sorts = parse_sort_param(current_param)

    {existing_dir, other_sorts} = extract_field_sort(current_sorts, field_path)

    new_dir = next_direction(existing_dir, toggle_nil?, multiple?)

    new_sorts = build_sort_list(new_dir, field_path, other_sorts, multiple?)

    encode_sort(new_sorts)
  end

  def toggle_sort_param(_, field_path, _opts), do: field_path

  defp extract_field_sort(sorts, field_path) do
    Enum.reduce(sorts, {nil, []}, fn {f, dir}, {found, acc} ->
      if f == field_path, do: {dir, acc}, else: {found, [{f, dir} | acc]}
    end)
    |> then(fn {dir, others} -> {dir, Enum.reverse(others)} end)
  end

  defp next_direction(nil, false, _multiple?), do: :asc
  defp next_direction(nil, true, _multiple?), do: :asc_nils_first
  defp next_direction(:asc, false, _multiple?), do: :desc
  defp next_direction(:asc, true, _multiple?), do: :asc_nils_first
  defp next_direction(:asc_nils_first, _, _multiple?), do: :asc
  defp next_direction(:asc_nils_last, _, _multiple?), do: :asc_nils_first
  defp next_direction(:desc, false, multiple?), do: if(!multiple?, do: :asc)
  defp next_direction(:desc, true, _multiple?), do: :desc_nils_last
  defp next_direction(:desc_nils_first, _, _multiple?), do: :desc_nils_last
  defp next_direction(:desc_nils_last, _, _multiple?), do: :desc

  defp build_sort_list(nil, _field_path, _other_sorts, false), do: []
  defp build_sort_list(nil, _field_path, other_sorts, true), do: other_sorts
  defp build_sort_list(dir, field_path, _other_sorts, false), do: [{field_path, dir}]
  defp build_sort_list(dir, field_path, other_sorts, true), do: other_sorts ++ [{field_path, dir}]

  # Parse sort param string into list of {field_path, direction} tuples
  defp parse_sort_param(""), do: []

  defp parse_sort_param(param) when is_binary(param) do
    param
    |> String.split(",", trim: true)
    |> Enum.map(fn part ->
      part = String.trim(part)

      cond do
        String.starts_with?(part, "--") ->
          {String.slice(part, 2..-1//1), :desc_nils_last}

        String.starts_with?(part, "-") ->
          {String.slice(part, 1..-1//1), :desc}

        String.starts_with?(part, "++") ->
          {String.slice(part, 2..-1//1), :asc_nils_first}

        true ->
          {part, :asc}
      end
    end)
  end

  defp do_toggle_sort(sorts, acc, %{key: key} = opts) when is_atom(key) do
    do_toggle_sort(sorts, acc, %{opts | key: Atom.to_string(key)})
  end

  defp do_toggle_sort([{key, order} | rest], acc, opts) when is_atom(key) do
    do_toggle_sort([{Atom.to_string(key), order} | rest], acc, opts)
  end

  defp do_toggle_sort([{key, old_order} | rest], acc, %{key: key, toggle_nil?: true} = opts) do
    order =
      case old_order do
        :asc -> :asc_nils_first
        :asc_nils_first -> :asc
        :desc -> :desc_nils_last
        :desc_nils_last -> :desc
      end

    if opts.multiple? do
      do_toggle_sort(rest, [{key, order} | acc], %{opts | toggled?: true})
    else
      encode_sort({key, order})
    end
  end

  defp do_toggle_sort([{key, old_order} | rest], acc, %{key: key, multiple?: true} = opts) do
    order =
      case old_order do
        :asc -> :desc
        :desc -> nil
        :asc_nils_first -> :desc_nils_last
        :desc_nils_last -> nil
      end

    if order == nil do
      do_toggle_sort(rest, acc, %{opts | toggled?: true})
    else
      do_toggle_sort(rest, [{key, order} | acc], %{opts | toggled?: true})
    end
  end

  defp do_toggle_sort([{key, old_order} | _rest], _acc, %{key: key}) do
    order =
      case old_order do
        :asc -> :desc
        :desc -> :asc
        :asc_nils_first -> :desc_nils_last
        :desc_nils_last -> :asc_nils_first
      end

    encode_sort({key, order})
  end

  defp do_toggle_sort([sort | rest], acc, %{multiple?: true} = opts) do
    do_toggle_sort(rest, [sort | acc], opts)
  end

  defp do_toggle_sort([_sort | rest], acc, opts) do
    do_toggle_sort(rest, acc, opts)
  end

  defp do_toggle_sort([], acc, %{toggled?: toggled?} = opts)
       when toggled? == false or [] == acc do
    order = if opts.toggle_nil?, do: :asc_nils_first, else: :asc
    do_toggle_sort([], [{opts.key, order} | acc], %{opts | toggled?: true})
  end

  defp do_toggle_sort([], acc, _opts) do
    acc |> Enum.reverse() |> encode_sort()
  end

  @doc """
  Returns whether there is a previous page.
  """
  @spec prev_page?(Ash.Page.Offset.t() | Ash.Page.Keyset.t() | term()) :: boolean()
  def prev_page?(%Ash.Page.Offset{offset: 0}), do: false
  def prev_page?(%Ash.Page.Keyset{after: nil}), do: false
  def prev_page?(_), do: true

  @doc """
  Returns the current page number (0-indexed).
  """
  @spec page_number(Ash.Page.Offset.t() | Ash.Page.Keyset.t()) :: non_neg_integer()
  def page_number(%Ash.Page.Offset{offset: 0}), do: 0

  def page_number(%Ash.Page.Offset{limit: limit, offset: offset}) do
    if rem(offset, limit) == 0 do
      div(offset, limit)
    else
      div(offset, limit) + 1
    end
  end

  def page_number(_), do: raise("Need to implement keyset pagination!")

  @doc """
  Returns the total number of pages (0-indexed).
  """
  @spec page_count(Ash.Page.Offset.t()) :: non_neg_integer()
  def page_count(%{count: 0}), do: 0

  def page_count(%{count: count, limit: limit}) do
    if_result =
      if rem(count, limit) == 0 do
        div(count, limit)
      else
        div(count, limit) + 1
      end

    Kernel.-(if_result, 1)
  end

  @doc """
  Returns a human-readable string describing the current page.
  """
  @spec page_info(Ash.Page.Offset.t() | Ash.Page.Keyset.t()) :: String.t()
  def page_info(%Ash.Page.Offset{} = page) do
    n =
      page
      |> page_number()
      |> Kernel.+(1)
      |> floor()

    c =
      page
      |> page_count()
      |> Kernel.+(1)
      |> floor()

    t = floor(page.count)
    "Page #{n} of #{c} (#{t} total)"
  end

  def page_info(%{count: count}) when is_integer(count) do
    "(#{floor(count)} total)"
  end

  @doc """
  Safely get nested values from maps or keyword lists that may be `nil` or an otherwise non-map value at any point. Great for accessing nested assigns in a template.

  ## Examples

      iex> get_nested(nil, [:one, :two, :three])
      nil

      iex> get_nested(%{one: nil}, [:one, :two, :three])
      nil

      iex> get_nested(%{one: %{two: %{three: 3}}}, [:one, :two, :three])
      3

      iex> get_nested(%{one: %{two: [three: 3]}}, [:one, :two, :three])
      3

      iex> get_nested([one: :nope], [:one, :two, :three])
      nil

      iex> get_nested([one: :nope], [:one, :two, :three], :default)
      :default
  """
  def get_nested(value, keys, default \\ nil)
  def get_nested(value, [], _), do: value
  def get_nested(%{} = map, [key], default), do: Map.get(map, key, default)

  def get_nested(%{} = map, [key | keys], default),
    do: get_nested(Map.get(map, key), keys, default)

  def get_nested([_ | _] = keyword, [key], default), do: Keyword.get(keyword, key, default)

  def get_nested([_ | _] = keyword, [key | keys], default),
    do: get_nested(Keyword.get(keyword, key), keys, default)

  def get_nested(_, _, default), do: default

  @doc """
  Formats a byte count as a human-readable string.

  ## Examples

      iex> humanize_size(0)
      "0 B"

      iex> humanize_size(512)
      "512 B"

      iex> humanize_size(1024)
      "1 KB"

      iex> humanize_size(1_048_576)
      "1 MB"

      iex> humanize_size(1_536_000)
      "1.46 MB"
  """
  @spec humanize_size(non_neg_integer()) :: String.t()
  def humanize_size(bytes) when is_integer(bytes) and bytes >= 0 do
    {value, unit} = reduce_size(bytes / 1, ~w(B KB MB GB TB))

    if value == trunc(value) do
      "#{trunc(value)} #{unit}"
    else
      "#{:erlang.float_to_binary(value, decimals: 2)} #{unit}"
    end
  end

  defp reduce_size(value, [unit]), do: {value, unit}
  defp reduce_size(value, [unit | _]) when value < 1024, do: {value, unit}
  defp reduce_size(value, [_ | rest]), do: reduce_size(value / 1024, rest)
end
