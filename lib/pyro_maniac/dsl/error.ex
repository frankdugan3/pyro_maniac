defmodule PyroManiac.Dsl.Error do
  @moduledoc false

  alias Spark.Error.DslError

  @doc """
  Raise a `Spark.Error.DslError` with a body composed from `:why`, optional
  `:suggestions`, and optional `:fix`.

  Required opts:

    * `:module` — the module being compiled.
    * `:path` — Spark DSL path with entity names; e.g. `[:views, :view, :read, :column, :foo]`.
    * `:why` — sentence describing what's wrong, with offending values inlined.

  Optional opts:

    * `:location` — `:erl_anno.anno()` from `Spark.Dsl.Entity.anno/1`,
      `Spark.Dsl.Entity.property_anno/2`, `Spark.Dsl.Transformer.get_opt_anno/3`, or
      `Spark.Dsl.Transformer.get_section_anno/2`.
    * `:suggestions` — list of atoms or strings produced by `did_you_mean/3`.
    * `:fix` — sentence describing the remediation, included only when the fix isn't
      obvious from `:why`.
  """
  @spec raise!(keyword()) :: no_return()
  def raise!(opts), do: raise(build(opts))

  @doc """
  Build a `Spark.Error.DslError` exception. Use from verifiers that return
  `{:error, exception}`. See `raise!/1` for accepted options.
  """
  @spec build(keyword()) :: DslError.t()
  def build(opts) do
    DslError.exception(
      module: Keyword.fetch!(opts, :module),
      location: opts[:location],
      path: opts[:path] || [],
      message: compose_body(opts)
    )
  end

  @doc """
  Names from `candidates` that look like typos of `target`, ranked by
  Jaro distance.

  Options:

    * `:threshold` — minimum similarity, default `0.75`.
    * `:max` — maximum number of suggestions, default `3`.

  Atoms and strings are compared by their string form.
  """
  @spec did_you_mean(atom() | String.t(), [atom() | String.t()], keyword()) ::
          [atom() | String.t()]
  def did_you_mean(target, candidates, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.75)
    max = Keyword.get(opts, :max, 3)
    target_str = stringify(target)

    candidates
    |> Enum.reject(&(stringify(&1) == target_str))
    |> Enum.map(&{&1, String.jaro_distance(target_str, stringify(&1))})
    |> Enum.filter(fn {_c, d} -> d >= threshold end)
    |> Enum.sort_by(fn {c, d} -> {-d, stringify(c)} end)
    |> Enum.take(max)
    |> Enum.map(&elem(&1, 0))
  end

  defp compose_body(opts) do
    why = Keyword.fetch!(opts, :why)
    suggestions = suggestions_block(opts[:suggestions])
    fix = fix_block(opts[:fix])

    [why, suggestions, fix]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
    |> indent_continuation_lines("  ")
  end

  defp suggestions_block(nil), do: nil
  defp suggestions_block([]), do: nil

  defp suggestions_block(list) when is_list(list) do
    bullets = Enum.map_join(list, "\n", &"  * #{format_name(&1)}")
    "Did you mean:\n#{bullets}"
  end

  defp fix_block(nil), do: nil
  defp fix_block(text) when is_binary(text), do: "Fix: #{text}"

  defp format_name(name) when is_atom(name), do: inspect(name)
  defp format_name(name) when is_binary(name), do: name

  defp indent_continuation_lines(text, indent) do
    case String.split(text, "\n") do
      [] ->
        ""

      [first | rest] ->
        rest
        |> Enum.map(fn
          "" -> ""
          line -> indent <> line
        end)
        |> then(&[first | &1])
        |> Enum.join("\n")
    end
  end

  defp stringify(name) when is_atom(name), do: Atom.to_string(name)
  defp stringify(name) when is_binary(name), do: name
end
