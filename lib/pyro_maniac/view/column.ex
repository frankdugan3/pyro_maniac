defmodule PyroManiac.View.Column do
  @moduledoc ~s'''
  The configuration of a data table column in `PyroManiac`.

  Columns are used exclusively in `:data_table` views. Unlike fields, columns
  are interactive — users can sort, filter, hide, and reorder them at runtime.

  For bespoke rendering needs, you can provide a custom component inline or as a function capture:

  ```elixir
  import Phoenix.Component, only: [sigil_H: 2]
  column :code do
    class "whitespace-nowrap"
    render_cell fn assigns ->
      ~H"""
      <span class="pyro-maniac-icon-rocket"></span>
      <%= Map.get(@row, @col[:name]) %>
      """
    end
  end
  ```
  '''

  use PyroManiac.Dsl.Entity,
    name: :column,
    args: [:name],
    describe: "Declare non-default behavior for a specific data table column.",
    schema: [
      cell_class: [
        doc: "Customize cell class.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      description: [
        doc: "Description of column.",
        type: PyroManiac.Dsl.Type.inheritable(:string)
      ],
      edit_with: [
        doc:
          "Inline edit config. An atom (e.g. `:text`) uses primary update action. A tuple `{:action, :type}` specifies both. A render function for custom UI. `nil` disables editing.",
        type: PyroManiac.Dsl.Type.edit_with()
      ],
      filterable?: [
        default: true,
        doc:
          "Enable filtering on this column. Note: If technically unfilterable, automatically set to false.",
        type: :boolean
      ],
      header_class: [
        doc: "Customize header class.",
        type: PyroManiac.Dsl.Type.css_class()
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
      render_cell_data: [
        default: &__MODULE__.render_cell_data/1,
        type: PyroManiac.Dsl.Type.render_fn()
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
      type: [
        default: :default,
        doc: "The type of the column.",
        type: {:one_of, [:default, :textarea, :attachment]}
      ],
      __attachment_destination__: [
        private?: true,
        hide: true,
        doc: "The destination resource module for attachment columns. Set by the transformer.",
        type: :any
      ],
      __enum_type__: [
        private?: true,
        hide: true,
        doc: "The Ash.Type.Enum module for enum columns. Set by the transformer.",
        type: :any
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  import PyroManiac.Helpers

  alias PyroManiac.Dsl.Transformers
  alias PyroManiac.Presenter

  @doc """
  The default render function for row cell data.
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

  def render_cell_data(%{col: %{source: source, type: :default}, row: row, scope: scope}) do
    row
    |> get_nested(source)
    |> Presenter.present(scope)
  end

  def render_cell_data(%{col: %{source: source, type: :default}, row: row}) do
    row
    |> get_nested(source)
    |> Presenter.present()
  end

  # TODO: Figure out how to do this framework-agnostically.
  # def render_cell_data(%{col: %{type: :textarea}} = assigns) do
  #   ~H"""
  #   <span class="whitespace-pre-wrap">{get_nested(@row, @col.source)}</span>
  #   """
  # end

  # TODO: Figure out how to do this framework-agnostically.
  # def render_cell_data(%{col: %{type: :attachment} = col, row: row} = assigns) do
  #   items = Map.get(row, col.name)
  #   count = if is_list(items), do: length(items), else: 0
  #
  #   assigns =
  #     assigns
  #     |> Map.put(:count, count)
  #     |> Map.put(:record_id, to_string(row.id))
  #     |> Map.put(:parent_resource, inspect(col.__attachment_destination__))
  #
  #   ~H"""
  #   <PyroManiac.Attachments.AttachmentManager.attachment_badge
  #     count={@count}
  #     record_id={@record_id}
  #     parent_resource={@parent_resource}
  #   />
  #   """
  # end

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
