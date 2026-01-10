defmodule PyroManiac.Theme.BaseClass do
  @moduledoc """
  Base class for a component block.
  """
  use PyroManiac.Dsl.Entity,
    args: [:name, :value],
    name: :base_class,
    identifier: :name,
    # quokka:sort
    schema: [
      __identifier__: [private?: true],
      name: [
        doc: "UI component for class",
        required: true,
        type: :atom
      ],
      prefixed: [type: :string, private?: true],
      value: [
        doc: "Class value",
        required: true,
        type: :string
      ]
    ]

  @doc """
  The default base class names requiring implementation. These are what the built-in PyroManiac backends require for compatible themes.
  """
  def default_base_class_names do
    ~w[
      data_table
        data_table__caption
        data_table__header
        data_table__header_row
        data_table__body
        data_table__body_row
        data_table__footer
        data_table__footer_row
        data_table__footer_cell
        data_table__column__header
        data_table__column__cell
      form
        form__step
        form__field
        form__field__input
        form__field_group
      pagination
        pagination__navigator
        pagination__first
        pagination__previous
        pagination__next
        pagination__last
        pagination__limit
        pagination__limit_label
        pagination__limit_input
        pagination__reset
      scroll_to_top
      icon
    ]a
  end
end
