defmodule PyroManiac.Form.Workflow do
  @moduledoc """
  The status of the workflow of the record: its state machine
  ([AshStateMachine](https://hexdocs.pm/ash_state_machine)) or its workflow
  ([AshWorkflow](https://hex.pm/packages/ash_workflow)). The resource uses
  one of them.

      workflow do
        type :steps
        history :transitions
      end

  - `type :steps` shows each state (or step) with the current one marked;
    `:badge` shows the current state only. `orientation` (`:horizontal`, the
    default, or `:vertical`) is the axis of the steps.
  - `transitions? true` shows the transitions that the record can take as
    buttons. Each transition is an action of the view (`action :approve,
    :discard`); a transition that is not an action of the view does not
    show.
  - `history` names the relationship of the transition log of the record
    (for example the log of AshWorkflow, or an audit resource). It shows as
    a timeline.

  The renderer reads the state: the state attribute of AshStateMachine, and
  with AshWorkflow its calculations (`:current_step`, `:steps`,
  `:available_actions`, `:pending_deadlines`). Refer to
  `PyroManiac.Workflow`.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type

  use PyroManiac.Dsl.Entity,
    name: :workflow,
    args: [],
    describe: "The status of the workflow (state machine) of the record.",
    imports: [Ash.Expr],
    entities: [
      description: [PyroManiac.Description],
      render: [PyroManiac.Render]
    ],
    schema: [
      label: [
        doc: "The heading (defaults to \"Status\").",
        type: :string
      ],
      type: [
        default: :steps,
        doc: "`:steps`: each state with the current one marked; `:badge`: the current state.",
        type: {:one_of, [:steps, :badge]}
      ],
      orientation: [
        default: :horizontal,
        doc:
          "The axis of the states of `type :steps`: `:horizontal` (in a row, the default) or `:vertical` (in a column). `:vertical` with `type :badge` is a compile error.",
        type: PyroManiac.Dsl.Type.orientation()
      ],
      transitions?: [
        default: true,
        doc:
          "Show the transitions that the record can take as buttons (the actions of the view with the names of the transitions).",
        type: :boolean
      ],
      history: [
        doc: "A relationship to the transition log of the record. It shows as a timeline.",
        type: :atom
      ],
      only: [
        doc:
          "The actions that show it: the read action of the view (view mode) and the actions of the tree. `nil`: all.",
        type: Type.only()
      ],
      visible?: [
        doc: "Conditional visibility: an Ash expression.",
        type: Type.expression()
      ]
    ],
    private_fields: [
      __full_path__: [
        default: [],
        doc: "The full path from the form resource. Set by the transformer.",
        type: {:list, :atom}
      ],
      __depends_on__: [
        default: [],
        doc:
          "The attributes and arguments that `visible?` refers to, and `{:parent, name}` for `parent(name)`. Set by the transformer.",
        type: {:list, :any}
      ],
      __engine__: [
        doc:
          "`:ash_workflow` or `:ash_state_machine`: the extension of the resource. Set by the transformer.",
        type: :atom
      ],
      __state__: [
        doc: "The state attribute of the resource. Set by the transformer.",
        type: :atom
      ]
    ]
end
