# Views

A view shows the records of a read action and runs the actions that it
names. `view` is a top-level entity of the page module: there is no
`views do` block, and no `forms` section. The name of a view is its read
action (or `read_action`).

```elixir
view :read do
  type :data_table
  primary? true
  exclude [:id, :description, :target_abv, :target_og, :target_fg]
  column :name
  column :style
  column :status

  action :create, :guard do
    delegate_to BreweryWeb.RecipeLive     # the form of the card of this page
  end

  action :destroy, :discard                # no inputs: a confirmation
end

view :read do
  type :card
  primary? true
  action [:create, :update], :guard       # the tree of the card is their form

  section :recipe do
    field :name, autofocus: true
    select :style
    select :status
    field :batch_count, only: [:read]      # view mode only
  end

  section :targets do
    field :target_abv
    field :target_og
    field :target_fg
    field :description, type: :textarea
  end
end
```

The actions of a view, their forms, and the inputs are in
[forms](forms.md).

## View types

| Type          | What it renders                                                      |
| ------------- | -------------------------------------------------------------------- |
| `:data_table` | Paginated, sortable, filterable table; uses `column` entities        |
| `:grid`       | Card grid: its own record tree, or the primary card of the page (`card? true`) |
| `:card`       | One record (a single view): its record tree (required), in view mode and in the form of each action that uses it. `presentation` |
| `:calendar`   | The records on a calendar (`date_field`, optional `end_date_field`): day, week, and month periods; `granularity` is the first one |
| `:gantt`      | A bar for each record from `start_field` to `end_field` (both required), in `group_by` groups |
| `:kanban`     | Board with swimlanes from the `kan_ban` section of the resource      |
| `:list`       | Tree/outline list, optionally hierarchical via `parent_field`        |
| `:timeline`   | The records as events in time order (`date_field`, optional `end_date_field`); `orientation :vertical` (default) or `:horizontal` |
| `:render`     | Escape hatch: a `render` entity for each renderer (required)         |

A page can have several `:card` views. The related records of a record are
`related` nodes of its record tree. Views do not nest.

## The record tree

The nodes of a view are its record tree: `field`, `select`, `combobox`,
`input`, `section`, `row`, `compound`, `related`, `attachments`,
`workflow`, `tabs` (with `tab`), and `step`. The same entities are the
form of an `action` (refer to [forms](forms.md)).

- **View mode** is the read action of the view: each node shows its value.
- Each write action that uses the tree (a card `action` without nodes) is
  a form of the same tree: an input shows its input, and a `field` that the
  action does not accept is read-only.
- `only [names]` puts a node in some of these actions. The names are the
  read action of the view and the actions of the tree; another name is an
  error.

```elixir
field :batch_count, only: [:read]              # view mode only
field :description, only: [:create]            # in the create form only

section :review do
  only [:create, :update]                      # not in view mode
  field :notes
end
```

- A view that names no write action has no inputs: use `field` for every
  value (also an enum or a foreign key). A `select`, a `combobox`, or an
  `input` in such a view is an error.
- A `:list`, `:kanban`, `:calendar`, `:gantt`, or `:timeline` view has
  `field` entities at its top level. `path` gives a related value: `field :name, path:
  [:recipe]`. A view field has no `source` (a `column` has one).
- A `:data_table` has `column` entities, not a record tree.

## Primary views

A link to the page opens a primary view.

- Each page has one primary single view: `primary? true` on a `:card`.
- At most one list view (`:data_table`, `:grid`, `:calendar`, `:gantt`,
  `:kanban`, `:list`, `:timeline`) can have `primary? true`: the primary list view.
  Without one, the primary card is also the primary list view (one card
  for each record).
- A `:render` view is not a primary view.

## Cards

- A card has its own record tree. A card without nodes does not compile.
- `action [:create, :update]` without nodes: the tree of the card is the
  form of each action. **Edit** switches the card to the update form in the
  same place. A card without a write action is in view mode only.
- An `action` with nodes in a card has its own tree: a button of the card
  opens it (`presentation`).
- **Show all fields** (`PyroManiac.Card.extra_fields/1`) gives the exposed
  fields of the read action of the card that its tree does not show.
- A `:grid` has its own record tree, or `card? true`: each card shows the
  tree of the primary card, the nodes before `tabs`, without `related` and
  `attachments`.

The card is in the URL of its page:

| Param              | Meaning                              |
| ------------------ | ------------------------------------ |
| `card=<id>`        | The primary card                     |
| `card=<view>:<id>` | Another card of the page (its action) |
| `edit`             | The card in its update form          |
| `tab=<name>`       | The open tab of the record tree      |

`PyroManiac.Card.param(page, view, id)` encodes it;
`PyroManiac.Card.parse_param(page, value)` gives `{:ok, view, id}` or
`:error`.

## View entity reference

`view :name do ... end` — `name` is one or more read action names. May be
a single atom (`view :read`) or a list (`view [:read, :list]`).

Top-level schema (selected; see `PyroManiac.View.View` for the full set):

| Key                                        | Type                               | Notes                                                                        |
| ------------------------------------------ | ---------------------------------- | ---------------------------------------------------------------------------- |
| `type`                                     | atom (one of the view types above) | Required                                                                     |
| `primary?`                                 | boolean (default `false`)          | The primary single view (a `:card`) or the primary list view                 |
| `resource`                                 | Ash resource module                | Defaults to the page's resource                                              |
| `read_action`                              | atom                               | Override which read action backs the view                                    |
| `default_sort`                             | sort spec (string or list)         | e.g. `"name"`, `"-batch_number"`                                             |
| `pagination`                               | pagination spec                    | Auto-detected from the action if not set                                     |
| `default_page_size`                        | `:pos_integer`                     | Falls back to action's `default_limit`, then 25                              |
| `page_sizes`                               | `[pos_integer]`                    | Available page-size options                                                  |
| `exclude`                                  | `[atom]`                           | Fields to exclude from the view                                              |
| `on_create`/`on_update`/`on_destroy`       | PubSub handler spec                | How to handle resource notifications                                         |
| `on_bulk`                                  | `:none`, `:reload`, `:notify`      | How to handle the single message of a bulk operation (needs `bulk`)          |
| `selectable?`                              | boolean (default `true`)           | Enable row selection (list views)                                            |
| `clone?`                                   | boolean (default `false`)          | A **Clone** action for each record (refer to "Clone, new row, and reorder")  |
| `new_row?`                                 | boolean (default `false`)          | An inline new row (`:data_table` only)                                       |
| `reorder?`                                 | boolean (default `false`)          | Drag to reorder (`:data_table`, `:grid`, `:list`)                            |

Entities: the nodes of the record tree, `column`, `action`, `bulk_action`,
`edit_columns`, `extra_action`, `description` (text below the tab of the
view: a text or implementations), and `render`.

A view has no `editable?` option: a view that names a write action is
editable (the private `__editable?__`, and `__actions__`, the names of its
write actions).

The DSL has no `class` options and no functions. A renderer maps the
meaning (`decoration`, `size`) to its own styles.

Type-specific keys:

- `:data_table` — `default_display` (the columns that the user sees by default), `selectable?`, `new_row?`, `reorder?`
- `:grid` — `card?`, `reorder?`
- `:card` — `presentation` (`:modal`, `:drawer`, `:page`)
- `:kanban` — none: `group_by`, `kanban_action`, `priority`, and
  `default_sort` come from the `kan_ban` section of the resource. Setting
  them on the view is an error (refer to [kan_ban](kan_ban.md))
- `:calendar` — `date_field` (required), `end_date_field` (a span),
  `granularity`: the period that the calendar opens with (`:day`, `:week`,
  or `:month`); the user switches between the three
- `:gantt` — `start_field` and `end_field` (required), `progress_field`, `group_by`
- `:list` — `parent_field`, `reorder?`
- `:timeline` — `date_field` (required), `end_date_field` (a span),
  `orientation`: `:vertical` (the events from top to bottom, the default)
  or `:horizontal` (the events from left to right, on a scrollable time
  axis). The content of an event is the record tree of the view
- `:render` — a `render` entity for each renderer (required), and `loads`

## `render`, `description`, and `label`

The content of a node is its `render`, its `description`, and (on a
column) its `label`. Each is an entity with three forms
(`PyroManiac.Content`):

- `render "text"`: the literal text, for every renderer.
- `render expr(...)`: an Ash expression on the record, for every renderer.
  Its refs are validated (like `decoration`) and loaded with the record.
- `render Renderer, implementation`: the implementation for one renderer.
  It overrides the text or the expression for that renderer.

```elixir
column :status do
  label "Stage"
  description "The production stage of the batch."
  render expr(if status == :cancelled, do: "Cancelled", else: "In production")
  render PyroManiac.LiveView, BreweryWeb.Cells.Status
end

view :read do
  type :render
  loads [:status]
  render PyroManiac.LiveView, BreweryWeb.Components.StatusBadge
  render PyroManiac.Solid, "~/components/StatusBadge"
end
```

- A node has at most one text or expression, and one implementation for
  each renderer, for each key. A node with a text or an expression
  satisfies every renderer.
- A view has no record: its own `render` and `description` are a text or
  implementations, no expression.
- The inputs (`field`, `select`, `combobox`, `input`, in a view or in a
  form) take `render Renderer, implementation` only.
- `description :inherit` (views, columns, inputs, actions, bulk actions) takes the
  description of the attribute, the argument, or the action, as a text.
- `description` is an entity, not a keyword option: `field :notes do
  description "..." end`, not `field :notes, description: "..."`. It is on
  views, columns, inputs, sections, compounds, steps, `related`,
  `attachments`, actions, bulk actions, and the `page` section.
- `label` is an entity on a column only (default: the capitalized name).
  The other nodes have `label` as a string option.
- `render` is an entity of views, columns, the values of a record tree
  (`field`, `select`, `combobox`, `input`), compounds, sections, `related`,
  steps, `tabs`, `tab`, and extra actions.
- An implementation is any term. The renderer validates it (a module, an
  import path, a tuple of a module and its options). It is not a bare
  keyword list: the DSL reads it as the options of the entity. Wrap it:
  `{BreweryWeb.Components.StatusBadge, props: [size: :sm]}`.
- A renderer reads the content with `PyroManiac.Content.resolve/2`. Refer
  to the renderer guide `documentation/renderers/renderer-custom-renders.md`.

## `column` (data_table only)

Columns are interactive — users sort, filter, hide, and reorder them.

```elixir
column :name
column :status do
  filterable? true
  decoration expr(cond do
    status == :retired -> :danger
    status == :active -> :success
    true -> nil
  end)
end
```

| Key                          | Default        | Notes                                                                 |
| ---------------------------- | -------------- | --------------------------------------------------------------------- |
| `name`                       | required       | Attribute, calculation, or aggregate                                  |
| `source`                     | `[name]`       | Path; allows relationship traversal                                   |
| `type`                       | `:default`     | One of `:default`, `:textarea`, `:attachment`                         |
| `sortable?`                  | `true`         | Auto-disabled if technically unsortable                               |
| `keyset_sortable?`           | `true`         | Auto-disabled if technically unsortable                               |
| `filterable?`                | `true`         | Auto-disabled if technically unfilterable                             |
| `decoration`                 | nil            | A decoration, or an Ash expression that gives one or `nil` (see below) |

Entities: `label` (the header; default: the capitalized name),
`description` (its help text), `render` (the cell), `link_to`, and
`action` (an inline edit). `label`, `description`, and `render` take a
text, an expression, or `Renderer, implementation`.

```elixir
column :actual_abv do
  label "ABV"
  description "Measured alcohol by volume."
end
```

### Inline edits

`action :update` in a column, with the inputs of the cell, edits the cell
in place. One action for each column. Its block has inputs only (`field`,
`select`, `combobox`, `input`, `compound`), and the completeness check and
the `autofocus` rule do not apply: the cell submits only its own inputs.
It has no `delegate_to` and no `resource`: it edits the record of the row.
It has a `state` like every action (usually `:discard`).

```elixir
column :status do
  action :update, :discard do
    select :status, autofocus: true
  end
end
```

`edit_columns action, columns, state` edits the cells of some columns of a
row together, with one save. The columns are columns of the view; a column
in `edit_columns` has no `action` of its own.

```elixir
column :target_og
column :target_fg

edit_columns :update, [:target_og, :target_fg], :discard do
  field :target_og, autofocus: true
  field :target_fg
end
```

## `field` (the record tree)

A `field` is one value of the record. In a view without a write action, or
for an attribute that the action does not accept, it shows the value only.
It is the same entity as the `field` input of a form (refer to
[forms](forms.md)).

```elixir
view :list do
  type :list
  field :batch_number
  field :name, path: [:recipe], label: "Recipe"
  field :brew_date, empty_text: "Not brewed"
end
```

| Key          | Default   | Notes                                                   |
| ------------ | --------- | ------------------------------------------------------- |
| `name`       | required  | Attribute, calculation, aggregate, or argument          |
| `label`      | humanized | Display label                                           |
| `path`       | `[]`      | A relative path of relationships: a related value       |
| `size`       | `:auto`   | The content role (`:code` … `:prose`)                   |
| `decoration` | nil       | A decoration, or an Ash expression (see below)          |
| `empty_text` | `"—"`     | Shown in view mode when the value is nil                |
| `only`       | nil       | The actions that show it (`[:read]`: view mode only)    |
| `visible?`   | nil       | Conditional visibility: an Ash expression               |

Entities: `description` (the help text: a text, an expression, or an
implementation), `render` (the value in view mode: `render Renderer,
implementation` only, no text or expression), `link_to`.

## `section`

Sections group the nodes of a record tree into logical areas.

```elixir
view :read do
  type :grid

  section :basics do
    field :name
    field :style
  end

  section :stats do
    collapsible? true
    collapsed? true

    field :target_abv
    field :target_og
    field :target_fg
  end
end
```

| Key            | Default        | Notes                                             |
| -------------- | -------------- | ------------------------------------------------- |
| `name`         | required (atom) | The identifier                                   |
| `label`        | humanized name | The heading (`:quality_tests` gives `"Quality Tests"`)          |
| `path`         | `[]`           | One block for each record at the path             |
| `density`      | `:normal`      | `:dense` uses narrower tracks                     |
| `max_columns`  | nil            | The maximum number of columns                     |
| `collapsible?` | `false`        | User can collapse/expand                          |
| `collapsed?`   | `false`        | Starts collapsed (only with `collapsible?: true`) |
| `only`         | nil            | The actions that show it (refer to "The record tree") |
| `visible?`     | nil            | Conditional visibility: an Ash expression         |

Entities: `description` (text below the heading), `render` (the entire
section), and the nodes of the record tree:
`field`, `select`, `combobox`, `input`, `compound :name` (one value of
fields, with `separator`), `row` (values or sections on one line), nested
`section`, `related`, and `attachments`. A nested section shows after the
other nodes of its section or row.

## `related`

The records of a relationship, a node of the record tree.

```elixir
section :ingredients do
  related :recipe_ingredients do
    type :data_table
    limit 25
    field :quantity
    field :notes
  end
end

related :batches do
  delegate_to BreweryWeb.BatchLive
  presentation :modal
  count :batch_count
end
```

| Key            | Default   | Notes                                                        |
| -------------- | --------- | ------------------------------------------------------------ |
| `name`         | required  | Relationship on the resource                                 |
| `type`         | `:list`   | One of `:list`, `:data_table`, `:grid`, `:count`, `:badge`   |
| `presentation` | `:inline` | Where the records show: `:inline`, or `:modal` or `:drawer` over the page |
| `label`        | humanized | Display label                                                |
| `limit`        | nil       | Maximum related records to display                           |
| `count`        | nil       | An aggregate or a calculation: the count in the heading      |
| `delegate_to`  | nil       | A page of the destination, mounted as a delegated viewer     |
| `empty_text`   | `"None"`  | Shown when no related records                                |
| `only`         | nil       | The actions that show it                                     |
| `visible?`     | nil       | Conditional visibility: an Ash expression                    |

Entities: `field` (the columns: `name`, `label`, `source`, `size`,
`decoration`, `empty_text`), `link_to`, `description` (text below the heading), `render`.

## `link_to`

A link navigates to another page. It is an entity on a `column`, a
`field`, a `combobox`, and `related`. One `link_to` for each node. A node
without `link_to` has no link.

```elixir
column :recipe do
  link_to BreweryWeb.RecipeLive             # the primary single view
end

column :recipe do
  link_to BreweryWeb.RecipeLive do
    single_view :list                       # another :card view
  end
end

related :batches do
  link_to BreweryWeb.BatchLive do
    list_view :list                         # all the batches: a filtered list
  end
end
```

| Key           | Default             | Notes                                                 |
| ------------- | ------------------- | ----------------------------------------------------- |
| `page`        | required            | A PyroManiac page of the destination resource         |
| `single_view` | primary single view | A `:card` view of the page                            |
| `list_view`   | primary list view   | A list view of the page. Relationships to many only   |

- To one record: the link opens the single view of the record.
- To many records (`related`): each record links to its single view, and a
  list link opens the list view filtered by the relationship
  (`PyroManiac.Link.list_filter/3`: the foreign key, or the reverse
  `many_to_many`).
- A modal or a drawer over the current page is not a link: use
  `presentation` of `related`.
- The page is not a compile-time dependency. A verifier checks each link
  after everything compiles: the page is a PyroManiac page on the
  destination resource, the views exist, `list_view` is only on a
  relationship to many, and the read action of the list view exposes the
  relationship filter.

## `workflow`

A node of the record tree: the status of the state machine
([AshStateMachine](https://hexdocs.pm/ash_state_machine)) or the workflow
([AshWorkflow](https://hex.pm/packages/ash_workflow)) of the record. The
resource uses one of them; else it is a compile error.

```elixir
workflow do
  type :steps
  history :transitions
end
```

| Key            | Default    | Notes                                                                              |
| -------------- | ---------- | ---------------------------------------------------------------------------------- |
| `label`        | `"Status"` | The heading                                                                        |
| `type`         | `:steps`   | `:steps`: each state, the current one marked; `:badge`: the current state only     |
| `transitions?` | `true`     | Buttons for the transitions that the record can take and that are actions of the view (`action :approve, :discard`) |
| `history`      | nil        | A relationship to the transition log of the record. It shows as a timeline         |
| `only`         | nil        | The actions that show it                                                           |
| `visible?`     | nil        | Conditional visibility: an Ash expression                                          |

Entities: `description`, `render`. `PyroManiac.Workflow` gives the engine
(`engine/1`), the state attribute (`state_attribute/1`), the states
(`states/1`), and the loads (`loads/1`; with AshWorkflow the calculations
`:current_step`, `:steps`, `:available_actions`, `:pending_deadlines`).

## `:timeline`

The records as events in time order. `date_field` is required (the date or
the start of an event); `end_date_field` makes each event a span. The
content of an event is the record tree of the view (top-level `field`
entities, sections). `orientation` is the axis of time: `:vertical` (the
default) or `:horizontal`.

```elixir
view :read do
  type :timeline
  date_field :brew_date
  end_date_field :package_date
  orientation :horizontal
  field :batch_number
  field :status
end
```

## Clone, new row, and reorder

- `clone? true`: a **Clone** action for each record, a create form
  prefilled with the values of the record. The view names a create action.
- `new_row? true` (`:data_table` only): an inline new row at the top of the
  table. The view names a create action, and each required input of it is
  the inline edit of a column (`action :create, :discard do <input> end`).
- `reorder? true` (`:data_table`, `:grid`, `:list`): the user drags the
  records to reorder them when the list is sorted by the rank. The resource
  has `PyroManiac.Ordering` (refer to [ordering](ordering.md)) or
  `PyroManiac.KanBan`. The move action of the resource counts as used by
  the view.

```elixir
view :read do
  type :data_table
  primary? true
  clone? true
  new_row? true

  column :name do
    action :create, :discard do
      field :name, autofocus: true
    end
  end

  column :style do
    action :create, :discard do
      select :style
    end
  end

  action :create, :guard do
    delegate_to BreweryWeb.RecipeLive
  end
end
```

## `decoration`

A column or a value of the record tree can have a `decoration`: the meaning
of the value, not a color. The default decorations are `:neutral`, `:info`,
`:success`, `:warning`, and `:danger`; an application sets its own list at
compile time (`PyroManiac.Info.decorations/0`):

```elixir
config :pyro_maniac, decorations: [:neutral, :info, :success, :warning, :danger, :muted]
```

The value is a decoration or an Ash expression that gives a decoration or
`nil`. The refs of the expression are validated at compile time and loaded
with the rows (they can be calculations or aggregates). A navigation item
or group has a `decoration` too (a decoration only).

```elixir
column :brew_date do
  decoration expr(if status == :planned and brew_date < today(), do: :warning)
end
```

## Common mistakes

- `views do ... end` or `forms do ... end`. They are removed: `view` is top
  level, and the actions are in the views.
- `form :update` on a card. It is removed: `action [:create, :update]` in
  the card, and the nodes of the card are the form.
- A card without nodes. A card has its own record tree.
- `only :view` or `only :edit`. Use the action names: `only [:read]`,
  `only [:create, :update]`.
- `edit_with` on a column. Use `column ... do action :update do <inputs>
  end end`, or `edit_columns`.
- `source` on a `field` of a view. Use `path` (`field :name, path:
  [:recipe]`). `source` is for columns and the fields of `related`.
- `group_by`, `kanban_action`, `priority`, or `default_sort` on a
  `:kanban` view. They come from the `kan_ban` section of the resource.
- A `select`, `combobox`, or `input` in a view that names no write action.
  Use `field`.
- Setting `type` as an inline keyword on `view :read, type: :data_table do`
  fails to compile — always put it inside the block.
- A page without `primary? true` on a `:card`, two primary views of one
  kind, or `primary? true` on a `:render` view.
- Using `column` in a non-table view, or a record tree in a `:data_table`.
- A nested `view`, `relationship`, `lazy?`, `multiple?`, `set`, a
  `:delegated` view, or `delegate_to` on a view. They are removed: use a
  `related` node in the record tree.
- `default_viewer`, card `key`, `link_to false`, `type`/`action` on
  `link_to`, a resource-level `link_to`, or `link_through`. They are
  removed: use `primary?`, and `single_view`/`list_view`.
- `display` on `related`. It is `type` (`:table` is `:data_table`).
- `section "Title" do`. The argument is an atom: `section :title do`, with
  `label "..."` when the humanized name differs.
- `render MyModule` or `component`/`props` on a `:render` view. Use
  `render Renderer, implementation`.
- A `class`, `cell_class`, `header_class`, or `render_cell_data` option, or a
  function for `render`. They are removed: use `decoration`, `size`, or a
  `render` entity.
- `tone`. It is renamed `decoration`.
- `clone?` or `new_row?` on a view that names no create action, `new_row?`
  without a column inline edit for a required input of the create action,
  or `reorder?` on a resource without `PyroManiac.Ordering` or
  `PyroManiac.KanBan`.
- A `:timeline` or a `:calendar` without `date_field`, a `:gantt` without
  `start_field` and `end_field`, or a `workflow` node on a resource
  without AshStateMachine or AshWorkflow.
- `granularity` on a view that is not a `:calendar`, or `orientation` on a
  view that is not a `:timeline`. Each is a compile error.
- `description: "..."` as a keyword (`field :notes, description: "..."`),
  or `label:` on a column (`column :abv, label: "ABV"`). They are entities:
  `field :notes do description "..." end`, `column :abv do label "ABV" end`.
- An expression in the own `render` or `description` of a view, or a text
  or an expression in the `render` of an input of a form. A view has no
  record; an input takes `render Renderer, implementation` only.
