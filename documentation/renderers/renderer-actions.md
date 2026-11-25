# Actions

The contract of the actions of the views: the trees of their forms, the
unsaved-changes state, the confirmations, the inline edits, the bulk
actions, clone, the new rows, reorder, and the extra actions. For the
design expectations (the UI and the DSL of each), refer to the
[Actions](../tutorials/views.md#actions) of the Views tutorial.

## The forms of the actions

`action name, state` (one name or a list) in a view names a write action
of the resource: create, update, destroy, or a generic action. Its tree is
the form of the action. A read action is the name of a view, not an
`action`. The `state` is required ([Unsaved changes](#unsaved-changes-guard-and-recovery)):
the second argument (`action :update, :guard`) or an option in the block
(`state :guard`).

| In | The tree | The UI |
|---|---|---|
| a card, without nodes | The tree of the card. A `select`, `combobox`, or `input` on an attribute that the action does not accept is read-only, as a `field`. | Create: **+ New** opens the empty tree. Update: **Edit** switches the card to the form, in the same place. An action without an input in the tree (a transition) is a button with its `confirm`. |
| a card, with nodes | Its own tree. | A button of the card opens the form (`presentation`). |
| a list view, with nodes | Its own tree. | Create: a toolbar button. The others: a button on each row. |
| a list view, `delegate_to Page` | The tree of the action of the same name in a view of `Page`. This page: its card. | The same buttons. |
| a list view, an action without inputs | None. A destroy or a status change. | A row button. It asks first only with `confirm` ([Confirmations](#confirmations)). |
| a column (`column ... do action ..., state do ... end end`) | Its own tree: inputs only (`field`, `select`, `combobox`, `input`, `compound`). No `delegate_to`, no `resource`. | An inline edit of the cell ([Inline edits](#inline-edits)). |
| `edit_columns action, columns, state` | Its own tree, inputs only. | The cells of the columns, edited together. |

An action in a list view with inputs and no tree is a compile error: a
list view has no record tree to use.

| Option | The UI |
|---|---|
| `state` | Required: `:guard`, `:recover`, or `:discard`. What happens to the unsaved inputs ([Unsaved changes](#unsaved-changes-guard-and-recovery)). |
| `confirm` | A confirmation before the action runs: a text, or an expression of the record that gives the message or `nil` ([Confirmations](#confirmations)). |
| `label` | The button and the title of the form (default: the humanized name). Two actions of a view have different labels. |
| `description` | An entity: the text below the title (a text, an expression of the record, or an implementation for one renderer). `description :inherit` takes the description of the action. None by default. |
| `presentation` | Where an own tree opens: `:modal` (the default), `:drawer`, or `:page`. |
| `width` | The width of a `:modal` or a `:drawer` (an intent: `:full`, `:record`, `:form`, `:prose`); `:record` by default. With `:page`, the width of the page. |
| `step_orientation` | The stepper of a tree with `step` entities: `:horizontal` or `:vertical`; without it, the `step_orientation` of the view ([Steps](#steps)). |
| `max_columns` | The maximum number of columns of the whole form. |
| `resource` | An action of another resource: for example a new quality test from the row of a batch. |
| `set :name, :source` | With `resource`: the form gets the value `source` of the record of the row for `name`, on submit. No input. |
| `set :name, :source, overridable?: true` | The value fills the input `name` when the form opens; the user can change it. The tree has an input of that name (a compile error otherwise). |
| `delegate_to` | The tree of the same action in a view of another page (or of this page). Not with nodes. |

**Completeness.** For each action, the transformer checks the nodes of its
tree (after `only`):

- each accepted attribute and each public argument of the action is an
  input, or has a `set` (an inline edit is exempt: it changes some values);
- exactly one input has `autofocus` (when the tree has inputs), not on a
  tab after the first (an inline edit is exempt: the renderer focuses the
  input of the cell that the user opened);
- each name is a field or an argument of the action; a value is once in
  the tree;
- an `Ash.Type.File` argument has a `field` with `type :attachment`.

The errors read `view -> action -> name`.

**Initial values.** A create form starts from the static default of each
input (the `default` of the attribute or the argument), and an update form
from the record. An input that the user did not touch submits that value:
it MUST NOT submit an empty value in place of a default.

**Errors.** The renderer shows the errors of Ash:

- An error of an input (an invalid value, a required value) shows at the
  input ([Accessibility](renderer-record-tree.md#accessibility)), in plain
  text ("is required"), without the internals of Ash (the bread crumbs,
  the module of the error).
- An error of a field that is not in the form, or of the action, shows
  above the form.
- Any other error (the data layer, the network, a bug) MUST NOT show its
  message or its stack: they can hold internal details (SQL, paths). The
  user gets a generic message ("The action failed."), and the server logs
  the error. A forbidden action says so ("You cannot do this.").

**Functions.**

- `PyroManiac.Info.actions/1`: each action of the page, one entity for each
  action name and view, the actions of the cards first. Each has
  `__view__` (`{name, type}` of its view), `__column__` (the column of an
  inline edit), and `__columns__` (of `edit_columns`). `actions/2`: the
  actions of one view.
- `PyroManiac.Info.action_for/2` (by name, a card first) and `action_for/3`
  (by name and resource); `actions_for_resource/2`; `action_for_type/2`
  and `action_for_type/3` (the first create or update).
- `PyroManiac.Card.actions/1`: the actions of the primary card.
- `PyroManiac.Info.form_fields/1`: the inputs of an action.
  `PyroManiac.Info.action_field_info/3`: the attribute or argument of an
  input. `PyroManiac.Info.field_allow_nil?/2`: whether it is required (the
  `*`).
- `PyroManiac.DataLoader.run_action/4` submits a form.
- Each action entity has `state`, `confirm`, and `__confirm_refs__` (the
  fields that a `confirm` expression reads).

## Unsaved changes: guard and recovery

The UI and the DSL: [Unsaved
changes](../tutorials/views.md#unsaved-changes-guard-and-recovery).

**MANDATORY.** Each `action`, `bulk_action`, inline edit (the `action` of
a column), and `edit_columns` has a required `state`, with no default. A
renderer MUST implement each value:

| `state` | The renderer |
|---|---|
| `:guard` | Warns before the user leaves a form with unsaved changes. |
| `:recover` | Keeps the inputs, and restores them after a reload or a lost connection. |
| `:discard` | Neither: the inputs go when the form closes. |

A form is **dirty** when the value of an input differs from its value when
the form opened (a value typed and erased again is not a change). A form
is clean again after a successful submit or a Cancel.

**Guard.** With a dirty `:guard` form, the renderer MUST ask before each
way of leaving it, with a dialog that names the form ("Discard the changes
to B-2026-043?") and two buttons, **Keep editing** (the default focus) and
**Discard**:

- a navigation in the app: a link, a tab of the page or of the record, a
  change of `card`, Back and Forward, a nav item, the command palette;
- closing the form: ×, Escape, a click outside a modal or a drawer,
  **Cancel** of an update form that switches the card back to view mode;
- the browser unload (a reload, a closed tab, an external link): the
  `beforeunload` event of the browser, whose text the browser chooses.

A failed submit keeps the form dirty. The guard does not ask after a
successful submit.

**Recover.** With a `:recover` form, the renderer MUST keep a draft of the
inputs while the user types, and restore it:

- The draft is in the client (for example the session storage of the
  browser), keyed by the page, the view, the action, and the record: for
  example `pyro_maniac:form:BreweryWeb.BatchLive:list:complete:<id>`, with
  `new` for a create. The key SHOULD also have the actor (on a shared
  computer, another user does not get the draft).
- After a reload or a lost connection (a LiveView reconnect, a new
  WebSocket), the form opens again with the draft, and a notice says so
  ("Unsaved changes restored", with **Discard**). A form that opens again
  later for the same record and action restores the draft the same way.
- The draft is cleared on a successful submit, on **Cancel** or × of the
  form, and on **Discard** of the notice. It SHOULD expire (for example
  after one day).
- The draft MUST NOT keep a password input (`type :password`) or the
  files of an upload: they stay empty after a restore.
- A draft that is not valid any more (an input that is not in the form,
  a record that is gone) is dropped.

A renderer MAY use the form recovery of its framework (for example the
reconnect recovery of Phoenix LiveView) for a lost connection, and the
client storage for a reload.

**Discard.** No warning and no draft.

An inline edit has its state too. A dirty `:guard` cell warns when the
user leaves the row or the page; Escape on a cell is an explicit cancel
(no warning). Most inline edits are `:discard`.

## Confirmations

The UI and the DSL: [Confirmations](../tutorials/views.md#confirmations).

An action never asks on its own: every confirmation is in the DSL. A
renderer MUST NOT add a confirmation or a default message.

- **No inputs.** An action of a view (a row, the toolbar, a card; not an
  inline edit of a column) or a bulk action without an input in its tree
  runs from its button. It MUST set `confirm`: a message, an expression,
  or `confirm false` (no confirmation). Without it the page does not
  compile ("action :start_brewing has no input, so its button runs it at
  once").
- **`confirm`.** An action or a bulk action with `confirm` asks before it
  runs: an action without inputs, when its button is pressed; a form, on
  submit, after the form is valid in the client.

| `confirm` | The message |
|---|---|
| none | No confirmation for a form. A compile error for an action without inputs. |
| `false` | No confirmation: the action runs at once. |
| `"text"` | The text. |
| `expr(...)` | The value of the expression on the record (and `^arg(:name)` for the inputs of the form). `nil`: no confirmation, the action runs at once. |

`__confirm_refs__` lists the fields that the expression reads: the
renderer MUST load them with the record (they are not in
`PyroManiac.Info.build_loads_from_view/2`). Evaluate the expression with
`Ash.Expr.eval/2` on the loaded record, as for a decoration. For a bulk
action the expression has no single record: evaluate it on the first
selected record, or show its text form; the message SHOULD name the count
("Advance 3 batches?").

The dialog is an `alertdialog` with the message as its description,
**Cancel** first in the focus order, and the action button with the label
of the action (a destroy with the `:danger` decoration).

## The tree of a card

The UI and the DSL: [The tree of a card](../tutorials/views.md#the-tree-of-a-card).

A card without action nodes is the form of each write action that it
names. `only` gives the differences: the read action of the view is view
mode.

- The tree of each action is `PyroManiac.Form.Tree.for_action(view.fields,
  name)`; `PyroManiac.Info.action_for/2` gives it resolved. View mode is
  `PyroManiac.Card.tree/1`.
- A value is once in the tree of an action, after `only`. An aggregate or
  a calculation is a value, not an input: read-only in a form.
- An action of a card with nodes or `delegate_to` is a button of the card
  that opens its own tree (its `presentation`). The card contract (**Edit**,
  the view mode, the dialog) is in [Cards](renderer-views.md#cards).

## Actions of a list view

The UI and the DSL: [Actions of a list
view](../tutorials/views.md#actions-of-a-list-view).

A list view has no record tree of its own for a form. Its actions have
their own tree, `delegate_to`, or no inputs:

- A create on the resource of the view is a toolbar button. The other
  actions are row buttons; the action runs on the record of the row.
- An action without inputs (no accepted attribute, no public argument)
  has no form: a destroy, `:start_brewing`, `:activate` of a recipe. Its
  button runs it. It sets `confirm` (a message, or `confirm false`), else
  the page does not compile ([Confirmations](#confirmations)). A destroy
  with inputs needs a tree.
- `delegate_to` this page uses the tree of the card for the same action.
- A transition of a state machine (AshStateMachine, AshWorkflow) shows on
  a record only when the state of the record is in its `from` states, and
  the actor can run it ([Workflow](renderer-record-tree.md#workflow)).

`PyroManiac.Info.actions/2` gives the actions of the view. An action with
`fields: []` has no form: its button runs it, after its `confirm`. With `delegate_to`, the entity
has the delegated tree already.

## Own trees and other resources

The UI and the DSL: [Own trees and other
resources](../tutorials/views.md#own-trees-and-other-resources).

An action with nodes has its own tree, in any view. With `resource`, it is
an action of another resource; `set` fills a value from the record of the
row, with no input. A create on another resource is a row button.

With `overridable? true`, a `set` is a default, not a fixed value: the
renderer fills the input of `name` with the value `source` of the record
when the form opens, and the user can change it. The input shows and
submits as any input. Without it, the value is added to the params on
submit, and no input shows it.

## Steps

The UI and the DSL: [Steps](../tutorials/views.md#steps). The nodes of a
step are in [The record tree](renderer-record-tree.md).

`step :name` divides a tree into steps: in a form one step at a time, with
**Back** and **Next**; in view mode each step is a section. A step has
`label`, `description`, `path` (its inputs are in the nested form of the
path), `density`, `max_columns`, `visible?` (a step that the form skips),
and `render`. `review? true` makes a read-only summary of the steps before
it (the last step only). A tree has steps or other nodes at the top level,
not both.

- **Next** validates the inputs of the current step with the validation of
  the action (Ash, on the server), not in the client only. A step with an
  error stays, with the errors at its inputs.
- A failed submit on the last step goes to the first step with an error,
  so the user sees it.

The stepper (the list of the steps, with the current one marked) has the
`step_orientation` of the action, else of the view: `:horizontal` (the
default), a row above the form; `:vertical`, a column at the side of the
form. A renderer MAY show a row as a column (or a compact "Step 2 of 4")
when there is no room.

## Inline edits

The UI and the DSL: [Inline edits](../tutorials/views.md#inline-edits).

`action name, state` in a column edits its cell: the cell switches to
the inputs of the block, and a change runs the action on the record of
the row. One action for each column. `edit_columns action, columns, state`
edits the cells of some columns of a row together, with one save; a
column in it has no `action` of its own. Both have inputs only (`field`,
`select`, `combobox`, `input`, `compound`), and no completeness check:
they change some values. `autofocus` is optional: the input of the cell
that the user opened gets the focus. The `action` of a column has no
`delegate_to` and no `resource`: it edits the record of the row. Both
carry a `state` ([Unsaved changes](#unsaved-changes-guard-and-recovery)).
A column `action` of a create action is a cell of the new row
([New rows](#new-rows)).

The entity of an inline edit has `__column__` (the action of a column) or
`__columns__` (`edit_columns`).

A table with inline edits is a `role="grid"`: the arrow keys move between
the cells, Enter or F2 starts the inline edit of a cell, Escape cancels it
([Data tables](renderer-views.md#data-tables)).

## Bulk actions

The UI and the DSL: [Bulk actions](../tutorials/views.md#bulk-actions).

`bulk_action :name, state` (one name or a list) is a form for the
selected rows of a list view: an update or a destroy action. It has the
required `state` ([Unsaved changes](#unsaved-changes-guard-and-recovery)),
`confirm` ([Confirmations](#confirmations)), `label` (the button), `description` (an entity; `description :inherit` takes the
description of the action), `max_columns`, `delegate_to` (the bulk action of
the same name on another page), and inputs, `section`, `row`, `compound`,
and `step` (no `related`, no `attachments`, no identity field). Its
`only` names the bulk action. A bulk action without inputs is a button,
and it sets `confirm` (a message, or `confirm false`). With `set_all_fields? false` (the default) an empty
input is left out, so it does not change the records; `true` submits each
input, as a normal form. A bulk action uses its action
([The actions of the page](renderer-pages.md)).
`PyroManiac.Info.bulk_actions/1` (each with its `__view__`) and
`bulk_action_for/2` give them.

The selection (the row checkboxes, "2 selected", **Clear**) is in [Data
tables](renderer-views.md#data-tables).

## Clone

The UI and the DSL: [Clone](../tutorials/views.md#clone).

`clone? true` on a view adds a **Clone** button to each record (a row of a
table, a card of a grid, an item of a list, a card). The view names a
create action (a compile error otherwise); with more than one, the first.

- **Clone** opens the form of that create action (its tree, its
  `presentation`, its `state`), filled from the record: each input of the
  form whose name is an attribute of the record gets the value of the
  record.
- Not copied: the primary key, the fields that are not inputs of the
  create action (calculations, aggregates, attributes that it does not
  accept), the files of an upload, and the nested forms (`path`) unless
  the renderer copies them as new records. An argument that is not an
  attribute starts empty (or with its default).
- The renderer loads the values: the attributes of the inputs of the
  form (`PyroManiac.Info.form_fields/1`) that the view does not load.
- The form is a create: its title is the label of the action (for
  example "New recipe"); a unique value (an identity) is not changed by
  the renderer, so the submit can fail with the error on its input.
- The form is dirty only after a change of the user: closing it with the
  copied values only needs no guard.

## New rows

The UI and the DSL: [New rows](../tutorials/views.md#new-rows).

`new_row? true` on a `:data_table` adds an inline new row at the top of
the table. The view names a create action, and each required input of it
(an accepted attribute or a public argument with `allow_nil? false` and
no default) is the inline edit of a column: `column :name do action
:create, :discard do field :name end end` (a compile error otherwise).

- The new row has the inputs of the columns with an `action` of the
  create action (the entities with `__column__` and that action name), and
  empty cells for the other columns. Its first input gets the focus when
  the user opens it (**+ Add row**, or a click on the row).
- Tab and Shift+Tab move between its inputs; Enter saves; Escape cancels
  (its `state` applies to the unsaved values).
- Save runs the create action with the values of all its inputs, in one
  submit. An error shows on its cell (`aria-invalid`, the message with
  `aria-describedby`); an error of a field without a cell shows on the
  row.
- After a save, the new record shows as a row (the `on_create` of the
  view, else at the top until the next reload), and the new row is empty
  again for the next record, with the focus on its first input.

## Reorder

The UI and the DSL: [Reorder](../tutorials/views.md#reorder).

`reorder? true` on a `:data_table`, `:grid`, or `:list` lets the user
order the records by hand. The resource has `PyroManiac.Ordering` (or
`PyroManiac.KanBan`) (a compile error otherwise);
`PyroManiac.Ordering.Info.ordering/1` gives `%{attribute:, scope:,
move_action:, algorithm:}`. The move action is a use of the page: it needs
no `action` and no `exclude`.

- **When.** Reordering is on only when the sort of the list is the rank
  attribute ascending, with no other sort (`"position"`). With a `scope`,
  the filter of the list also has one value of the scope (for example
  `recipe_id` equal to the recipe; a `related` list of the recipe is
  scoped already): a move does not cross scopes. Otherwise the handles are
  disabled, with the reason ("Sort by position to reorder") and a button
  that sets the sort.
- **Drag.** Each record has a drag handle (a button with the label "Move
  Citra"). The drop position shows while dragging.
- **Keyboard.** The handle is also the keyboard alternative: Space or
  Enter picks the record up, Up and Down arrows move it, Space or Enter
  drops it, Escape cancels. The renderer MAY also offer **Move up**,
  **Move down**, and **Move to end** in the menu of the record. A live
  region announces each step ("Citra, position 2 of 4") and the result.
- **The move.** A drop runs the move action on the moved record, with
  its public arguments `target_id` (the ID of the record next to the
  drop) and `placement`: `:before` (before the target), `:after` (after
  the target), or `:last` (the default: the end of the scope; no target).
  For example `Ash.Changeset.for_update(record, move_action, %{target_id:
  target.id, placement: :before})`. They are inputs, so a client runs the
  move over RPC as any other action. The database computes the rank. A
  kanban move takes the same arguments
  ([Kanban boards](renderer-views.md#kanban-boards)).
- **After.** The renderer SHOULD move the record at once (an optimistic
  move), and MUST NOT show it at its old place while the move runs (no
  jump back and forth on a drop). It applies the result or the
  notification of the update, and puts the record back with the error on
  a failure (for example a policy). A board MUST move at once
  ([Kanban boards](renderer-views.md#kanban-boards)).
- **Pages.** A drop on the first record of a page is `"before"` it; on the
  last, `"after"` it. A move to another page is **Move to end**
  (`"last"`) or the keyboard across pages; the list stays on its page.

## Extra actions

The UI and the DSL: [Extra actions](../tutorials/views.md#extra-actions).

`extra_action :name` (with a `label`) adds a custom action:

- in the `page` section: a button of the page toolbar;
- in a view: a button of each row of a data table, or of the card of a
  record.

`render` gives the whole action for a renderer: its button and its content
(a modal, a panel). The implementation gets the action, the base path, the
params, and (on a row) the record. Without `render`, the renderer shows a
link button and a generic action. `PyroManiac.Info.page_extra_actions/1`
and `PyroManiac.Info.view_extra_actions/1` give them.

The implementations of `render` and their verifier are in [Custom
renders](renderer-custom-renders.md).
