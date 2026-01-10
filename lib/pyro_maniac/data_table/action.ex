defmodule PyroManiac.DataTable.Action do
  @moduledoc """
  A data table for action(s) in `PyroManiac`.
  """
  use PyroManiac.Dsl.Entity,
    name: :action,
    args: [:name],
    describe: "Configure the appearance of the data table for specific action(s).",
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
        doc: "Customize data table classes.",
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
      label: [
        doc: "The label for this data table (defaults to capitalized name).",
        type: :string
      ],
      name: [
        doc: "The action name(s) for this data table.",
        required: true,
        type: {:wrap_list, :atom}
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  @doc false
  def __set_defaults__(action) do
    {:ok,
     action
     |> Map.update!(:default_display, fn
       nil -> Enum.map(action.columns, & &1.name)
       display -> display
     end)}
  end
end
