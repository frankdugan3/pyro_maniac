defmodule PyroManiac.Theme.DaisyUI do
  @moduledoc """
  A PyroManiac theme implementation for DaisyUI.
  """

  use PyroManiac.Theme

  theme do
    base_class :data_table, "table table-zebra table-pin-rows table-sm"
    base_class :data_table__caption, "text-3xl font-bold"
    base_class :data_table__header, ""
    base_class :data_table__header_row, ""
    base_class :data_table__body, ""
    base_class :data_table__body_row, ""
    base_class :data_table__footer, ""
    base_class :data_table__footer_row, ""
    base_class :data_table__footer_cell, ""
    base_class :data_table__column__header, ""
    base_class :data_table__column__cell, ""
    base_class :form, "fieldset"
    base_class :form__step, ""
    base_class :form__field, ""
    base_class :form__field__input, ""
    base_class :form__field_group, ""
    base_class :pagination, "footer"
    base_class :pagination__navigator, "join join-horizontal"
    base_class :pagination__first, "join-item btn"
    base_class :pagination__previous, "join-item btn"
    base_class :pagination__next, "join-item btn"
    base_class :pagination__last, "join-item btn"
    base_class :pagination__limit, "join-item"
    base_class :pagination__limit_label, "label"
    base_class :pagination__limit_input, "select"
    base_class :pagination__reset, "join-item btn"
    base_class :scroll_to_top, "btn btn-circle"
    base_class :icon, ""
  end
end
