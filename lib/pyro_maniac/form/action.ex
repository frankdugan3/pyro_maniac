defmodule PyroManiac.Form.Action do
  @moduledoc """
  A form configuration for an Ash resource action.
  """

  use PyroManiac.Dsl.Entity,
    name: :action,
    args: [:name],
    describe: "Configure the appearance forms forms for specific action(s).",
    entities: [
      fields: [PyroManiac.Form.Field, PyroManiac.Form.FieldGroup, PyroManiac.Form.Step],
      sets: [PyroManiac.Form.Set]
    ],
    schema: [
      class: [
        doc: "Customize form classes.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      description: [
        doc: "The description for this form (defaults to action's description).",
        type: :string
      ],
      label: [
        doc: "The label for this form (defaults to capitalized name).",
        type: :string
      ],
      name: [
        doc: "The action name(s) for this form.",
        required: true,
        type: {:wrap_list, :atom}
      ],
      resource: [
        doc:
          "Target a different resource for this form. Enables cross-resource actions (e.g., creating a child record from a parent data table).",
        type: {:spark, Ash.Resource}
      ],
      delegate_to: [
        doc:
          "Resolve fields from a matching action in another pyro_maniac module. Mutually exclusive with inline field definitions.",
        type: {:spark, PyroManiac}
      ]
    ]
end
