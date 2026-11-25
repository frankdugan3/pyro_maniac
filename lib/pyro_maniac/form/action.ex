defmodule PyroManiac.Form.Action do
  @moduledoc """
  An action of a view: a create, update, destroy, or generic action of the
  resource, and its form (the nodes of its tree).

  - In a card, without nodes: the tree of the card is the form. A
    `select`, `combobox`, or `input` on an attribute that the action does not
    accept shows its value (as a `field`). An action that has no input in
    that tree (a transition) needs `confirm`: a message, or `confirm false`
    to run it at once from its button.
  - With nodes: its own tree, which a button of the view opens
    (`presentation`), in a modal or a drawer of its `width` (`:record` by
    default).
  - With `delegate_to`: the tree that a view of that page uses for the
    action of the same name (this page: the tree of its card).
  - In a list view, without nodes and without `delegate_to`: an action
    without inputs (a destroy, a status change). Its button runs it.
  - In a column: an inline edit of the cell: inputs only (`field`,
    `select`, `combobox`, `input`, `compound`), no `delegate_to`, and no
    `resource`.

  `state` is required, with no default: the optional second argument
  (`action :update, :guard`) or `state :guard` in the block. `:guard` warns
  before the user leaves with unsaved changes, `:recover` restores the
  inputs after a reload or a lost connection, and `:discard` does neither.

  `confirm` asks the user before the action runs: a text, or an Ash
  expression on the record that gives the message or `nil`. `confirm false`
  runs it without a confirmation. No confirmation is automatic: an action
  without an input in its tree (not an inline edit) must set `confirm`, or
  the page does not compile. A renderer never adds one.

  `description` is an entity (refer to `PyroManiac.Description`);
  `description :inherit` takes the description of the action.

  With `resource` and `set`, the action runs on another resource, for
  example a quality test of a batch. `set ..., overridable?: true` sets
  the value when the form opens, and the user can change it.

      view :read do
        type :card
        primary? true

        section :batch do
          field :batch_number
          field :status
        end

        action :create, :guard do
          resource Brewery.QualityTest
          label "Add test"
          description "A quality test of this batch."
          set :batch_id, :id

          select :test_type, autofocus: true
          field :tested_at
          field :result
          field :passed
          field :notes
          combobox :tester_id
        end
      end
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :action,
    args: [:name, {:optional, :state}],
    describe: "An action of the view, and its form.",
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
        PyroManiac.Form.Related,
        PyroManiac.Form.Attachments,
        PyroManiac.Form.Workflow,
        PyroManiac.Form.Tabs,
        PyroManiac.Form.Step
      ],
      sets: [PyroManiac.Form.Set]
    ],
    schema: [
      label: [
        doc: "The label for this form (defaults to capitalized name).",
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
          "Ask the user to confirm before the action runs: a text, or an Ash expression on the record (and `^arg(:name)` for the inputs) that gives the message (`nil`: no confirmation), or `false` for no confirmation. Required for an action without inputs.",
        type: :any
      ],
      max_columns: [
        doc: "The maximum number of columns of the form.",
        type: :pos_integer
      ],
      presentation: [
        default: :modal,
        doc:
          "How the form of an action with its own tree opens: `:modal`, `:drawer`, or `:page`.",
        type: PyroManiac.Dsl.Type.presentation()
      ],
      width: [
        doc:
          "The width of the modal or the drawer of an action with its own tree (an intent, `PyroManiac.Dsl.Type.width/0`): `:full`, `:record`, `:form`, or `:prose`. `nil`: `:record` (`PyroManiac.Info.action_width/1`).",
        type: PyroManiac.Dsl.Type.width()
      ],
      step_orientation: [
        doc:
          "The axis of the stepper of the `step` entities of the form: `:horizontal` or `:vertical`. `nil`: the `step_orientation` of the view.",
        type: PyroManiac.Dsl.Type.orientation()
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
    ],
    private_fields: [
      __confirm_refs__: [
        default: [],
        doc: "The fields that the `confirm` expression needs. Set by the transformer.",
        type: {:list, :atom}
      ],
      __view__: [
        doc: "The view of the action: `{name, type}`. Set by the transformer.",
        type: :any
      ],
      __column__: [
        doc: "The column whose cell the action edits. Set by the transformer.",
        type: :atom
      ],
      __columns__: [
        default: [],
        doc: "The columns whose cells the action edits together. Set by the transformer.",
        type: {:list, :atom}
      ]
    ]
end
