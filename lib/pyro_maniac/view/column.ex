defmodule PyroManiac.View.Column do
  @moduledoc """
  The configuration of a data table column in `PyroManiac`.

  Columns are used exclusively in `:data_table` views. Unlike fields, columns
  are interactive — users can sort, filter, hide, and reorder them at runtime.

  For custom cell rendering, give a render module. Each renderer requires
  that the module implements its render behaviour:

  ```elixir
  column :code do
    render MyAppWeb.Cells.Code
  end
  ```

  `tone` gives the meaning of each cell: a tone, or an Ash expression that
  gives a tone or `nil`:

  ```elixir
  column :status do
    tone expr(if status == :overdue, do: :danger, else: nil)
  end
  ```
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :column,
    args: [:name],
    describe: "Declare non-default behavior for a specific data table column.",
    imports: [Ash.Expr],
    schema: [
      description: [
        doc: "Description of column.",
        type: PyroManiac.Dsl.Type.inheritable(:string)
      ],
      edit_with: [
        doc:
          "Inline edit config. An atom (e.g. `:text`) uses primary update action. A tuple `{:action, :type}` specifies both. `nil` disables editing.",
        type: PyroManiac.Dsl.Type.edit_with()
      ],
      filterable?: [
        default: true,
        doc:
          "Enable filtering on this column. Note: If technically unfilterable, automatically set to false.",
        type: :boolean
      ],
      keyset_sortable?: [
        default: true,
        doc:
          "Enable keyset-paged sorting. Note: If technically unsortable, automatically set to false.",
        type: :boolean
      ],
      label: [
        doc: "The label of the column (defaults to capitalized name).",
        type: :string
      ],
      name: [
        doc: "The name of the column.",
        required: true,
        type: :atom
      ],
      render: [
        doc:
          "A render module for the cell. The renderer requires its render behaviour. Without it, the cell shows `render_cell_data/1`.",
        type: PyroManiac.Dsl.Type.render_module()
      ],
      sortable?: [
        default: true,
        doc:
          "Enable unpaged and offset-paged sorting. Note: If technically unsortable, automatically set to false.",
        type: :boolean
      ],
      source: [
        doc: "Source path for data (defaults to name).",
        type: {:list, :atom}
      ],
      tone: [
        doc:
          "The meaning of each cell: `:neutral`, `:info`, `:success`, `:warning`, `:danger`, or an Ash expression that gives one of them or `nil`.",
        type: :any
      ],
      type: [
        default: :default,
        doc: "The type of the column.",
        type: {:one_of, [:default, :textarea, :attachment]}
      ]
    ],
    private_fields: [
      __attachment_destination__: [
        doc: "The destination resource module for attachment columns. Set by the transformer.",
        type: :any
      ],
      __enum_type__: [
        doc: "The Ash.Type.Enum module for enum columns. Set by the transformer.",
        type: :any
      ],
      __tone_refs__: [
        default: [],
        doc: "The fields that the `tone` expression needs. Set by the transformer.",
        type: {:list, :atom}
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  import PyroManiac.Helpers

  alias PyroManiac.Dsl.Transformers
  alias PyroManiac.Presenter

  @doc """
  The default content of a cell: the presented value, as text.
  """
  def render_cell_data(%{
        col: %{__enum_type__: enum_type, source: source, type: :default},
        row: row
      })
      when not is_nil(enum_type) do
    case get_nested(row, source) do
      nil -> ""
      values when is_list(values) -> Enum.map_join(values, ", ", &enum_type.label/1)
      value when is_atom(value) -> enum_type.label(value)
      value -> Presenter.present(value)
    end
  end

  def render_cell_data(%{col: %{source: source}, row: row, scope: scope}) do
    row
    |> get_nested(source)
    |> Presenter.present(scope)
  end

  def render_cell_data(%{col: %{source: source}, row: row}) do
    row
    |> get_nested(source)
    |> Presenter.present()
  end

  @doc false
  def __set_defaults__(column) do
    {:ok,
     column
     |> Map.update!(:source, fn
       nil -> List.wrap(column.name)
       source -> source
     end)
     |> Map.update!(:label, fn
       nil -> Transformers.default_label(column.name)
       label -> label
     end)}
  end
end
