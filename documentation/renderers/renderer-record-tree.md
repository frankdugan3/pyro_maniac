# Record Tree

The **record tree** is the nodes of a view. One tree serves view mode (the
read action of the view) and the form of each write action that uses it
(the actions of a card without nodes). An action with nodes has its own
tree, of the same nodes. The cards, the grids, the list items, and the
actions have the same nodes. This guide is the contract of a renderer for
the tree and each node. For the UI, the DSL, and the design expectations,
refer to [The record layout](../tutorials/record-layout.md).

## The tree

| Node | View mode | A form (edit mode) |
|---|---|---|
| `section :name` | A block with its `label` (default: the humanized name), `description`, and its own grid. With `path`, one block for each related record. | The inputs; with `path`, a nested form. |
| `row` | The children on one line when there is room. | The same. |
| `compound :name` | The parts, joined by `separator`, with one label. | A fieldset with one legend. |
| `field` `select` `combobox` `input` | The value. | The input. |
| `related :rel` | The related records ([Related records](renderer-pages.md#related-records)). | Read-only. |
| `attachments :name` | The files. | The upload. |
| `workflow` | The state of the record, its transitions, and its history ([Workflow](#workflow)). | Read-only. |
| `tabs` › `tab :name` | One tab at a time. | The same. |
| `step :name` | A section. | One step at a time ([Steps](renderer-actions.md#steps)). |

**Edit** switches the same tree to edit mode in the same place: nothing
moves. Rules for the renderer:

- `only [names]` puts a node in some actions: the read action of the view
  (view mode) and the actions of the tree. A name that is not one of them
  is a compile error. `PyroManiac.Form.Tree.for_action/2` gives the nodes
  of one action; `in_action?/2` tests one node.
- A field that is not an input of the action (a calculation, an aggregate,
  a relationship, an attribute that the action does not accept) is
  **read-only** (`PyroManiac.Form.Tree.read_only?/1`, the private
  `__read_only?__`): its value in both modes.
- `decoration`, `empty_text`, and `link_to` of a field are for view mode.
- `visible?` hides a node by an expression of the record (in edit mode, of
  the form): `PyroManiac.Form.visible?/4`. `__depends_on__` lists the
  fields that it reads (`{:parent, name}` for `parent(name)`), so the
  renderer evaluates it again when one changes. It refers to attributes,
  `^arg(:name)`, and `parent(name)` only: it is evaluated in memory, with
  no query.
- `collapsible?` lets the user close a section; `collapsed?` starts it
  closed.
- **Show all fields** at the end of the card adds the exposed fields that
  the tree does not show (`PyroManiac.Card.extra_fields/1`).

## Walking a tree

- `PyroManiac.Card.tree/1` gives the tree of a view (or of the primary card
  of a page) in view mode, resolved (`__tree__`).
  `PyroManiac.Card.grid_tree/1` gives the nodes of a card of a grid: the
  nodes before `tabs`, without `related` and `attachments`.
- `PyroManiac.Form.Tree` walks a tree: `inputs/1` (the inputs that are not
  read-only), `values/1` (the inputs and the read-only fields), `leaves/1`
  (also `related`, `attachments`, and `workflow`), `tabs/1`, `all/1`,
  `children/1`, `reduce/3`, `map/2`, and `map_down/3`. Use them, so that a
  new entity is handled in one place.
- `PyroManiac.Info.form_layout/1` gives the tree of an action as plain
  maps, for a renderer that is not in Elixir.

## The private fields

The transformers resolve each node. A renderer reads these fields and does
not compute them again:

| Field | Nodes | Meaning |
|---|---|---|
| `__full_path__` | All the nodes | The full path of relationships from the resource of the form to the level of the node (`[]` at the top level). |
| `__depends_on__` | All the nodes but `tabs` and `tab` | The attributes and arguments that `visible?` reads, and `{:parent, name}`. |
| `__allow_nil?__` | Inputs | Whether the attribute or argument allows `nil` (no required mark). |
| `__decoration_refs__` | Inputs | The fields that the `decoration` expression needs. |
| `__read_only?__` | `field` | Not an input of the action: the value in both modes. |
| `__multiple?__` | `field`, `select` | More than one value (an array). |
| `__enum_options__` | `field`, `select` | The options, as `%{value:, label:, description:}` (a `:checkbox` group of a `field`). |
| `__mode__`, `__resource__`, `__relationship__`, `__multiple?__`, `__inputs__` | `combobox` | Refer to [Comboboxes](#comboboxes). |
| `__opts__` | `input` | The options of the input type, validated against its schema. |
| `__destination__` | `related` | The destination resource of the relationship. |
| `__engine__`, `__state__` | `workflow` | Refer to [Workflow](#workflow). |

## Loads

- `PyroManiac.Card.paths/2` gives what a view loads for its tree: each
  value of the tree (in view mode), the label of each linked record, the
  records of `related`, the counts, the `decoration` refs, and the files.
  `PyroManiac.Card.tree_paths/2` gives the same for a tree.
- `PyroManiac.Info.loads_for_form/1` gives what the form of an action
  loads.
- A `workflow` node adds `PyroManiac.Workflow.loads/1` and its `history`
  relationship ([Workflow](#workflow)).
- Each path must be exposed in `loads` of the read action
  ([The surface](../tutorials/surface.md)).

## Fields

- `type`: `PyroManiac.Info.resolve_field_type/3` gives the input of
  `:default` from the Ash type.
- `size`: the content role gives the width of the track (`:code`, `:term`,
  `:name`, `:phrase`, `:prose`); `:auto` comes from the type.
- `autofocus`: the input with the focus when the form opens. Exactly one
  in the tree of each action with inputs, not on a tab after the first.
- `description :inherit` takes the description of the attribute or
  argument as text. The content of `description` and `render` comes from
  `PyroManiac.Content.resolve/2`
  ([Custom renders](renderer-custom-renders.md)).
- `decoration`: a configured decoration or an expression that gives one or
  `nil` ([Decorations](renderer-decorations.md)). `empty_text` (default
  `"—"`) shows for `nil` in view mode.
- `path` puts the input in the nested form of a relationship, with no
  section. In a view that names no write action, `path` reads a related
  record. A `field` of `related` has `source` in place of `path`.
- `link_to`: a read-only relationship field links to its page
  ([Links](renderer-pages.md#links)).

## Selects

Without `options`, the options come from the type: an `Ash.Type.Enum`
(with its labels), a `one_of` constraint, or a `one_of` in the items of an
array (`PyroManiac.Info.enum_options_for/2`). `options` gives values or
`{label, value}` tuples; `prompt` is the text of the empty option. View
mode shows the label of the value.

## Comboboxes

The private fields give the mode:

- `__mode__`: `:select` (the foreign key of a `belongs_to`, or an argument
  that the action passes to `manage_relationship`) or `:free_text` (a
  `:string` or `:ci_string`: the typed text is the value; the options are
  the values that the records already have).
- `__multiple?__`: `true` for select many ([Select many](#select-many)).
- `__relationship__`: select mode, the relationship whose records the
  combobox selects, which view mode shows (its `default_label`, a link
  with `link_to`). A read-only combobox (view mode, or not an input of the
  action) shows the label of the related record, never its key: the
  renderer loads the label with the relationship.
- `__resource__`: the searched resource (the destination).
- `__inputs__`: the inputs that `^input/1` names in `filter` or
  `argument`. When one changes, the renderer searches again.

`PyroManiac.Form.combobox_options/4` runs the search (with the typed text
and the values of the other inputs) and gives `[%{label:, value:}]`: the
`read_action` with its filter, preparations, and policies, the `search`
fields (`contains`, joined with `or`), `filter`, the `argument` values,
`sort`, and `limit` (1 to 100, default 20). `combobox_query/4` gives the
query; `combobox_label/3` gives the label of the current value.

### Select many

A combobox with `__multiple?__: true` selects many records. The renderer
MUST:

- show the selected records as chips in the input (their
  `default_label`), each with a remove button ("Remove Citra"), and the
  search after them; Backspace in an empty search removes the last chip;
- keep the options open after a selection (a multi-select listbox,
  `aria-multiselectable="true"`), mark the selected options
  (`aria-selected="true"`), and not offer a selected record twice;
- submit the list of the selected primary keys (the `value_key`) as the
  value of the argument: the action attaches the new ones and detaches
  the removed ones (`manage_relationship`, for example `type
  :append_and_remove`). An empty list detaches all;
- load the current records of `__relationship__` for an update form and
  for view mode. View mode shows them as a list of labels (links with
  `link_to`).

## Inputs with an input type

`input :name, type` uses an app input type: a module that implements
`PyroManiac.Form.InputType`, or `{module, options}`. PyroManiac validates
the options with `schema/0` at compile time (`__opts__`); `default_size/0`
gives the size for `size: :auto`. The behaviour has no rendering: each
renderer has its own render behaviour for the module.

## Rows and compounds

- A `row` is layout only: its children stay on one line when there is
  room, and wrap as a unit.
- A `compound` in view mode joins its parts with `separator` (default
  `" "`), under one label. In edit mode it is a fieldset with one legend
  (the `label`) and its `description` as help text. With
  `show_labels? true` the labels of the parts show; otherwise they are for
  assistive technology only.

## Sections side by side

A `row` of sections puts them side by side on a wide screen; the renderer
wraps them on a narrow screen. `density :dense` uses narrower tracks.
`max_columns` caps the columns of a section; `max_columns` of an action
caps its whole form.

## Nested records

A `section` with `path` repeats for each record of the relationship: in
view mode a block for each, in edit mode a nested form with **Add** and
**Remove**. The buttons name a record of the destination, not the
relationship: "Add shipment line", "Remove shipment line 2" (the short
name of the destination resource, and the position). An input with `path`
is in the nested form, with no section.
`__full_path__` gives the level of each node. In a nested form, `visible?`
evaluates `parent(name)` on the form above (the `:parent` option of
`PyroManiac.Form.visible?/4`).

## Tabs

- A record has at most one `tabs`, the last node of the top level. The
  nodes before it show on every tab.
- `PyroManiac.Card.tabs/1` gives `[%{name:, label:, count:}]`: of the
  primary card of a page in view mode, or of a tree (the tree of an action
  has the tabs of that action). `count` is a public aggregate or
  calculation, shown in the label.
- The open tab is in the URL (`tab=<name>`).
- In create mode all the tabs show. A tab with an invalid input shows it
  (the count of its errors).
- **Orientation.** `orientation` of `tabs`: `:horizontal` (the default),
  the tab list above the panel, Left and Right move between the tabs;
  `:vertical`, the tab list at the side of the panel, Up and Down move
  between the tabs. The tab list has the `aria-orientation` of the layout
  that shows; a renderer MAY show a vertical tab list above the panel on a
  narrow screen (with `aria-orientation="horizontal"`).

## Attachments

`attachments :name` shows the files of an `AshStorage` attachment
(`has_one_attached` or `has_many_attached`): in view mode the list of the
files, in edit mode the upload with the `attach_*` and `detach_*` actions
of AshStorage. A field with `type :attachment` is a file input for an
`Ash.Type.File` argument; a column with `type :attachment` shows the files
of each row. `PyroManiac.Helpers.humanize_size/1` formats a size.

## Workflow

`workflow` (`PyroManiac.Form.Workflow`) shows the status of the state
machine of the record: [AshStateMachine](https://hexdocs.pm/ash_state_machine)
or [AshWorkflow](https://hex.pm/packages/ash_workflow). The private
`__engine__` (`:ash_state_machine` or `:ash_workflow`) and `__state__`
(the state attribute) tell the renderer what to read.

- **Loads.** `PyroManiac.Workflow.loads/1` gives the fields that the node
  reads: the state attribute, and with AshWorkflow its calculations
  (`:current_step`, `:steps`, `:available_actions`,
  `:pending_deadlines`) that the resource has. The renderer MUST add them
  and the `history` relationship to the loads of the view.
- **States.** `PyroManiac.Workflow.states/1` gives the states of
  AshStateMachine; with AshWorkflow the `:steps` calculation gives the
  steps, `:current_step` the current one. With `type :steps`, the states
  are in a row (`orientation :horizontal`, the default) or in a column
  (`:vertical`); a renderer MAY show a row as a column when there is no
  room. `type :badge` shows the current state only (no orientation).
- **Transitions.** The available transitions: with AshWorkflow the
  `:available_actions` calculation; with AshStateMachine the transitions
  of the state machine whose `from` has the current state. Show a button
  only for a transition that is an action of the view
  (`PyroManiac.Info.actions/2`, for example `action :approve, :discard`)
  and that the actor can run (`Ash.can?/3`); hide the others. A button
  runs its action as any other action of the view: its form, its
  `confirm`, its `state` ([Actions](renderer-actions.md)). After it, the
  node shows the new state.
- **History.** The records of `history`, in time order (newest first),
  each with its time, its actor when the log has one, and the change
  ("Draft → Active"): the same UI as a
  [timeline](renderer-views.md#timelines).
- **Edit mode.** The node is read-only; the transition buttons do not show
  in a form.

## Accessibility

- Each input has a label: its `label`, or with a compound, the legend of
  the fieldset and the labels of the parts (visible with `show_labels?`,
  else for assistive technology only).
- `description` is the help text of the input, referenced by the input
  (for example `aria-describedby`).
- The input with `autofocus` has the focus when the form opens.
- **Headings.** The heading of a section is one level below the heading
  of the record (the card), and a nested section one level below its
  section, so the outline never skips a level, in a full page, a dialog,
  or a card of a grid or a board ([Cards](renderer-views.md#cards)).
- A collapsible section is a disclosure: its heading is a button with
  `aria-expanded`.
- `tabs` is a tab list; the open tab is selected. A tab with an invalid
  input names the errors in text, not by color only.
- Select many: a multi-select listbox (`aria-multiselectable="true"`,
  `aria-selected="true"`), and a remove button with a name for each chip.
- `workflow` `:steps` is an ordered list; the current state is marked with
  `aria-current="step"` and named in text, not by color only.

## Checklist

- [ ] The record tree in view mode and in the form of each action, in the
  same place: sections, rows, compounds, `path`, tabs, steps,
  attachments, `workflow`, `only` (`Tree.for_action/2`), `visible?`,
  read-only fields, `decoration`, `empty_text`, `size`, `autofocus`, and
  **Show all fields**.
- [ ] The `orientation` of `tabs` and of `workflow`, and the
  `step_orientation` of the stepper, with the arrow keys and
  `aria-orientation` of the layout that shows.
- [ ] Each input: `field` types, `select` options, `combobox` (select,
  select many, and free text, its search), `input` with an input type.
- [ ] The loads of the tree (`PyroManiac.Card.paths/2`), of the forms
  (`PyroManiac.Info.loads_for_form/1`), and of `workflow`.
