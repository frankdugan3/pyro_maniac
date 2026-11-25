defmodule PyroManiac.Form.BulkAction do
  @moduledoc """
  An action on the selected records of a list view.

  Bulk actions allow performing update or destroy operations on multiple
  selected records simultaneously. They support the same inputs, sections,
  rows, compounds, and steps as `Form.Action`, and a `description` entity
  (`description :inherit` takes the description of the action). A bulk
  action is a use of its action: the page needs no `exclude` for it. Its
  `state` is required. `confirm` is optional for a bulk action with inputs,
  and required without inputs (a message, or `confirm false`), as on
  `PyroManiac.Form.Action`.

      bulk_action :update, :discard do
        description "Change the selected batches."
        confirm "Change the selected batches?"
        select :status, autofocus: true
      end
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :bulk_action,
    args: [:name, {:optional, :state}],
    describe:
      "Configure a bulk action form. References an update or destroy action on the resource.",
    imports: [Ash.Expr],
    entities: [
      description: [PyroManiac.Description],
      fields: [
        PyroManiac.Form.Field,
        PyroManiac.Form.Combobox,
        PyroManiac.Form.Select,
        PyroManiac.Form.Input,
        PyroManiac.Form.Section,
        PyroManiac.Form.Row,
        PyroManiac.Form.Compound,
        PyroManiac.Form.Step
      ]
    ],
    schema: [
      label: [
        doc: "The label for this bulk action button (defaults to capitalized name).",
        type: :string
      ],
      state: [
        doc:
          "What happens to the unsaved inputs of the form (renderers must implement it): `:guard` warns before the user leaves with unsaved changes, `:recover` keeps the inputs and restores them after a reload or a lost connection, `:discard` does neither. Required, with no default: the optional second argument (`action :update, :guard`) or an option in the block.",
        required: true,
        type: {:one_of, [:guard, :recover, :discard]}
      ],
      confirm: [
        doc:
          "Ask the user to confirm before the action runs: a text, or an Ash expression on the record (and `^arg(:name)` for the inputs) that gives the message (`nil`: no confirmation), or `false` for no confirmation. Required for a bulk action without inputs.",
        type: :any
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
    ],
    private_fields: [
      __confirm_refs__: [
        default: [],
        doc: "The fields that the `confirm` expression needs. Set by the transformer.",
        type: {:list, :atom}
      ],
      __view__: [
        doc: "The view of the bulk action: `{name, type}`. Set by the transformer.",
        type: :any
      ]
    ]
end
