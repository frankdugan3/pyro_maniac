defmodule PyroManiac.View.View do
  @moduledoc """
  A view of a page: the records of a read action, and the actions that it
  runs. `view` is a top-level entity of the page.

  ## View Types

  - `:data_table` — Paginated, sortable, filterable table with interactive columns
  - `:grid` — Card grid: its own record tree (`section`, `row`, `compound`,
    `field`, `related`), or the primary card of the page (`card? true`)
  - `:calendar` — Calendar/timeline view keyed on date fields
  - `:gantt` — Gantt chart for scheduling data with start/end dates
  - `:kanban` — Board with swimlanes grouped by a field
  - `:list` — Tree/outline list, optionally hierarchical
  - `:timeline` — The records as events in time order (`date_field`, and
    `end_date_field` for a span), for example the history of a workflow
  - `:card` — One record (a single view): its record tree in view mode, and
    the form of each write action that it names (`action`). It opens over
    its page (`presentation`). A card can also show a list: one card for
    each record.
  - `:render` — A custom render (`render`, one for each renderer): the escape
    hatch.

  ## The record tree

  The nodes of a view (`field`, `select`, `combobox`, `input`, `section`,
  `row`, `compound`, `related`, `attachments`, `workflow`, `tabs`, `step`)
  are its record tree. View mode is the read action of the view; each write action that
  the view names (`action`) is a form of the same tree. `only [names]` puts
  a node in some of these actions.

  ## Actions

  - `action name, state` names an action of the resource: create, update,
    destroy, or a generic action. `state` (`:guard`, `:recover`, or
    `:discard`) is required: the second argument or `state` in the block.
    In a card, an action without nodes uses
    the tree of the card. An action with nodes has its own tree (a dialog);
    an action with `delegate_to` uses the tree of another page. In a list
    view, an action has its own tree or `delegate_to`; an action without
    inputs (a destroy, a status change) is a button, with its required
    `confirm` (a message, or `confirm false`).
  - `bulk_action name`: an action on the selected records of a list view.
    It is a use of its action.
  - `edit_columns action, columns, state`: the cells of some columns of a
    row, edited together. A column with `action :update` edits its cell
    alone.
  - `clone? true`: a Clone action for each record (a prefilled create
    form). `new_row? true` (`:data_table`): an inline new row, whose inputs
    are the create actions of the columns. `reorder? true` (`:data_table`,
    `:grid`, `:list`): drag to reorder by the rank of `PyroManiac.Ordering`
    or `PyroManiac.KanBan`.

  The form of each action has each accepted attribute and public argument
  of the action (or a `set`), and one input with `autofocus`. An inline
  edit (the `action` of a column, `edit_columns`) has inputs only, and no
  completeness check. Each exposed action of the resource is used by a view
  or is in `page do exclude [...] end`.

  A view that names a write action is editable (`__editable?__`). A view
  without one has no inputs: its `field` entities show values.

  The public arguments of the read action of a view are resolved inputs in
  `__arguments__`, for the controls of the view (for example the
  `lane_value` of a kanban read action).

  ## Content

  `description` is an entity (refer to `PyroManiac.Content`): the text
  below the tab of the view. A view has no record, so its own `render` and
  `description` are a text or implementations, not an expression.

  ## Layout

  - `width`: the width of the view, an intent (`PyroManiac.Dsl.Type.width/0`):
    `:full`, `:record`, `:form`, or `:prose`. Without it, the `width` of the
    page (`:full` by default); a `:card` with `presentation :modal` or
    `:drawer` is the width of its modal or its drawer, `:record` by default.
    Refer to `PyroManiac.Info.view_width/2`.
  - `orientation` (`:timeline`, `:kanban`): the axis of the view. A timeline
    is `:vertical` by default, a board `:horizontal` (its lanes side by
    side; `:vertical` stacks them as rows).
  - `step_orientation`: the stepper of the `step` entities of the forms of
    the view, `:horizontal` (the default) or `:vertical`. An `action` can
    set its own.

  ## Primary views

  A page has a primary single view (`primary? true` on a `:card`). With a
  primary list view (`primary? true` on a list type), the card is the
  primary single view only; without one, the card is also the primary list
  view. A link to the page opens a primary view (refer to `PyroManiac.LinkTo`).

  ## Example

      view :read do
        type :data_table
        primary? true
        description "The recipes of the brewery."
        exclude [:id, :description, :target_abv, :target_og, :target_fg]
        column :name
        column :style
        column :status

        action :create, :guard do
          delegate_to BreweryWeb.RecipeLive
        end

        action :destroy, :discard do
          confirm "Delete the recipe?"
        end
      end

      view :read do
        type :card
        primary? true
        action [:create, :update], :guard

        section :recipe do
          field :name, autofocus: true
          select :style
          select :status
          field :description, type: :textarea
        end

        section :targets do
          field :target_abv
          field :target_og
          field :target_fg
        end
      end
  """

  use PyroManiac.Dsl.Entity,
    name: :view,
    args: [:name],
    describe: "A view of the records of a read action, and the actions that it runs.",
    imports: [Ash.Expr],
    entities: [
      description: [PyroManiac.Description],
      columns: [PyroManiac.View.Column],
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
      actions: [PyroManiac.Form.Action],
      bulk_actions: [PyroManiac.Form.BulkAction],
      edit_columns: [PyroManiac.View.EditColumns],
      extra_actions: [PyroManiac.Page.ExtraAction],
      render: [PyroManiac.Render]
    ],
    schema: [
      name: [
        doc: "The action name(s) for this view.",
        type: {:wrap_list, :atom},
        default: []
      ],
      type: [
        doc: "The view type.",
        required: true,
        type:
          {:one_of,
           [:data_table, :grid, :card, :calendar, :gantt, :kanban, :list, :timeline, :render]}
      ],
      primary?: [
        default: false,
        doc:
          "The primary view of its kind (a top-level view): the primary single view (a `:card`), or the primary list view. A link to the page opens it. A page has a primary single view; a `:card` that is the only primary view is also the primary list view.",
        type: :boolean
      ],
      resource: [
        doc: "Target resource. Defaults to the resource of the page.",
        type: {:spark, Ash.Resource}
      ],
      label: [
        doc: "Display label for this view (defaults to capitalized name).",
        type: :string
      ],
      default_page_size: [
        doc: "Default page size. Falls back to action's default_limit, then 25.",
        type: :pos_integer
      ],
      page_sizes: [
        doc: "Available page size options for pagination controls.",
        type: {:list, :pos_integer}
      ],
      default_sort: [
        doc:
          "Default sort specification. Each key is a column, or the rank of the order of the resource (`PyroManiac.Ordering`), shown or not.",
        type: PyroManiac.Dsl.Type.sort()
      ],
      pagination: [
        doc: "Pagination type. Auto-detected from resource action if not set.",
        type: PyroManiac.Dsl.Type.pagination()
      ],
      count?: [
        doc: "Display page count. Defaults to true for offset if allowed.",
        type: :boolean
      ],
      read_action: [
        doc: "Override which read action to use on the target resource.",
        type: :atom
      ],
      exclude: [
        default: [],
        doc: "Fields to exclude from this view.",
        type: {:list, :atom}
      ],
      ensure_loaded: [
        default: [],
        doc:
          "Ash load statement always applied when loading data for this view, " <>
            "in addition to the loads inferred from columns, fields, and sections.",
        type: PyroManiac.Dsl.Type.load()
      ],
      on_create: [
        doc: "How to handle PubSub create notifications.",
        type: PyroManiac.Dsl.Type.on_create()
      ],
      on_update: [
        doc: "How to handle PubSub update notifications.",
        type: PyroManiac.Dsl.Type.on_update()
      ],
      on_destroy: [
        doc: "How to handle PubSub destroy notifications.",
        type: PyroManiac.Dsl.Type.on_destroy()
      ],
      on_bulk: [
        doc:
          "How to handle a `PyroManiac.Realtime.Bulk` message (one message for a bulk operation). The resource needs `bulk` in its `realtime` section.",
        type: PyroManiac.Dsl.Type.on_bulk()
      ],
      selectable?: [
        default: true,
        doc: "Enable the selection of records for bulk actions (list views).",
        type: :boolean
      ],
      default_display: [
        doc: "Which columns are visible by default (`:data_table` only).",
        type: {:list, :atom}
      ],
      group_by: [
        doc: "Field to group records into swimlanes (`:kanban` and optionally `:gantt`).",
        type: :atom
      ],
      kanban_action: [
        doc:
          "Update action for kanban card moves (`:kanban` only). Must accept both the `group_by` and `priority` fields.",
        type: :atom
      ],
      priority: [
        doc:
          "The string attribute for card ordering within lanes (a fractional index, `:kanban` only). Set from the `priority` of the `kan_ban` section of the resource. Sets `default_sort` automatically.",
        type: :atom
      ],
      date_field: [
        doc: "Field for the date or the start of an event (`:calendar` and `:timeline`).",
        type: :atom
      ],
      end_date_field: [
        doc: "Field for the end of an event (`:calendar` and `:timeline`, optional: a span).",
        type: :atom
      ],
      granularity: [
        doc:
          "The period that the calendar opens with: `:day`, `:week`, or `:month` (`:calendar` only). The user switches between the three.",
        type: {:one_of, [:day, :week, :month]}
      ],
      orientation: [
        doc:
          "The axis of the view (`:timeline` and `:kanban` only). A timeline: `:vertical` (the events from top to bottom, the default) or `:horizontal` (the events from left to right, on a scrollable time axis). A board: `:horizontal` (the lanes side by side, the default) or `:vertical` (the lanes stacked as rows, the cards of each lane from left to right). Set to the default of the type by the transformer.",
        type: PyroManiac.Dsl.Type.orientation()
      ],
      width: [
        doc:
          "The width of the view (an intent, `PyroManiac.Dsl.Type.width/0`): `:full`, `:record`, `:form`, or `:prose`. A `:card` with `presentation :modal` or `:drawer`: the width of its modal or its drawer. `nil`: `:record` for the modal or the drawer of a card, else the width of the page (`PyroManiac.Info.view_width/2`).",
        type: PyroManiac.Dsl.Type.width()
      ],
      step_orientation: [
        default: :horizontal,
        doc:
          "The axis of the stepper of the `step` entities of the forms of the view: `:horizontal` (the steps in a row, the default) or `:vertical` (the steps in a column at the side). An `action` can set its own.",
        type: PyroManiac.Dsl.Type.orientation()
      ],
      start_field: [
        doc: "Field for task start date (`:gantt` only).",
        type: :atom
      ],
      end_field: [
        doc: "Field for task end date (`:gantt` only).",
        type: :atom
      ],
      progress_field: [
        doc: "Field for completion percentage (`:gantt` only, optional).",
        type: :atom
      ],
      parent_field: [
        doc:
          "The `belongs_to` of a record to its parent, on the same resource: the list is a tree (`:list` only, optional).",
        type: :atom
      ],
      loads: [
        doc: "Ash load statement for `:render` views.",
        default: [],
        type: :any
      ],
      reorder?: [
        default: false,
        doc:
          "The user drags the records to reorder them, when the list is sorted by the rank of the resource (`PyroManiac.Ordering`). `:data_table`, `:grid`, and `:list` views.",
        type: :boolean
      ],
      clone?: [
        default: false,
        doc:
          "A **Clone** action for each record: a create form with the values of the record. The view names a create action (`action`).",
        type: :boolean
      ],
      new_row?: [
        default: false,
        doc:
          "An inline new row at the top of the table (`:data_table` only). The view names a create action, and each required input of it is the inline edit of a column (`column ... do action :create do ... end end`).",
        type: :boolean
      ],
      card?: [
        default: false,
        doc:
          "Each card of the grid shows the tree of the primary `:card` of the page, in view mode: the nodes before `tabs`, without `related` and `attachments` (`:grid` only). Without it, the grid has its own record tree.",
        type: :boolean
      ],
      presentation: [
        default: :modal,
        doc:
          "How the card opens (`:card` only): `:modal` over the page, `:drawer` at the side of the page, or `:page` on the full page without the list.",
        type: PyroManiac.Dsl.Type.presentation()
      ]
    ],
    private_fields: [
      "__editable?__": [
        default: false,
        doc: "Whether the view names a write action. Set by the transformer.",
        type: :boolean
      ],
      __actions__: [
        default: [],
        doc: "The names of the write actions of the view. Set by the transformer.",
        type: {:list, :atom}
      ],
      __tree__: [
        default: [],
        doc:
          "The record tree in view mode (the read action of the view), resolved. Set by the transformer.",
        type: {:list, :any}
      ],
      __arguments__: [
        default: [],
        doc:
          "The public arguments of the read action, as resolved inputs. Set by the transformer.",
        type: {:list, :any}
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  alias PyroManiac.Dsl.Transformers

  @view_types [:data_table, :grid, :card, :calendar, :gantt, :kanban, :list, :timeline, :render]
  @default_orientations %{timeline: :vertical, kanban: :horizontal}
  @single_types [:card]
  @list_types [:data_table, :grid, :card, :calendar, :gantt, :kanban, :list, :timeline]

  @doc false
  def __set_defaults__(view) do
    {:ok,
     view
     |> Map.update!(:label, fn
       nil when view.name == [] -> nil
       nil -> Transformers.default_label(hd(view.name))
       label -> label
     end)
     |> Map.update!(:on_create, fn
       nil -> :none
       v -> v
     end)
     |> Map.update!(:on_update, fn
       nil -> :none
       v -> v
     end)
     |> Map.update!(:on_destroy, fn
       nil -> :none
       v -> v
     end)
     |> Map.update!(:on_bulk, fn
       nil -> :none
       v -> v
     end)
     |> Map.update!(:orientation, fn
       nil -> Map.get(@default_orientations, view.type)
       v -> v
     end)}
  end

  @doc "Returns the list of valid view types."
  def view_types, do: @view_types

  @doc "The types of a single view: one record."
  def single_types, do: @single_types

  @doc "The types of a list view. A `:card` shows one card for each record."
  def list_types, do: @list_types

  @doc """
  The primary views of the views of a page: `%{single:, list:}`.
  The list is the primary list-only view, else the primary single view.
  `nil` for a kind without one.
  """
  @spec primaries([struct()]) :: %{single: t() | nil, list: t() | nil}
  def primaries(views) do
    primary = for %__MODULE__{primary?: true} = view <- views, do: view
    single = Enum.find(primary, &(&1.type in @single_types))
    list = Enum.find(primary, &(&1.type not in @single_types)) || single
    %{single: single, list: list}
  end
end
