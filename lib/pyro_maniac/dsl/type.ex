defmodule PyroManiac.Dsl.Type do
  @moduledoc false

  @load {:list, {:or, [:atom, {:tuple, [:atom, :any]}]}}
  @pagination {:one_of, [:keyset, :offset, :none]}
  @sizes [:auto, :code, :term, :name, :phrase, :prose]
  @default_decorations [:neutral, :info, :success, :warning, :danger]
  @decorations Application.compile_env(:pyro_maniac, :decorations, @default_decorations)
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
  def on_bulk, do: {:or, [nil, {:one_of, [:none, :reload, :notify]}]}

  @doc """
  A render module. PyroManiac stores the module only. Each renderer requires
  that the module implements its render behaviour.
  """
  def render_module, do: :atom

  @doc "The content role of an input. `:auto` is resolved by the transformer."
  def size, do: {:one_of, @sizes}

  @doc false
  def sizes, do: @sizes

  @doc "The density of a section or a step."
  def density, do: {:one_of, [:normal, :dense]}

  @doc """
  The actions of a node of the record tree (`only`): names of the read
  action of the view (view mode) and of the actions that use the tree.
  """
  def only, do: {:wrap_list, :atom}

  @doc """
  The page module of a link. A module, not `{:spark, PyroManiac}`: two pages
  can link to each other, so a verifier checks it after both compile.
  """
  def link_target, do: :atom

  @widths [:full, :record, :form, :prose]
  @orientations [:horizontal, :vertical]

  @doc """
  The width of a page, a view, or a modal or drawer: an intent. Each
  renderer maps each one to its own size (as the decorations).

  - `:full`: the whole content area (the default of a page).
  - `:record`: the width of one record (a card, a detail).
  - `:form`: the width of a form of inputs.
  - `:prose`: a readable line length for text.
  """
  def width, do: {:one_of, @widths}

  @doc "The widths (`width/0`)."
  def widths, do: @widths

  @doc """
  The axis of a layout: `:horizontal` (left to right) or `:vertical` (top
  to bottom). A preference: a renderer may fall back to `:vertical` when a
  horizontal layout has no room.
  """
  def orientation, do: {:one_of, @orientations}

  @doc "The orientations (`orientation/0`)."
  def orientations, do: @orientations

  @doc "How a card view opens: over the page, at its side, or as the page."
  def presentation, do: {:one_of, [:modal, :drawer, :page]}

  @doc "How the records of a relationship look: a view type, a count, or badges."
  def related_type, do: {:one_of, [:list, :data_table, :grid, :count, :badge]}

  @doc "Where the records of a relationship show: in the record, or over the page."
  def related_presentation, do: {:one_of, [:inline, :modal, :drawer]}

  @doc """
  The decorations: the meanings that a value can have. Each renderer maps
  each one to its own style. The default set is
  `[:neutral, :info, :success, :warning, :danger]`; an application sets its
  own list (at compile time):

      config :pyro_maniac, decorations: [:neutral, :info, :success, :warning, :danger, :muted]
  """
  def decorations, do: @decorations

  @doc "The default decorations."
  def default_decorations, do: @default_decorations

  @doc """
  An Ash expression, made with `expr/1`. The transformer validates it.
  """
  def expression, do: :any

  @doc """
  A validated Ash sort input. Supports string or keyword list syntax.
  """
  def sort, do: @sort
end
