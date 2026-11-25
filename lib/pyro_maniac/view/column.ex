defmodule PyroManiac.View.Column do
  @moduledoc """
  The configuration of a data table column in `PyroManiac`.

  Columns are used exclusively in `:data_table` views. Unlike fields, columns
  are interactive — users can sort, filter, hide, and reorder them at runtime.

  The header (`label`, default: the capitalized name), its help text
  (`description`), and the cell (`render`) are entities: a text or an Ash
  expression for every renderer, and an implementation for one renderer
  (refer to `PyroManiac.Content`):

  ```elixir
  column :actual_abv do
    label "ABV"
    description "Measured alcohol by volume."
  end

  column :batch_number do
    render PyroManiac.LiveView, BreweryWeb.Components.BatchNumber
  end
  ```

  `decoration` gives the meaning of each cell: a decoration, or an Ash
  expression that gives a decoration or `nil`. The decorations are
  `PyroManiac.Info.decorations/0` (configurable):

  ```elixir
  column :status do
    decoration expr(if status == :cancelled, do: :danger, else: nil)
  end
  ```

  `action :update` with the inputs of the cell (`field`, `select`,
  `combobox`, `input`, `compound`; no `delegate_to` or `resource`) edits
  the cell inline. A create action in a column is an input of the inline
  new row of the view (`new_row? true`):

  ```elixir
  column :status do
    action :update, :discard do
      select :status, autofocus: true
    end
  end
  ```
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :column,
    args: [:name],
    describe: "Declare non-default behavior for a specific data table column.",
    imports: [Ash.Expr],
    entities: [
      label: [PyroManiac.Label],
      description: [PyroManiac.Description],
      link_to: [PyroManiac.LinkTo],
      render: [PyroManiac.Render],
      actions: [PyroManiac.Form.Action]
    ],
    schema: [
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
      name: [
        doc: "The name of the column.",
        required: true,
        type: :atom
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
      decoration: [
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
      __decoration_refs__: [
        default: [],
        doc: "The fields that the `decoration` expression needs. Set by the transformer.",
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
     |> Map.update!(:label, fn label ->
       if PyroManiac.Content.portable(label) do
         label
       else
         text = Transformers.default_label(column.name)
         [PyroManiac.Content.default_text(PyroManiac.Label, text) | label]
       end
     end)}
  end
end
