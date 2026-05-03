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
  Toggles sort directly on the encoded sort param string.

  Operating on the encoded string (rather than parsed structures) avoids
  issues with Ash calculation expressions that don't stringify cleanly.
  Works with field paths like `"type.label"`.

  ## Modes

  The combination of `:multiple?` and `:toggle_nil?` selects one of three
  modes — designed to map onto plain / shift / ctrl click in a column header:

    * `multiple?: false, toggle_nil?: false` (default) — **isolate**. Drop
      all other sorts and sort by `field_path` alone. If `field_path` is
      already the sole sort, cycle: `:asc` → `:desc` → off. If it's part of
      a multi-sort, isolate it preserving its current direction.

    * `multiple?: true, toggle_nil?: false` — **append-or-flip**. Append
      `field_path` at `:asc` if absent. If present, flip `:asc` ↔ `:desc`
      preserving its position and nil ordering. **Never removes** —
      position is stable across repeated invocations.

    * `toggle_nil?: true` (regardless of `multiple?`) — **cycle nils**.
      Append `field_path` at `:asc_nils_first` if absent. If present, cycle
      its nil ordering preserving direction and position. **Never removes.**

  The nil-ordering cycle has two states per direction, matching what the
  encoding can distinguish (Postgres convention: `ASC` defaults to nulls
  last; `DESC` defaults to nulls first):

    * `:asc` ↔ `:asc_nils_first`
    * `:desc` ↔ `:desc_nils_last`

  ## Examples

  Isolate (plain click):

      iex> toggle_sort_param("name", "code", %{})
      "code"

      iex> toggle_sort_param("code", "code", %{})
      "-code"

      iex> toggle_sort_param("-code", "code", %{})
      ""

      iex> toggle_sort_param("name,code", "name", %{})
      "name"

  Append-or-flip (shift click) — position stable, never removes:

      iex> toggle_sort_param("name", "code", %{multiple?: true})
      "name,code"

      iex> toggle_sort_param("name,code", "name", %{multiple?: true})
      "-name,code"

      iex> toggle_sort_param("-name,code", "name", %{multiple?: true})
      "name,code"

  Cycle nils (ctrl click) — position stable, never removes:

      iex> toggle_sort_param("name,code", "name", %{toggle_nil?: true})
      "++name,code"

      iex> toggle_sort_param("++name,code", "name", %{toggle_nil?: true})
      "name,code"

      iex> toggle_sort_param("-name", "name", %{toggle_nil?: true})
      "--name"

      iex> toggle_sort_param("--name", "name", %{toggle_nil?: true})
      "-name"
  """
  def toggle_sort_param(current_param, field_path, opts \\ %{})

  def toggle_sort_param(current_param, field_path, opts) when is_binary(current_param) do
    multiple? = Map.get(opts, :multiple?, false)
    toggle_nil? = Map.get(opts, :toggle_nil?, false)

    parsed = parse_sort_param(current_param)

    new_sorts =
      cond do
        toggle_nil? -> apply_cycle_nils(parsed, field_path)
        multiple? -> apply_append_or_flip(parsed, field_path)
        true -> apply_isolate(parsed, field_path)
      end

    encode_sort(new_sorts)
  end

  def toggle_sort_param(_, field_path, _opts), do: field_path

  defp apply_isolate(parsed, field) do
    case parsed do
      [{^field, dir}] ->
        case cycle_plain_direction(dir) do
          nil -> []
          next -> [{field, next}]
        end

      _ ->
        case List.keyfind(parsed, field, 0) do
          nil -> [{field, :asc}]
          {^field, dir} -> [{field, dir}]
        end
    end
  end

  defp apply_append_or_flip(parsed, field) do
    case Enum.find_index(parsed, fn {f, _} -> f == field end) do
      nil ->
        parsed ++ [{field, :asc}]

      idx ->
        {_, dir} = Enum.at(parsed, idx)
        List.replace_at(parsed, idx, {field, flip_direction(dir)})
    end
  end

  defp apply_cycle_nils(parsed, field) do
    case Enum.find_index(parsed, fn {f, _} -> f == field end) do
      nil ->
        parsed ++ [{field, :asc_nils_first}]

      idx ->
        {_, dir} = Enum.at(parsed, idx)
        List.replace_at(parsed, idx, {field, cycle_nils(dir)})
    end
  end

  defp cycle_plain_direction(:asc), do: :desc
  defp cycle_plain_direction(:asc_nils_first), do: :desc_nils_first
  defp cycle_plain_direction(:asc_nils_last), do: :desc_nils_last
  defp cycle_plain_direction(:desc), do: nil
  defp cycle_plain_direction(:desc_nils_first), do: nil
  defp cycle_plain_direction(:desc_nils_last), do: nil

  defp flip_direction(:asc), do: :desc
  defp flip_direction(:asc_nils_first), do: :desc_nils_first
  defp flip_direction(:asc_nils_last), do: :desc_nils_last
  defp flip_direction(:desc), do: :asc
  defp flip_direction(:desc_nils_first), do: :asc_nils_first
  defp flip_direction(:desc_nils_last), do: :asc_nils_last

  # 2-state cycle matching the URL encoding (Postgres convention: ASC default
  # = nulls last; DESC default = nulls first), so `:asc_nils_last` and
  # `:desc_nils_first` aren't reachable from a default starting state.
  defp cycle_nils(:asc), do: :asc_nils_first
  defp cycle_nils(:asc_nils_first), do: :asc
  defp cycle_nils(:asc_nils_last), do: :asc_nils_first
  defp cycle_nils(:desc), do: :desc_nils_last
  defp cycle_nils(:desc_nils_first), do: :desc_nils_last
  defp cycle_nils(:desc_nils_last), do: :desc

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
