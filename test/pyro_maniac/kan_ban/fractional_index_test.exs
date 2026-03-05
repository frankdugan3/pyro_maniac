defmodule PyroManiac.KanBan.FractionalIndexTest do
  use ExUnit.Case, async: true

  alias PyroManiac.KanBan.FractionalIndex, as: FI

  describe "generate_key_between/2" do
    test "nil, nil returns a0" do
      assert FI.generate_key_between(nil, nil) == "a0"
    end

    test "a0, nil returns a1" do
      assert FI.generate_key_between("a0", nil) == "a1"
    end

    test "nil, a0 returns Zz" do
      assert FI.generate_key_between(nil, "a0") == "Zz"
    end

    test "a0, a1 returns midpoint" do
      result = FI.generate_key_between("a0", "a1")
      assert result > "a0"
      assert result < "a1"
    end

    test "nil, a1 returns a0" do
      assert FI.generate_key_between(nil, "a1") == "a0"
    end

    test "between adjacent integers uses fractional" do
      result = FI.generate_key_between("a0", "a1")
      assert String.starts_with?(result, "a0")
      assert String.length(result) > 2
    end

    test "sequential appends produce sorted unique keys" do
      keys =
        Enum.reduce(1..200, {nil, []}, fn _, {prev, acc} ->
          key = FI.generate_key_between(prev, nil)
          {key, [key | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()

      assert keys == Enum.sort(keys)
      assert length(keys) == length(Enum.uniq(keys))
    end

    test "sequential prepends produce sorted unique keys" do
      keys =
        Enum.reduce(1..200, {nil, []}, fn _, {next, acc} ->
          key = FI.generate_key_between(nil, next)
          {key, [key | acc]}
        end)
        |> elem(1)

      assert keys == Enum.sort(keys)
      assert length(keys) == length(Enum.uniq(keys))
    end

    test "append keys stay short" do
      keys =
        Enum.reduce(1..100, {nil, []}, fn _, {prev, acc} ->
          key = FI.generate_key_between(prev, nil)
          {key, [key | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()

      max_len = keys |> Enum.map(&String.length/1) |> Enum.max()
      assert max_len <= 4
    end

    test "prepend keys stay short" do
      keys =
        Enum.reduce(1..100, {nil, []}, fn _, {next, acc} ->
          key = FI.generate_key_between(nil, next)
          {key, [key | acc]}
        end)
        |> elem(1)

      max_len = keys |> Enum.map(&String.length/1) |> Enum.max()
      assert max_len <= 4
    end

    test "worst case insertion grows logarithmically" do
      {_, final} =
        Enum.reduce(1..50, {"a0", "a1"}, fn _, {a, b} ->
          key = FI.generate_key_between(a, b)
          {a, key}
        end)

      assert String.length(final) <= 14
    end

    test "raises when a >= b" do
      assert_raise ArgumentError, ~r/must be less than/, fn ->
        FI.generate_key_between("a1", "a0")
      end
    end

    test "raises when a == b" do
      assert_raise ArgumentError, ~r/must be less than/, fn ->
        FI.generate_key_between("a0", "a0")
      end
    end

    test "integer part transitions Z to a correctly" do
      result = FI.generate_key_between("Zz", nil)
      assert result == "a0"
    end

    test "integer part transitions a to Z correctly" do
      result = FI.generate_key_between(nil, "a0")
      assert result == "Zz"
    end

    test "handles multi-char integer parts" do
      a = FI.generate_key_between("az", nil)
      assert String.length(a) == 3
      assert a > "az"
    end

    test "mixed operations maintain sort order" do
      a = FI.generate_key_between(nil, nil)
      b = FI.generate_key_between(a, nil)
      c = FI.generate_key_between(a, b)
      d = FI.generate_key_between(nil, a)
      e = FI.generate_key_between(c, b)

      keys = [a, b, c, d, e]
      assert Enum.sort(keys) == [d, a, c, e, b]
    end
  end

  describe "generate_n_keys_between/3" do
    test "0 keys returns empty list" do
      assert FI.generate_n_keys_between(nil, nil, 0) == []
    end

    test "1 key returns single key" do
      keys = FI.generate_n_keys_between(nil, nil, 1)
      assert length(keys) == 1
    end

    test "n keys are sorted and unique" do
      for n <- [2, 5, 10, 20, 50] do
        keys = FI.generate_n_keys_between(nil, nil, n)
        assert length(keys) == n, "expected #{n} keys, got #{length(keys)}"
        assert keys == Enum.sort(keys), "keys not sorted for n=#{n}"
        assert length(keys) == length(Enum.uniq(keys)), "duplicate keys for n=#{n}"
      end
    end

    test "keys between existing bounds are within bounds" do
      keys = FI.generate_n_keys_between("a0", "a5", 4)
      assert length(keys) == 4
      assert Enum.all?(keys, fn k -> k > "a0" and k < "a5" end)
      assert keys == Enum.sort(keys)
    end

    test "append mode produces sequential keys" do
      keys = FI.generate_n_keys_between("a0", nil, 5)
      assert length(keys) == 5
      assert Enum.all?(keys, fn k -> k > "a0" end)
      assert keys == Enum.sort(keys)
    end

    test "prepend mode produces sequential keys" do
      keys = FI.generate_n_keys_between(nil, "a5", 5)
      assert length(keys) == 5
      assert Enum.all?(keys, fn k -> k < "a5" end)
      assert keys == Enum.sort(keys)
    end
  end

  describe "key ordering matches Elixir binary comparison" do
    test "base62 digits are in ASCII codepoint order" do
      digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
      chars = String.graphemes(digits)
      assert chars == Enum.sort(chars)
    end

    test "generated keys sort correctly with Elixir default comparison" do
      keys = FI.generate_n_keys_between(nil, nil, 100)
      assert keys == Enum.sort(keys)
    end
  end

  describe "validation" do
    test "rejects invalid head character" do
      assert_raise ArgumentError, ~r/invalid order key head/, fn ->
        FI.generate_key_between("00", nil)
      end
    end

    test "rejects key that is too short for its head" do
      assert_raise ArgumentError, fn ->
        FI.generate_key_between("b", nil)
      end
    end
  end
end
