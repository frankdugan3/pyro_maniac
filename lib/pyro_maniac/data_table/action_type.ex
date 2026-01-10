defmodule PyroManiac.DataTable.ActionType do
  @moduledoc """
  A data table for action(s) of a given type in `PyroManiac`.
  """
  use PyroManiac.Dsl.Entity,
    name: :action_type,
    args: [:name],
    describe:
      "Configure the default data table appearance for actions of type(s). Will be ignored by actions configured explicitly.",
    entities: [columns: [PyroManiac.DataTable.Column]],
    # quokka:sort
    schema: [
      body_class: [
        doc: "Additional data table tbody classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      body_row_class: [
        doc: "Additional data table tbody > tr classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      caption_class: [
        doc: "Additional data table caption classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      class: [
        doc: "Additional data table classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      default_display: [
        doc: "The columns to display by default.",
        type: {:list, :atom}
      ],
      default_sort: [
        doc: "The columns to sort on by default.",
        type: PyroManiac.Dsl.Type.sort()
      ],
      description: [
        doc: "The description for this data table.",
        type: PyroManiac.Dsl.Type.inheritable(:string)
      ],
      exclude: [
        default: [],
        doc: "The fields to exclude from columns.",
        type: {:list, :atom}
      ],
      footer_cell_class: [
        doc: "Additional data table tfoot -> tr -> td classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      footer_class: [
        doc: "Additional data table tfoot classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      footer_row_class: [
        doc: "Additional data table tfoot -> tr classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      header_class: [
        doc: "Additional data table thead classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      header_row_class: [
        doc: "Additional data table thead > tr classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      name: [
        doc: "The action type(s) for this data table.",
        required: true,
        type: {:wrap_list, {:one_of, [:read]}}
      ]
    ],
    transform: {PyroManiac.DataTable.Action, :__set_defaults__, []}
end
