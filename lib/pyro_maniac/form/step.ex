defmodule PyroManiac.Form.Step do
  @moduledoc """
  A step for wizard forms.
  """

  use PyroManiac.Dsl.Entity,
    name: :step,
    args: [:name],
    describe: "Configure a form step in the `PyroManiac.Dsl` extension.",
    entities: [fields: [PyroManiac.Form.Field, PyroManiac.Form.FieldGroup]],
    schema: [
      class: [
        doc: "Customize class.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      label: [
        doc: "The label of this step (defaults to capitalized name).",
        type: :string
      ],
      name: [
        doc: "The name of the step.",
        required: true,
        type: :atom
      ],
      path: [
        default: [],
        doc:
          "Base path for all fields in this step. When set, fields are rendered within inputs_for for this path.",
        type: {:list, :atom}
      ],
      render_fn: [
        doc: "Custom render override function. Receives assigns map, returns HEEx.",
        type: PyroManiac.Dsl.Type.render_fn()
      ],
      review?: [
        default: false,
        doc: "When true, auto-generates a read-only summary of previous steps.",
        type: :boolean
      ],
      when: [
        doc:
          "Conditional visibility function. Receives the form and returns a boolean. When nil (default), step is always visible.",
        type: {:or, [nil, {:fun, 1}]}
      ]
    ]
end
