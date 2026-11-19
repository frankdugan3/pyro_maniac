defmodule PyroManiac.Dsl.Type do
  @moduledoc false

  @load {:list, {:or, [:atom, {:tuple, [:atom, :any]}]}}
  @pagination {:one_of, [:keyset, :offset, :none]}
  @sizes [:auto, :code, :term, :name, :phrase, :prose]
  @tones [:neutral, :info, :success, :warning, :danger]
  @sort {:or,
         [
           :string,
           {:list,
            {:tuple,
             [
               :atom,
               {:one_of,
                [
                  :asc,
                  :desc,
                  :asc_nils_first,
                  :asc_nils_last,
                  :desc_nils_first,
                  :desc_nils_last
                ]}
             ]}},
           {:list, :atom},
           {:list, :string},
           nil
         ]}

  @doc """
  Inheritable types will inherit from parent DSL if not defined, falling back to the Ash resource DSL where applicable.
  """
  def inheritable(type), do: {:or, [type, {:one_of, [:inherit]}]}

  @doc """
  Inline edit configuration for a column.

  - `nil` — not editable
  - `:text`, `:number`, etc. — input type using primary update action
  - `{:action_name, :input_type}` — specific action + input type
  - a render module — custom edit UI (see `render_module/0`)
  """
  def edit_with do
    {:or, [nil, :atom, {:tuple, [:atom, :atom]}]}
  end

  @doc """
  An Ash load statement: a list of field names and/or nested `{relationship, loads}` keywords.
  """
  def load, do: @load

  @doc """
  Ash pagination strategies.
  """
  def pagination, do: @pagination

  @doc """
  Real-time event handling strategy for PubSub notifications.

  - `:none` — ignore this event type
  - `:prepend` — insert new record at the beginning of the list (create only)
  - `:append` — insert new record at the end of the list (create only)
  - `:replace` — find and replace the record in the list (update only)
  - `:remove` — remove the record from the list (destroy only)
  - `:reload` — reload the entire data set
  - `:notify` — show a flash notification without modifying data
  """
  def on_create, do: {:or, [nil, {:one_of, [:none, :prepend, :append, :reload, :notify]}]}
  def on_update, do: {:or, [nil, {:one_of, [:none, :replace, :reload, :notify]}]}
  def on_destroy, do: {:or, [nil, {:one_of, [:none, :remove, :reload, :notify]}]}

  @doc """
  A render module. PyroManiac stores the module only. Each renderer requires
  that the module implements its render behaviour (for the LiveView renderer,
  `PyroManiac.LiveView.Render`).
  """
  def render_module, do: :atom

  @doc "The content role of an input. `:auto` is resolved by the transformer."
  def size, do: {:one_of, @sizes}

  @doc false
  def sizes, do: @sizes

  @doc "The density of a group or a step."
  def density, do: {:one_of, [:normal, :dense]}

  @doc "The meaning of a value. Each renderer maps it to its own style."
  def tones, do: @tones

  @doc """
  An Ash expression, made with `expr/1`. The transformer validates it.
  """
  def expression, do: :any

  @doc """
  A validated Ash sort input. Supports string or keyword list syntax.
  """
  def sort, do: @sort
end
