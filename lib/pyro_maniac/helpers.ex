defmodule PyroManiac.Helpers do
  @moduledoc """
  Shared helpers used to implement your own PyroManiac components.
  """

  alias Ash.Page.{Offset, Keyset}

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
  @spec prev_page?(Offset.t() | Keyset.t() | term()) :: boolean()
  def prev_page?(%Offset{offset: 0}), do: false
  def prev_page?(%Keyset{after: nil}), do: false
  def prev_page?(_), do: true

  @doc """
  Returns the current page number (0-indexed).
  """
  @spec page_number(Offset.t() | Keyset.t()) :: non_neg_integer()
  def page_number(%Offset{offset: 0}), do: 0

  def page_number(%Offset{limit: limit, offset: offset}) do
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
  @spec page_count(Offset.t()) :: non_neg_integer()
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
  @spec page_info(Offset.t() | Keyset.t()) :: String.t()
  def page_info(%Offset{} = page) do
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
end
