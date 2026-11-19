defmodule PyroManiac.Form.BulkAction do
  @moduledoc """
  A bulk action configuration for forms in `PyroManiac`.

  Bulk actions allow performing update or destroy operations on multiple
  selected records simultaneously. They support the same inputs, groups,
  rows, compounds, and steps as `Form.Action`.
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :bulk_action,
    args: [:name],
    describe:
      "Configure a bulk action form. References an update or destroy action on the resource.",
    entities: [
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input,
        PyroManiac.Form.Group,
        PyroManiac.Form.Row,
        PyroManiac.Form.Compound,
        PyroManiac.Form.Step
      ]
    ],
    schema: [
      description: [
        doc: "The description for this bulk action (defaults to action's description).",
        type: :string
      ],
      label: [
        doc: "The label for this bulk action button (defaults to capitalized name).",
        type: :string
      ],
      max_columns: [
        doc: "The maximum number of columns of the form.",
        type: :pos_integer
      ],
      name: [
        doc: "The action name(s) for this bulk action.",
        required: true,
        type: {:wrap_list, :atom}
      ],
      set_all_fields?: [
        doc:
          "When true, all fields are submitted including empty/nil values (like a normal form). When false (default), empty fields are filtered out for partial updates.",
        type: :boolean,
        default: false
      ],
      delegate_to: [
        doc:
          "Resolve fields from a matching bulk action in another pyro_maniac module. Mutually exclusive with inline field definitions.",
        type: {:spark, PyroManiac}
      ]
    ]
end
