defmodule PyroManiac.Test.DslError do
  @moduledoc """
  Test helpers for asserting on `Spark.Error.DslError` raised by the PyroManiac
  DSL transformers and verifiers.

  The volatile `defined in <path>:<line>[:<col>]` segment of the rendered message
  is substituted with `defined in <FILE:LINE>` before comparison so heredocs stay
  stable across edits that shift line numbers.
  """

  @doc """
  Asserts that the given block raises `Spark.Error.DslError` and that the
  rendered message matches `expected`.

  - When `expected` is a string, asserts an exact heredoc match (with
    `defined in <FILE:LINE>` substituted in for the volatile path/line).
  - When `expected` is a regex, asserts the rendered message matches.

  In both modes the Spark warning that Spark emits on stderr alongside the
  raise is captured and discarded so test output stays clean.
  """
  defmacro assert_dsl_error(expected, do: block) do
    quote do
      {err, captured} =
        PyroManiac.Test.DslError.__capture_dsl_error__(fn ->
          unquote(block)
        end)

      actual = PyroManiac.Test.DslError.__select_actual__(err, captured, unquote(expected))
      PyroManiac.Test.DslError.__match_dsl_error__(actual, unquote(expected))
    end
  end

  @doc false
  # For exact-match heredocs: render the structured exception message and
  # append the IO.warn source-context block parsed out of the captured stderr,
  # so heredocs can verify both *what's wrong* and *where* the bad code is.
  # For regex match: the rendered exception message alone (regex is loose).
  def __select_actual__(err, _captured, %Regex{}), do: normalize(Exception.message(err))

  def __select_actual__(err, captured, _exact_string) do
    body = normalize(Exception.message(err))

    case extract_source_context(captured) do
      "" -> body
      ctx -> body <> "\n" <> ctx
    end
  end

  @doc false
  def __capture_dsl_error__(fun) do
    parent = self()

    captured =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        result =
          try do
            fun.()
            :no_raise
          rescue
            e in Spark.Error.DslError -> {:raised, e}
          end

        send(parent, {:dsl_error_result, result})
      end)

    case (receive do
            {:dsl_error_result, x} -> x
          end) do
      :no_raise ->
        raise ExUnit.AssertionError,
          message: "Expected Spark.Error.DslError but nothing was raised"

      {:raised, e} ->
        {e, captured}
    end
  end

  @doc false
  def __match_dsl_error__(actual, %Regex{} = pattern) do
    if Regex.match?(pattern, actual) do
      :ok
    else
      raise ExUnit.AssertionError,
        message: "Spark.Error.DslError message did not match",
        left: actual,
        right: pattern
    end
  end

  def __match_dsl_error__(actual, expected) when is_binary(expected) do
    if actual == expected do
      :ok
    else
      raise ExUnit.AssertionError,
        message: "Spark.Error.DslError message mismatch",
        left: actual,
        right: expected,
        expr: "actual == expected"
    end
  end

  @doc """
  Substitute the volatile `defined in <path>:<line>[:<col>]` segment of an already-
  formatted exception message. Use when calling verifiers directly (no `assert_raise`).
  """
  def normalize(message) when is_binary(message) do
    Regex.replace(~r/defined in [^\n]+?:\d+(:\d+)?:?/, message, "defined in <FILE:LINE>")
  end

  @doc """
  Asserts that the captured stderr output from a Spark verifier failure equals
  the given expected message.

  Spark verifiers emit DslErrors as compile warnings on stderr (deps/spark/lib/spark/dsl.ex:539).
  This macro captures stderr, extracts only the structured DslError header + body,
  discards the stacktrace and the IO.warn source snippet, then exact-matches.
  """
  defmacro assert_dsl_warning(expected, do: block) do
    quote do
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          unquote(block)
        end)

      stripped = PyroManiac.Test.DslError.extract_warning_body(output)
      assert stripped == unquote(expected)
    end
  end

  @doc false
  # Parse the IO.warn source-context block out of the captured stderr.
  # Returns "" when there is no source context (e.g. verifier with no location).
  # Multiple emits are deduped — only the first context is returned.
  def extract_source_context(output) do
    output
    |> String.split("\n")
    |> Enum.drop_while(&(not source_context_line?(&1)))
    |> Enum.take_while(fn line ->
      line == "" or source_context_line?(line) or
        String.match?(line, ~r/^ *└─ /)
    end)
    |> Enum.map(&strip_context_indent/1)
    |> Enum.join("\n")
    |> String.trim_trailing()
    |> normalize_source_context()
  end

  # IO.warn pads `│` and `└─` lines so they align with line numbers, which
  # produces a varying number of leading spaces depending on the line number's
  # digit count. Normalize by stripping all leading whitespace before `│`
  # and `└─`; numbered source lines get their leading spaces removed too.
  defp strip_context_indent(line) do
    cond do
      String.match?(line, ~r/^ *└─ /) ->
        Regex.replace(~r/^ +/, line, "")

      String.match?(line, ~r/^ *\│/) ->
        Regex.replace(~r/^ +/, line, "")

      String.match?(line, ~r/^ *\d+ \│/) ->
        Regex.replace(~r/^ +/, line, "")

      true ->
        line
    end
  end

  @doc false
  # Verifier-only path: extract the full warning (header + body + source
  # context) from a captured stderr emit. Used by `assert_dsl_warning/2`
  # since verifier failures don't surface an exception to the caller.
  def extract_warning_body(output) do
    {body_lines, footer_lines} = split_warning(output)

    body =
      body_lines
      |> Enum.map(&String.replace_prefix(&1, "    ", ""))
      |> Enum.join("\n")
      |> String.replace_prefix("warning: ** (Spark.Error.DslError) ", "")
      |> String.trim_trailing()
      |> normalize()

    footer =
      footer_lines
      |> Enum.map(&strip_context_indent/1)
      |> Enum.join("\n")
      |> String.trim_trailing()
      |> normalize_source_context()

    case footer do
      "" -> body
      ctx -> body <> "\n" <> ctx
    end
  end

  defp split_warning(output) do
    lines = String.split(output, "\n")

    body =
      lines
      |> Enum.reduce_while([], fn line, acc ->
        stripped = String.trim_leading(line)

        stack_frame? =
          String.match?(stripped, ~r/^\([a-z_]+( [\d.]+)?\) [\w\/.]+:\d+:/) or
            String.match?(stripped, ~r/^test\/[\w\/_.]+\.exs:\d+:/)

        if stack_frame?, do: {:halt, acc}, else: {:cont, [line | acc]}
      end)
      |> Enum.reverse()

    footer =
      lines
      |> Enum.drop_while(&(not source_context_line?(&1)))
      |> Enum.take_while(fn line ->
        line == "" or source_context_line?(line) or
          String.match?(line, ~r/^ *└─ /)
      end)

    {body, footer}
  end

  defp source_context_line?(line) do
    String.match?(line, ~r/^ {0,4}\d* \│/) or
      String.match?(line, ~r/^ *\│/) or
      String.match?(line, ~r/^ *└─ /)
  end

  defp normalize_source_context(text) do
    text
    |> String.replace(~r/^ *\d+ \│/m, "<LINE> │")
    |> String.replace(~r/└─ [^\n]+?:\d+(:\d+)?:/, "└─ <FILE:LINE>:")
  end
end
