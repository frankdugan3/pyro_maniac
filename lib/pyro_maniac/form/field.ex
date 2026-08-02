defmodule PyroManiac.Form.Field do
  @moduledoc """
  The configuration of a form field in `PyroManiac`.
  """

  use PyroManiac.Dsl.Entity,
    name: :field,
    args: [:name],
    describe:
      "Declare non-default behavior for a specific form field in the `PyroManiac` extension.",
    schema: [
      combobox_option_label_key: [
        doc:
          "Combobox label key. Auto-populated for `belongs_to` fields from the destination resource's `default_label`; falls back to `:label` if neither is set.",
        type: :atom
      ],
      combobox_option_value_key: [
        doc:
          "Combobox value key. Auto-populated for `belongs_to` fields from the destination resource's primary key; falls back to `:id`.",
        type: :atom
      ],
      combobox_search_action: [
        doc:
          "Combobox search action name. Auto-populated for `belongs_to` fields to the destination resource's primary `:read` action.",
        type: :atom
      ],
      combobox_search_arg: [
        doc: "Argument name on `combobox_search_action` that receives the typed search string.",
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
      multiple?: [
        default: false,
        doc:
          "Whether the field accepts multiple values (e.g. an array enum). Auto-populated by the transformer; the renderer reads this to choose between single and multi-valued chrome on the same atom.",
        type: :boolean
      ],
      when: [
        doc:
          "Conditional visibility function. Receives the form and returns a boolean. When nil (default), field is always visible.",
        type: {:or, [nil, {:fun, 1}]}
      ]
    ]
end
