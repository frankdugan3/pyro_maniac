defmodule PyroManiac.Form.Field do
  @moduledoc """
  The configuration of a form field in `PyroManiac`.
  """

  use PyroManiac.Dsl.Entity,
    name: :field,
    args: [:name],
    describe:
      "Declare non-default behavior for a specific form field in the `PyroManiac.Dsl` extension.",
    schema: [
      autocomplete_option_label_key: [
        default: :label,
        doc: "Override the default autocomplete key used as a label.",
        type: :atom
      ],
      autocomplete_option_value_key: [
        default: :id,
        doc: "Override the default autocomplete key used as a value.",
        type: :atom
      ],
      autocomplete_search_action: [
        default: :read,
        doc: "Set the autocomplete search action name.",
        type: :atom
      ],
      autocomplete_search_arg: [
        doc: "Set the autocomplete search argument key.",
        type: :atom
      ],
      autofocus: [
        default: false,
        doc: "Autofocus the field.",
        type: :boolean
      ],
      class: [
        doc: "Customize class.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      description: [
        doc: "Override the default extracted description.",
        type: :string
      ],
      form_only?: [
        default: false,
        doc:
          "When true, this field exists only in the form UI and is not submitted to the action.",
        type: :boolean
      ],
      input_class: [
        doc: "Customize input class.",
        type: PyroManiac.Dsl.Type.css_class()
      ],
      label: [
        doc: "The label of the field (defaults to capitalized name).",
        type: :string
      ],
      name: [
        doc: "The name of the field to be modified",
        required: true,
        type: :atom
      ],
      options: [
        default: [],
        doc: "The options for a select type input.",
        type: {:list, :any}
      ],
      path: [
        default: [],
        doc: "Append to the root path (nested paths are appended).",
        type: {:list, :atom}
      ],
      prompt: [
        doc: "Override the default prompt.",
        type: :string
      ],
      type: [
        default: :default,
        doc:
          "The type of the value in the form. Extensible via `extra_form_types` on the forms section.",
        type: :atom
      ],
      allow_nil?: [
        default: true,
        doc: "Whether nil is allowed. Auto-populated by the transformer from the Ash attribute.",
        type: :boolean
      ],
      enum_options: [
        default: [],
        doc:
          "Options from Ash enum types or one_of constraints. Auto-populated by the transformer.",
        type: {:list, :any}
      ],
      when: [
        doc:
          "Conditional visibility function. Receives the form and returns a boolean. When nil (default), field is always visible.",
        type: {:or, [nil, {:fun, 1}]}
      ]
    ]
end
