defmodule PyroManiac.Form.Templates do
  @moduledoc """
  Template functions for the expressions of a `combobox`.

  Use them with `^`, as `^arg/1` of `Ash.Expr`:

      combobox :lot_number do
        filter expr(is_nil(^input(:name)) or name == ^input(:name))
      end

  They are Ash context templates. `PyroManiac.Form.combobox_query/4` fills
  them before the query runs.
  """
  @moduledoc group: "PyroManiac"

  @doc "The text that the user typed in the combobox, trimmed. `\"\"` when empty."
  def search, do: {:_context, [:pyro_maniac, :search]}

  @doc "The current value of the input `name` of the same form level. `nil` when empty."
  def input(name) when is_atom(name), do: {:_context, [:pyro_maniac, :inputs, name]}
end
