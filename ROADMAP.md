# Roadmap

The planned work of PyroManiac. Each feature is authorized as every action
interface is: with the scope of the user, no exceptions
([Authorization](documentation/renderers/renderer-overview.md#authorization)).

## Kanban

`PyroManiac.KanBan` orders the cards of a lane with a fractional index (a
`:string` rank) and moves a card with one atomic update. Today it supports
the AshPostgres data layer: the `pyro_fractional_key_between` PL/pgSQL
function (`PyroManiac.KanBan.PostgresExtension`) computes the rank in the
database, `PyroManiac.KanBan.MoveCard` updates the card in one statement,
and the setup adds a custom index on the lane and the rank (`COLLATE "C"`,
byte order).

Support for the other official Ash data layers:

| Data layer | Status | Work |
|---|---|---|
| AshPostgres | Supported | — |
| ETS (`Ash.DataLayer.Ets`) | Partial | The rank expression runs in Elixir (`PyroManiac.KanBan.Expressions.FractionalKeyBetween`). `MoveCard` and the index setup are for Postgres only: a move in Elixir (read the neighbours, compute the key, update), and no index. |
| Mnesia (`Ash.DataLayer.Mnesia`) | Planned | As ETS: the rank in Elixir, the move in a Mnesia transaction (the read of the neighbours and the update together). |
| AshSQLite | Planned | The rank as an expression that SQLite can run (or in Elixir), the move in one statement or a transaction, and an index on the lane and the rank with byte-order collation (`BINARY`). |
| AshCSV | Planned | The rank in Elixir, the move as a read and an update of the file (no concurrent writers), and no index. |

For each data layer:

- `PyroManiac.KanBan.Expressions.FractionalKeyBetween` gives the rank for
  the data layer (or computes it in Elixir).
- `PyroManiac.KanBan.MoveCard` moves a card without a lost update: in one
  statement where the data layer can, else in a transaction, else with the
  limits written down.
- The setup transformer adds the index of the lane and the rank where the
  data layer has indexes, with byte-order comparison of the rank.
- The tests of `PyroManiac.KanBan` run on the data layer.

Dynamic lanes (a `belongs_to` lane) and the lane resources of
`PyroManiac.KanBan.Lanes` use the same rank and move setup: on the other
data layers they follow the same table.

Planned board features:

- **WIP limits per lane.** A maximum number of cards in a lane (an option
  for static lanes, an attribute of a lane record for dynamic lanes). The
  board shows the limit in the lane header and marks a lane over it; a
  validation can refuse a move into a full lane.
- **Swimlanes.** A second grouping: rows across the lanes by another field
  (for example the assignee), each cell the cards of one lane and one row.

## Ordering

`PyroManiac.Ordering` (`reorder?` on `:data_table`, `:grid`, and `:list`)
uses the same rank and move setup as Kanban, and has the same data layer
limits: AshPostgres only today.

- The other data layers (ETS, Mnesia, AshSQLite), as in the Kanban table.
- Other algorithms than `:fractional_index` (for example integer positions
  with renumbering, for small lists that an app reads by position).

## Lists

New view types and list features.

- **Pivot / aggregation view.** `view type :pivot`: rows and columns are
  fields, the cells are measures (sum, count, average) from Ash aggregates
  with a group by.
- **Charts.** A chart view or a chart on a list view: bar, line, and pie
  charts of the records or of aggregates. The DSL gives the data; each
  renderer chooses the chart library.
- **Column summaries.** A summary per column (`:sum`, `:avg`, `:count`,
  `:min`, `:max`) in a footer row of a `:data_table`, over the filtered
  records, not only the page.
- **Row grouping with subtotals.** Group the rows of a list by a field (the
  user can change it, as the columns), with a subtotal row per group from the
  column summaries.
- **Map / geo view.** `view type :map`: records as markers from a location
  field (or latitude and longitude fields), with a popup of the view's fields.
- **Drag reparent in a tree.** A `:list` with `parent_field` shows a tree,
  and `reorder?` orders the siblings. Missing: a drop on a node makes it
  the parent, through a `reparent_action` (an update action that accepts
  the parent field). The keyboard alternative indents and outdents. The
  action refuses a cycle (a node under its own descendant).

## Search

- **Cross-resource search.** One search box that finds records of several
  resources (a job, a part, a lot by number) and opens the primary card of
  the result. Each resource declares the fields it is searched by. Full-text
  search where the data layer has it (Postgres `tsvector` with AshPostgres),
  a simple `ilike` match else. The command palette is the natural place for
  it.
- **Facet counts.** Next to each value of a filter, the number of records
  that the value would give with the other active filters, for example
  "Status: Active (12), Draft (3)". The user sees how many records each
  choice gives before choosing it, and does not choose a value that gives
  no records. The counts come from an aggregate per value (group by) on the
  current query.

## History and undo

Optimistic UI is done by Ash and is not in this plan.

- **History behaviour.** A module that the app implements and names in the
  DSL; it gives the versions of a record (the values, the actor, the time,
  the action). Integrations out of the box for AshPaperTrail, Ash temporal
  actions and attributes, and AshEvents. An app can write its own (for
  example for its own audit trail).
- **Restore version.** An action that reverts a record to a past version,
  through an Ash action of the resource (so policies and validations apply).
- **History view.** A timeline of the versions of a record, and a diff
  between two versions.

## Record navigation

A single view opened from a list has no previous and next record. Missing:

- Previous and next buttons in the context of the list that opened the
  view: the same filter, sort, and page.
- The position in the list ("3 of 120").
- Keyboard shortcuts for previous and next (in the
  [keyboard shortcuts](#keyboard-shortcuts)).
- Across pages of the list: the next record after the last one of a page is
  the first one of the next page (offset and keyset).
- When the list is not known (a direct link to the record), no previous and
  next.

## Workflow

The `workflow` node shows the status and the transitions of AshStateMachine
and AshWorkflow. If useful, more of AshWorkflow: the display of the pending
deadlines, and the forms of the steps.

## Navigation

- **Count badges.** A `badge` on a navigation item: a count from a read
  action of a resource (an aggregate, with a filter, for example the open
  NCRs), with a `decoration`. The count is read with the scope of the user,
  and it updates with the realtime topics of the resource.
- **Breadcrumbs.** The trail from the navigation tree (the group and the
  item of the page) and the open card (the records of the `link_to` chain).
  The renderer derives it; the DSL has an option to turn it off.
- **Multitenancy UI.** A tenant switcher in the navigation: the tenant
  resource, its read action, and its label field. The renderer sets the Ash
  tenant of the scope and keeps it across the routes. A user sees only the
  tenants that the read gives with the scope.

## Dashboards

- **Dashboards and widgets.** A `PyroManiac.Dashboard` DSL module (as
  `PyroManiac.Navigation`), with a route as a page: a grid of widgets. A
  widget is a view of a page (a list, a chart), a metric, or a `:render`.
- **Metrics / KPI.** A `metric` widget: a value from an aggregate or a
  calculation of a read action (count, sum, average), with a filter, a
  comparison with a previous period (the trend), a target (the progress), a
  `decoration` by thresholds, and a link to the filtered list.
- **Dynamic editing.** Users build and change dashboards, views, pages, and
  widgets at run time. The DSL gives the base; a user configuration is a
  layer over it.
  - Storage: a resource for the configurations, as `PyroManiac.FilterPresets`
    for the filters today. The custom filters (`custom_filters?`,
    `filter_storage`, `shared_filters?`) move into this storage.
  - Access: the owner, the sharing, and the roles, by the Ash policies of
    the storage resource.
  - Validation: a stored configuration uses only the surface of the
    resources (the exposed actions and fields), as the DSL does at compile
    time. A configuration that a change of the DSL breaks falls back to the
    base, with a message.

## Collaboration

- **Edit conflicts.** Optimistic locking: an Ash `optimistic_lock` on a
  version attribute refuses a stale write; the form shows the conflict (the
  current values and the user's values) and lets the user reload or apply
  the change again. With realtime, an open form warns when its record
  changes. UI locking (optional): a lock while a user edits a record, with
  the holder shown (presence) and a timeout.
- **Comments and activity stream.** An abstraction (a behaviour, as the
  history behaviour) that gives the entries of a record: comments, changes,
  workflow transitions, and attachments, in one stream. A composer creates a
  comment with an Ash create action. The stream updates in realtime.
- **Notifications.** In-app notifications for a user (a mention, an
  assignment, a workflow step): a resource that stores them, the unread
  count as a navigation badge, mark as read, and a link to the record. The
  delivery is realtime.

## Translations

- **Labels.** The literal strings of the DSL (labels, titles,
  descriptions, enum labels, confirmations, empty texts) are the msgids of a
  configured translator (a Gettext backend). Each renderer translates with
  it. A mix task extracts the strings of the DSL.
- **Locales.** The formats of numbers, dates, times, and currencies by the
  locale of the scope, as the time zone of the scope today.

## Keyboard shortcuts

A unified shortcut system for the app. Today only the hotkey of the
`command_palette` exists.

- `shortcut` on `action`, `extra_action`, `bulk_action`, and `command`, and
  the built-in shortcuts (the views, previous and next record, the filter,
  the save).
- Scopes: global, page, view, and dialog. The DSL rejects two shortcuts of
  one scope with the same keys.
- A list of the shortcuts (`?`), and the shortcut next to each command in
  the command palette.
- Accessibility: a single-key shortcut is off by default, or the user can
  turn it off or change it (WCAG 2.1.4).

## Import and export

- **Export (CSV, XLSX).** A list view exports its visible columns, with the
  active filter and sort, and all the records (not only the page), as a
  stream. The read runs with the scope of the user; the fields are those of
  the surface.
- **Import (CSV, XLSX).** The columns of a file map to the inputs of a
  create action (or an upsert by an identity). A preview shows the errors of
  each row before the import. The import runs `Ash.bulk_create/4` with the
  scope, and reports the result of each row.
