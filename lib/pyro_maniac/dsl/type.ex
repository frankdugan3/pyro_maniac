defmodule PyroManiac.Dsl.Type do
  @moduledoc false

  @css_class {:or, [nil, :string, {:fun, [:map], :string}]}
  @pagination {:one_of, [:keyset, :offset, :none]}
  @render_fn {:fun, [:map], :any}
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
  Extra CSS classes. Will be appended to base classes. If a function, it will be passed the component assigns.
  """
  def css_class, do: @css_class

  @doc """
  Inheritable types will inherit from parent DSL if not defined, falling back to the Ash resource DSL where applicable.
  """
  def inheritable(type), do: {:or, [type, {:one_of, [:inherit]}]}

  @doc """
  Inline edit configuration for a column.

  - `nil` — not editable
  - `:text`, `:number`, etc. — input type using primary update action
  - `{:action_name, :input_type}` — specific action + input type
  - render function — custom render function
  """
  def edit_with do
    {:or, [nil, :atom, {:tuple, [:atom, :atom]}, @render_fn]}
  end

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
  A render function to render the item. It will be passed assigns.
  """
  def render_fn, do: @render_fn

  @doc """
  A validated Ash sort input. Supports string or keyword list syntax.
  """
  def sort, do: @sort
end
