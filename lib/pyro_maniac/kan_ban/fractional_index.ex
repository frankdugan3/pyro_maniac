defmodule PyroManiac.KanBan.FractionalIndex do
  @moduledoc """
  Fractional indexing for kanban card ordering.

  Exact port of the canonical algorithm by David Greenspan (Figma/rocicorp).
  Generates lexicographically sortable string keys that can be inserted
  between any two existing keys without rebalancing.

  Requires byte-order comparison (Elixir default, PostgreSQL `COLLATE "C"`).

  ## Key Structure

  Keys have a variable-length integer part followed by a fractional part.
  The integer part length is encoded in the first character:

  - Uppercase head (`A`-`Z`): length = `?Z - head + 2` (A=27, Z=2)
  - Lowercase head (`a`-`z`): length = `head - ?a + 2` (a=2, z=27)

  The default/zero key is `"a0"`. The integer space alone provides
  enormous headroom (62^26 positions in each direction).
  """

  @base_digits "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  @base String.length(@base_digits)

  @smallest_integer String.duplicate("0", 26) |> then(&("A" <> &1))
  @largest_integer String.duplicate("z", 26) |> then(&("z" <> &1))
  @integer_zero "a0"

  @doc """
  Generate a key between `a` and `b`.

  - `generate_key_between(nil, nil)` — returns `"a0"`
  - `generate_key_between(nil, b)` — returns a key before `b`
  - `generate_key_between(a, nil)` — returns a key after `a`
  - `generate_key_between(a, b)` — returns a key between `a` and `b`
  """
  @spec generate_key_between(String.t() | nil, String.t() | nil) :: String.t()
  def generate_key_between(a, b) do
    if a != nil, do: validate_order_key!(a)
    if b != nil, do: validate_order_key!(b)

    if a != nil and b != nil and a >= b do
      raise ArgumentError, "a (#{inspect(a)}) must be less than b (#{inspect(b)})"
    end

    do_generate(a, b)
  end

  defp do_generate(nil, nil), do: @integer_zero
  defp do_generate(nil, b), do: key_before(b)
  defp do_generate(a, nil), do: key_after(a)
  defp do_generate(a, b), do: key_between(a, b)

  defp key_before(b) do
    ib = get_integer_part(b)
    fb = String.slice(b, String.length(ib), String.length(b))

    cond do
      ib == @smallest_integer -> ib <> midpoint("", fb)
      decremented = decrement_integer(ib) -> decremented
      true -> raise ArgumentError, "cannot decrement past smallest integer"
    end
  end

  defp key_after(a) do
    ia = get_integer_part(a)
    fa = String.slice(a, String.length(ia), String.length(a))

    case increment_integer(ia) do
      nil -> ia <> midpoint(fa, nil)
      incremented -> incremented
    end
  end

  defp key_between(a, b) do
    ia = get_integer_part(a)
    fa = String.slice(a, String.length(ia), String.length(a))
    ib = get_integer_part(b)
    fb = String.slice(b, String.length(ib), String.length(b))

    if ia == ib do
      ia <> midpoint(fa, fb)
    else
      key_between_diff_int(a, b, ia, fa)
    end
  end

  defp key_between_diff_int(a, b, ia, fa) do
    case increment_integer(ia) do
      nil -> raise ArgumentError, "cannot increment integer part of #{inspect(a)}"
      incremented when incremented < b -> incremented
      _ -> ia <> midpoint(fa, nil)
    end
  end

  @doc """
  Generate `n` evenly-spaced keys between `a` and `b`.
  """
  @spec generate_n_keys_between(String.t() | nil, String.t() | nil, non_neg_integer()) ::
          [String.t()]
  def generate_n_keys_between(_a, _b, 0), do: []

  def generate_n_keys_between(a, b, n) when is_nil(b) do
    c = generate_key_between(a, b)

    if n == 1 do
      [c]
    else
      [c | generate_n_keys_between(c, b, n - 1)]
    end
  end

  def generate_n_keys_between(a, b, n) when is_nil(a) do
    c = generate_key_between(a, b)

    if n == 1 do
      [c]
    else
      generate_n_keys_between(a, c, n - 1) ++ [c]
    end
  end

  def generate_n_keys_between(a, b, n) do
    mid = div(n, 2)
    c = generate_key_between(a, b)

    generate_n_keys_between(a, c, mid) ++ [c] ++ generate_n_keys_between(c, b, n - mid - 1)
  end

  defp get_integer_part(key) do
    head = :binary.at(key, 0)
    int_len = get_integer_length(head)

    if int_len > String.length(key) do
      raise ArgumentError,
            "invalid order key head: #{<<head>>} in #{inspect(key)}"
    end

    String.slice(key, 0, int_len)
  end

  defp get_integer_length(head) when head >= ?a and head <= ?z, do: head - ?a + 2
  defp get_integer_length(head) when head >= ?A and head <= ?Z, do: ?Z - head + 2

  defp get_integer_length(head) do
    raise ArgumentError, "invalid order key head: #{<<head>>}"
  end

  defp validate_order_key!(key) do
    if key == @smallest_integer or key == @largest_integer do
      raise ArgumentError,
            "order key is the boundary value #{inspect(key)}, use nil instead"
    end

    head = :binary.at(key, 0)
    int_len = get_integer_length(head)

    if int_len != min(String.length(key), int_len) do
      raise ArgumentError, "invalid order key: #{inspect(key)}"
    end
  end

  defp increment_integer(x) do
    validate_integer!(x)
    if x != @largest_integer, do: do_increment(x)
  end

  defp decrement_integer(x) do
    validate_integer!(x)
    if x != @smallest_integer, do: do_decrement(x)
  end

  defp validate_integer!(x) do
    if String.length(x) != get_integer_length(:binary.at(x, 0)) do
      raise ArgumentError, "invalid integer: #{inspect(x)}"
    end
  end

  defp do_increment(x) do
    chars = String.to_charlist(x)
    {head, digits} = {hd(chars), tl(chars)}

    case carry_digits(digits, 1) do
      {:ok, new_digits} -> <<head>> <> List.to_string(new_digits)
      :overflow -> increment_overflow(head)
    end
  end

  defp increment_overflow(?Z), do: "a0"

  defp increment_overflow(head) when head < ?z do
    new_head = head + 1
    new_len = get_integer_length(new_head)
    <<new_head>> <> String.duplicate(<<digit_at(0)>>, new_len - 1)
  end

  defp increment_overflow(_head), do: nil

  defp do_decrement(x) do
    chars = String.to_charlist(x)
    {head, digits} = {hd(chars), tl(chars)}

    case carry_digits(digits, -1) do
      {:ok, new_digits} -> <<head>> <> List.to_string(new_digits)
      :overflow -> decrement_overflow(head)
    end
  end

  defp decrement_overflow(?a),
    do: "Z" <> String.duplicate(<<digit_at(@base - 1)>>, get_integer_length(?Z) - 1)

  defp decrement_overflow(head) when head > ?A do
    new_head = head - 1
    new_len = get_integer_length(new_head)
    <<new_head>> <> String.duplicate(<<digit_at(@base - 1)>>, new_len - 1)
  end

  defp decrement_overflow(_head), do: nil

  defp carry_digits(digits, delta) do
    digits
    |> Enum.reverse()
    |> do_carry(delta, [])
  end

  defp do_carry([], _carry, _acc), do: :overflow

  defp do_carry([d | rest], carry, acc) do
    val = digit_value(d) + carry

    cond do
      val >= 0 and val < @base ->
        {:ok, Enum.reverse(rest, [digit_at(val) | acc])}

      val >= @base ->
        do_carry(rest, 1, [digit_at(val - @base) | acc])

      true ->
        do_carry(rest, -1, [digit_at(val + @base) | acc])
    end
  end

  defp midpoint(a, b) do
    a_digits = for <<c <- a>>, do: digit_value(c)
    b_digits = if b, do: for(<<c <- b>>, do: digit_value(c))
    compute_midpoint(a_digits, b_digits, 0, [])
  end

  defp compute_midpoint(a_digits, b_digits, pos, acc) do
    a_val = Enum.at(a_digits, pos, 0)

    b_val =
      cond do
        b_digits == nil -> @base
        pos < length(b_digits) -> Enum.at(b_digits, pos)
        true -> 0
      end

    cond do
      a_val == b_val ->
        compute_midpoint(a_digits, b_digits, pos + 1, [a_val | acc])

      b_val - a_val > 1 ->
        mid = div(a_val + b_val, 2)

        acc
        |> Enum.reverse([mid])
        |> Enum.map(&digit_at/1)
        |> IO.iodata_to_binary()

      true ->
        # Gap is exactly 1. Take a_val and recurse with b=nil (open-ended)
        compute_midpoint(a_digits, nil, pos + 1, [a_val | acc])
    end
  end

  defp digit_value(char) when is_integer(char) do
    case :binary.match(@base_digits, <<char>>) do
      {pos, 1} -> pos
      :nomatch -> raise ArgumentError, "invalid base62 digit: #{<<char>>}"
    end
  end

  defp digit_at(val) when val >= 0 and val < @base do
    :binary.at(@base_digits, val)
  end
end
