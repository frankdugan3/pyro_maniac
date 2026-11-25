# Views

The contract of the views: the options and the loads of every list view,
the frame of a list view, and the UI of each view type. For the design
expectations (the UI and the DSL of each type), refer to the
[Views](../tutorials/views.md) tutorial. For the actions of the views,
refer to [Actions](renderer-actions.md).

A list view shows the records of a read action. Its `type` gives the
layout; every type has the same [frame](#the-frame-of-a-list-view): the
filter bar, the actions, the pages, the empty state. The `:card` is the
single view of a record ([Cards](#cards)); it is a list view only when the
page has no other primary list view.

| Type | Section | Tutorial |
|---|---|---|
| `:data_table` | [Data tables](#data-tables) | [Data tables](../tutorials/views.md#data-tables) |
| `:grid` | [Grids](#grids) | [Grids](../tutorials/views.md#grids) |
| `:card` | [Cards](#cards) | [Cards](../tutorials/views.md#cards) |
| `:calendar` | [Calendars](#calendars) | [Calendars](../tutorials/views.md#calendars) |
| `:gantt` | [Gantt charts](#gantt-charts) | [Gantt charts](../tutorials/views.md#gantt-charts) |
| `:timeline` | [Timelines](#timelines) | [Timelines](../tutorials/views.md#timelines) |
| `:kanban` | [Kanban boards](#kanban-boards) | [Kanban boards](../tutorials/views.md#kanban-boards) |
| `:list` | [Lists](#lists) | [Lists](../tutorials/views.md#lists) |
| `:render` | [The render view](#the-render-view) | [The render view](../tutorials/views.md#the-render-view) |

The searches (the quick chips of the filter bar) are in [Filters and
sorts](renderer-filters-and-sorts.md); the realtime options of a view are
in [Pages](renderer-pages.md).

## The options of every list view

| Option | The UI |
|---|---|
| `label`, `description` | The tab of the view, and text below it. `description` is an entity: a text, or an implementation for one renderer (a view has no record, so no expression). |
| `read_action` | The read action, when it is not the name of the view. |
| `resource` | Another resource than the resource of the page. |
| `exclude` | The exposed fields of the read action that the view does not show. (The actions that the page does not use are in `page exclude`.) |
| `default_sort` | The first sort: a sort input string (`"-batch_number"`) or a sort list ([Filters and sorts](renderer-filters-and-sorts.md)). |
| `pagination` | `:offset` (numbered pages), `:keyset` (next and previous), or `:none`. Without it, the action decides (`PyroManiac.DataLoader.pagination_type/3`). |
| `default_page_size`, `page_sizes` | The first page size, and the sizes that the user can select. |
| `count?` | The total count ("1–25 of 112"). Default: `true` for offset pages. |
| `ensure_loaded` | Loads that the view always adds (for a `render`, or an extra action). |
| `field` | The values of each item of a calendar, a gantt, a timeline, a kanban, or a list. `path` reads a related record: `field :name, path: [:recipe]`. |
| `action` | A toolbar button (create) or a row button (the others), with its form, or without inputs with its `confirm` ([Actions of a list view](renderer-actions.md#actions-of-a-list-view)). |
| `bulk_action` | A button for the selected records ([Bulk actions](renderer-actions.md#bulk-actions)). |
| `edit_columns` | Some cells of a row, edited together ([Inline edits](renderer-actions.md#inline-edits)). |
| `extra_action` | A button on each record ([Extra actions](renderer-actions.md#extra-actions)). |
| `clone?` | A **Clone** button on each record: the create form, filled from the record ([Clone](renderer-actions.md#clone)). |
| `new_row?` | An inline new row at the top of a `:data_table` ([New rows](renderer-actions.md#new-rows)). |
| `reorder?` | Drag handles on the records of a `:data_table`, `:grid`, or `:list`, when the list is sorted by the rank ([Reorder](renderer-actions.md#reorder)). |
| `selectable?` | A checkbox on each record for the bulk actions (default `true`). |
| `on_create`, `on_update`, `on_destroy`, `on_bulk` | The notifications ([Pages](renderer-pages.md)). |

- **Loads.** `PyroManiac.Info.build_loads_from_view/2` gives the loads of a
  view: its values, the labels of its links (`PyroManiac.Info.link_paths/2`),
  the attachments, and `ensure_loaded`. `PyroManiac.DataLoader.load_list/3`
  reads a page.
- **Surface.** The page uses only the exposed surface of the resource
  (refer to [The surface](../tutorials/surface.md)); the transformers check
  it. Restrict the sort and the filter that the user selects with
  `PyroManiac.Surface.restrict_sort_input/3` and
  `PyroManiac.Surface.restrict_filter/3` ([Filters and sorts](renderer-filters-and-sorts.md)).
- **Values.** A cell or a value without `render` shows
  `PyroManiac.View.Column.render_cell_data/1` or
  `PyroManiac.Presenter.present/2`. A view that names no write action
  shows values only: each `field` is read-only, and a `select`,
  `combobox`, or `input` is a compile error.
- **Editable.** A view that names a write action (`action`,
  `edit_columns`, the `action` of a column) is editable: its private
  `__editable?__` is `true`, and `__actions__` lists the names.

## The frame of a list view

Each type puts its records in its own layout, inside the same frame. The
sections of the types refer to it, and say only what differs.

- **The tabs.** The list views of a page are tabs (`label`), with the
  `description` below the tab. The open tab is in the URL.
- **Width.** A view fills its width:
  `PyroManiac.Info.view_width/2`, the `width` of the view, else the
  `width` of the page, `:full` by default (the whole content area). The
  widths are intents (`:full`, `:record`, `:form`, `:prose`); the renderer
  maps each one to its own size, as the decorations. A renderer MUST NOT cap
  a `:full` view at a reading width. The prose (the title and the
  description of the page, the description of a view) keeps a readable line
  length whatever the width of the view.
- **Orientation.** A `:horizontal` orientation (a board, a timeline, the
  tabs, a stepper, the navigation) is a preference: a renderer MAY fall
  back to the vertical layout when there is no room (a narrow screen). The
  arrow keys and `aria-orientation` MUST follow the layout that shows.
- **The filter bar and the sort.** The same filter bar, chips, presets,
  and URL state for each type ([Filters and sorts](renderer-filters-and-sorts.md)).
  The sort is in the headers of a table, and in a sort menu for the other
  types. A type whose order is its axis (a calendar, a gantt, a
  timeline, a board) has no sort menu, or a sort for the order inside a
  day, a lane, or a group.
- **The actions.** A create action is a toolbar button; the other actions,
  the extra actions, and **Clone** are on each record: buttons on a row,
  or a menu (⋯) on a card, an event, a bar, or a line ([Actions of a list
  view](renderer-actions.md#actions-of-a-list-view), [Extra
  actions](renderer-actions.md#extra-actions)). With bulk actions and
  `selectable?` (the default), each record has a checkbox, and the bulk
  actions show for the selected records ([Bulk
  actions](renderer-actions.md#bulk-actions)).
- **A record.** Activating a record (a click, or Enter on the focused
  record) opens the primary card (`card=<id>`, [Cards](#cards)). Its
  links (`link_to`) are links, and do not open the card.
- **The empty state.** No records MUST show a message in place of the
  records, not an empty frame. Without a filter: "No batches yet", and the
  create button when the view has one. With a filter: "No batches match
  the filter", and **Clear the filter**.
- **Loading.** The first read SHOULD show a placeholder of the layout. A
  later read (a filter, a page, a period) MUST keep the records on the
  screen until the new ones arrive, with `aria-busy="true"` on the view
  and a busy indicator. An error of the read (a policy, the network) shows
  a message with **Retry**, and keeps the filter.
- **Pages.** A table, a grid, a list, and the cards have the page controls
  of the action (`pagination`, `count?`, `page_sizes`). A board loads each
  lane (`per_lane`); a timeline loads more at its end; a calendar and a
  gantt read the records of their visible range.
- **Accessibility.** Each record has an accessible name (its label,
  `PyroManiac.Resource.Info.record_label/3`). A meaning of a decoration or
  of a position (a lane, a day, a bar) is also text. A drag has a keyboard
  alternative ([Reorder](renderer-actions.md#reorder)).

## Data tables

The UI and the DSL: [Data tables](../tutorials/views.md#data-tables).

The renderer:

- MUST render a `<table>` (or `role="grid"` when the cells have inline
  edits): `<th scope="col">` headers, and `aria-sort` on the sorted
  header. A sortable header is a button. With `role="grid"`, the arrow
  keys move between the cells, Enter or F2 starts the inline edit of a
  cell, Escape cancels it.
- MUST show the columns of `default_display` at first (all the columns
  without it), and SHOULD offer a column menu to show, hide, and reorder
  the others. A column SHOULD also move with a drag of its header (the
  drop position shows across the height of the table); the column menu
  is its keyboard alternative. The choice of the user SHOULD stay (the URL
  or the storage of the renderer).
- A column of a relationship sorts by the label of the related record (a
  path, `recipe.name`, in the exposed `sort`), never by the relationship
  itself ([Sorts](renderer-filters-and-sorts.md#sorts)).
- The row checkbox (`selectable?` and bulk actions) has the label of the
  record ("Select B-2026-044"); the header checkbox selects the page. The
  selection SHOULD stay across the pages, with a count ("2 selected") and
  **Clear**.
- A long text (`type :textarea`) is clipped to one line, with the full
  text on focus or in the card.
- On a narrow screen, the table SHOULD scroll on its own (the first column
  sticky), or change to one card for each row.
- The empty state, the loading, and the pages are those of [the
  frame](#the-frame-of-a-list-view); the count is above or below the rows.

The inline edits of the cells are in [Inline
edits](renderer-actions.md#inline-edits), the new row in [New
rows](renderer-actions.md#new-rows).

## Cards

The UI and the DSL: [Cards](../tutorials/views.md#cards). The URL params
of a card (`card`, `edit`, `tab`) and its `presentation` are in
[Pages](renderer-pages.md).

The renderer:

- **Read.** MUST read the record by its ID with the read action of the
  view and the loads of the view (`PyroManiac.Info.build_loads_from_view/2`),
  for the actor. A record that does not exist and a record that the actor
  cannot read MUST give the same "Not found" message, in the card, with the
  list behind it unchanged.
- **Header.** The label of the record
  (`PyroManiac.Resource.Info.record_label/3`) is the heading of the card
  (`<h2>` in a modal or a drawer, `<h1>` on a full page). The header has
  **Edit** (when the card names an update action), the action buttons, the
  extra actions, and **Close** (not on a full page).
- **View mode.** Each node shows its value ([The record
  tree](renderer-record-tree.md)). **Show all fields**
  (`PyroManiac.Card.extra_fields/1`) shows the exposed fields that the
  tree does not show.
- **Edit mode.** **Edit** adds `edit` to the URL and puts the same tree in
  the form of the update action, in the same place: the inputs replace the
  values, the focus goes to the input with `autofocus`. **Save** runs the
  action; **Cancel** and Escape return to view mode, after the
  [unsaved-changes guard](renderer-actions.md#unsaved-changes-guard-and-recovery).
- **Modal and drawer.** A modal or a drawer MUST be a dialog
  (`role="dialog"`, `aria-modal="true"`, labelled by its heading): the
  focus goes into it when it opens and stays in it, Escape closes it, and
  the focus returns to the element that opened it (the row, the event, the
  card of the grid). Close removes `card` from the URL. The width of the
  dialog is the `width` of the view (an intent, as the
  [width](#the-frame-of-a-list-view)), `:record` by default
  ([Card presentation](renderer-pages.md#card-presentation)).
- **Headings.** The headings of a card follow the outline of the page: the
  label of the record is one level below the heading that the card is
  under (`<h1>` on a full page, `<h2>` in a dialog over the page), and the
  headings of its sections one level below it. A card inside a grid or a
  board is one level below the heading of its view or its lane. A level is
  never skipped.
- **Previous and next.** Refer to [Pages](renderer-pages.md).

When the primary card is the list view, the renderer shows one card for each
record of the list (a column of cards, or a grid of them on a wide
screen), in view mode, with the filter bar and the pages of a list view
([Filters and sorts](renderer-filters-and-sorts.md)). Activating a card
opens it (`card=<id>`); a card that names an update action SHOULD also
have **Edit** in the list, which opens it with `edit`. **New** (the create
action of the card) is a toolbar button. The empty state, the loading, and
the selection are those of [every list view](#the-frame-of-a-list-view).

The actions of a card are in [The tree of a
card](renderer-actions.md#the-tree-of-a-card).

## Grids

The UI and the DSL: [Grids](../tutorials/views.md#grids).

`PyroManiac.Card.tree/1` gives the nodes of a grid card (`__tree__` of the
view); `PyroManiac.Card.grid_tree/1` prunes a card tree for a grid (with
`card? true`: the nodes of the primary card before `tabs`, without
`related` and `attachments`).

The renderer:

- MUST lay the cards out in columns that fit the width (one column on a
  phone), in the order of the sort, row by row. A card is a list item of
  the grid (`<ul>`, or `role="list"`), with the label of the record as its
  heading, under a heading that names the view (it MAY be visually
  hidden).
- The whole card opens the record (one link or button for the card, not a
  link for each value); the links of its values (`link_to`) stay links
  inside it. The actions of the record are in a menu (⋯) of the card.
- The arrow keys SHOULD move the focus between the cards (left and right,
  and up and down by a row of the grid); Tab leaves the grid.
- With `reorder? true`, a drop position is between two cards; the keyboard
  alternative moves a card one place before or after ([Reorder](renderer-actions.md#reorder)).
- The empty state, the loading, and the pages are those of [the
  frame](#the-frame-of-a-list-view).

## Calendars

The UI and the DSL: [Calendars](../tutorials/views.md#calendars).

The renderer:

- **The periods.** A calendar MUST have the three periods, and a period
  switcher (Day, Week, Month: a group of toggle buttons with
  `aria-pressed`, or tabs). `granularity` is the first one. The period
  and the date SHOULD be in the URL (a param of the renderer), so a reload
  and Back give the same period.
  - **Month**: a grid of weeks (`role="grid"`, a column header for each
    weekday, a cell for each day, the days of the other months dim). The
    weeks start on the first day of the week of the locale.
  - **Week**: seven columns, one for each day of the week, with every
    event of each day.
  - **Day**: one day, with every event and its fields in full.
- **Navigation.** **Previous** and **Next** move by one period (a month, a
  week, a day); **Today** goes to the period of today. The heading names
  the period ("November 2026", "Nov 16 – 22, 2026", "Thursday, November
  19, 2026") and is a live region (`aria-live="polite"`), so a move is
  announced. The renderer SHOULD offer a date picker (a small month) to go
  to a date.
- **Today.** The day of today MUST be marked (`aria-current="date"`, and a
  style), in each period.
- **Spans.** A span MUST cover each day from its start to its end. In a
  month or a week, it is one bar for each week that it crosses, with the
  same lane in each day of the week; a bar that starts before the visible
  range or ends after it SHOULD show it (‹ ›, and the dates in the day
  view). The order in a day: the earlier start first, then the longer
  span, then the sort of the view.
- **Times.** With a `:date` field, each event takes the whole day. With a
  datetime field, the week and the day views SHOULD place the events at
  their times (an hour grid), and the month shows the time before the text.
  The times show in the time zone of the user.
- **Overflow.** A day of the month has room for a few lanes (three, for
  example). The other events of the day MUST be reachable: "+2 more", a
  button that opens a popover (or the day view) with every event of the
  day. The week and the day views show every event.
- **The events.** An event is a button or a link with an accessible name
  of its fields and its dates ("B-2026-044, Hazy Daze IPA, November 12 to
  November 25"). Activating it opens the card. The actions of the record
  are in a menu of the event, or in the card.
- **Keyboard.** In the month grid the arrow keys move between the days
  (Page Up and Page Down by a month, Home and End to the start and the end
  of the week); Enter on a day opens its events; Tab goes to the events
  of the focused day.
- **The visible range is the read.** The calendar reads only the records
  of its visible range (the whole weeks of a month, the week, the day): the
  renderer adds the range to the filter of the user (and), as a filter
  input on `date_field` and `end_date_field`. For the month of the figure,
  the range is October 26 to December 6:

  ```elixir
  %{"and" => [
    %{"brew_date" => %{"less_than_or_equal" => "2026-12-06"}},
    %{"or" => [
      %{"package_date" => %{"greater_than_or_equal" => "2026-10-26"}},
      %{"brew_date" => %{"greater_than_or_equal" => "2026-10-26"}}
    ]}
  ]}
  ```

  The range is not a chip of the filter bar and not in the `f` param; a
  change of the period reads again, and keeps the filter. The
  `date_field` and the `end_date_field` SHOULD be in the exposed `filter`
  of the read action ([Filters and sorts](renderer-filters-and-sorts.md));
  else the renderer filters the records that it reads.
- **Pages.** A calendar has no page controls: the renderer reads every
  record of the range (each page in turn with a paginated action). The
  filter bar, the actions, and the empty state ("No batches in November
  2026") are those of [the frame](#the-frame-of-a-list-view).

## Gantt charts

The UI and the DSL: [Gantt charts](../tutorials/views.md#gantt-charts).

The DSL has no dependencies between the bars and no milestones. A chart
with them is a `:render` view ([The render view](#the-render-view)).

The renderer:

- **Layout.** A table at the left (the `field` entities, one row for each
  record) and the time scale at the right, with the same rows. The scale
  has a header of the periods (days, weeks, months) and a line for today.
  The table and the chart scroll together up and down; the chart scrolls
  left and right on its own, and the table stays.
- **Scale.** The renderer SHOULD fit the range of the records at first,
  and offer zoom levels (days, weeks, months) and **Today**. The scale is
  in the time zone of the user.
- **Groups.** With `group_by`, the rows are in groups, in the order of the
  values (the order of an enum, else the sort), each with a heading row;
  a group SHOULD be collapsible.
- **Open bars.** A record without an `end_field` value SHOULD show a
  marker at its start and "no end date"; a record without a start has no
  bar, and SHOULD stay in the table ("not scheduled").
- **Bars.** A bar is focusable, with an accessible name of its fields and
  its dates ("B-2026-044, Hazy Daze IPA, November 12 to November 25");
  Enter opens the card. The table is a `role="treegrid"` (with groups) or
  a `<table>`; Up and Down move between the rows.
- **Move and resize.** When the view names an update action that accepts
  the `start_field` and the `end_field`, the renderer MAY let the user drag
  a bar (both dates) or its ends (one date). The keyboard alternative: with
  the bar focused, Left and Right move it by one unit of the scale, Shift
  with Left and Right changes its end. The drop runs the action, and puts
  the bar back with the error on a failure.
- **The read.** As a calendar, a gantt reads the records that overlap
  its visible range ([Calendars](#calendars)), with no page controls. The
  filter bar, the actions, and the empty state are those of [the
  frame](#the-frame-of-a-list-view).

## Timelines

The UI and the DSL: [Timelines](../tutorials/views.md#timelines).
`PyroManiac.Card.tree/1` gives the content of an event.

The renderer, for both orientations:

- The events MUST be in time order: the sort of the view (`default_sort`,
  or the sort of the user), else `date_field` descending.
- An event has its date as text, not as its position only. A span shows
  its start and its end ("Nov 5 → Nov 30"); a span without an end is
  open ("since Nov 12"). The times are in the time zone of the user.
- An event is focusable, with an accessible name of its fields and its
  dates; Enter opens the card. The actions of the record are in a menu of
  the event.
- The filter bar, the actions, and the empty state are those of [the
  frame](#the-frame-of-a-list-view). A filter or a sort change starts
  again at the first page.

**Vertical** (`orientation :vertical`, the default): a list of the events
from top to bottom.

- The timeline is a list (`<ol>`, or `role="list"`); each event is a list
  item.
- The renderer SHOULD group the events by day, with a heading for each day
  (`<h3>`), and by month for a long range (a month heading above its
  days); the time of an event shows in the event.
- Pages: the timeline loads more events at its end (**Load more**, or
  more at the scroll end with keyset pages). The focus stays on the last
  event read before the new ones.

**Horizontal** (`orientation :horizontal`): a time axis from left to right
that scrolls. A renderer MAY show the vertical timeline when there is no
room ([the frame](#the-frame-of-a-list-view)).

- The axis has a header of the periods (days, weeks, months), a line for
  today, and the events in lanes: a span is a bar from its start to its
  end, an event without a span is a point (a marker with its text), and an
  open span runs to the end of the visible range. Two events that overlap
  are in two lanes.
- Zoom levels (days, weeks, months) SHOULD change the scale, with the
  center of the view kept; **Today** scrolls to today.
- Keyboard: the axis is focusable; Left and Right scroll it, Page Up and
  Page Down by a screen, Home goes to today, + and − zoom. Tab moves
  through the events in time order, and the axis scrolls to the focused
  event. A scroll button (‹ ›) and a scrollbar are for the pointer.
- The axis reads the records of its visible range, as a calendar
  ([Calendars](#calendars)), and reads more as it scrolls.
- For a screen reader, the events are also a list in time order (the
  same items as the vertical timeline, visually hidden or in the
  accessible name of each event).

## Kanban boards

The UI and the DSL: [Kanban boards](../tutorials/views.md#kanban-boards).

A `:kanban` needs the `PyroManiac.KanBan` extension on the resource. The
`kan_ban` section gives the board; the transformer sets `group_by`,
`priority`, and `kanban_action` of the view from it, and `default_sort` to
the priority. These options on a `:kanban` view are a compile error.

`PyroManiac.KanBan.Info` gives each option (`lane!/1`, `priority!/1`,
`move_action!/1`, `read_action!/1`, `per_lane/1`, `count?/1`,
`lane_read_action/1`, `lane_action/2`, `lane_sort/1`, `manage_lanes?/1`).
The renderer
MUST read the lanes with `PyroManiac.KanBan.Info.lanes/2`: a list of
`%{value:, label:, record:}`, in order. Static lanes are the values of the
attribute (`record: nil`); dynamic lanes are the lane records (`value` is
the primary key, `label` the record label). The cards group by
`PyroManiac.KanBan.Info.lane_attribute!/1`: the `lane` attribute, or the
foreign key of a `belongs_to` lane. The board
uses the same rank machinery as `PyroManiac.Ordering`:
`PyroManiac.Ordering.Info.ordering/1` also gives the rank (the
`priority`), the scope (the `lane`), and the move action of a kanban
resource. The move action of a board takes the arguments `target_id` and
`placement`, as [Reorder](renderer-actions.md#reorder). A card moves with
the keyboard too: the keyboard alternative of
[Reorder](renderer-actions.md#reorder), plus moves to the next lane, with
the keys below (**Keyboard**).

The read action of the board has the public argument `lane_value`. Each
view of a read action with public arguments has them as resolved inputs
in its private `__arguments__`: the renderer can offer controls for them.

The renderer:

- **Lanes.** A lane for each item of `lanes/2`, in order. A lane is a
  list (`role="list"`) labelled by its header: the label, and the count
  with `count?`. An empty lane stays: it is a drop target, with "No
  cards". The board has a heading that names the view (it MAY be visually
  hidden), and the heading of each lane is under it.
- **Orientation.** `orientation :horizontal` (the default): the lanes side
  by side; the board scrolls left and right, and each lane scrolls on its
  own (up and down). `orientation :vertical`: the lanes stacked as rows,
  the cards of a lane from left to right; each row scrolls left and right.
  The keyboard of a move follows the layout: in a vertical board, Left and
  Right move a card in its lane, Up and Down to the lane above or below.
- **Cards.** Each lane reads its own cards: the `read_action` of the
  `kan_ban` section with the `lane_value` of the lane, sorted by the
  priority, `per_lane` at a time, and **Load more** at the end of the
  lane (a read of that lane only). The content of a card is the record
  tree of the view (its `field` entities); every card, of every lane and
  of every page of a lane, has its label, its menu, and its decorations.
  Activating a card (a click, or Enter) opens the primary card, and its
  actions are in a menu of the card.
- **Filters.** The filter of the user applies to each lane and to its
  count; the lanes stay. The order in a lane is the priority: a board has
  no sort menu.
- **Move.** A drop shows its position between two cards (a bar in the
  space between them), and runs the move action (in the table above):
  `before` or `after` a card, or `last` in a lane without cards.
  - The renderer MUST put the card at its drop at once, and MUST NOT show
    it at its old place while the move runs: a card never jumps back and
    forth on a drop. A pointer drop SHOULD slide the card from the place
    of the drag preview (where the user let it go), not from its old place
    or the pointer.
  - After the move, the renderer reads that card again (the read of the
    view: the move action does not give the fields of the view) and keeps
    it at its new place.
  - On a failure (a policy, a validation of the new lane) it MUST put the
    card back, and show the error.
  - The space between two cards holds the drop bar: the cards MUST NOT
    move while the bar shows.
- **Keyboard.** Space picks a card up and Enter opens it. With the card
  picked up, the arrows move it (Up and Down in its lane, Left and Right
  to the next lane, in a horizontal board), Space or Enter drops it, and
  Escape cancels. A live region announces each step ("B-2026-047,
  Brewing, position 2 of 2") and the result.
- **Realtime.** The change of a card has its position: the action, the
  lane and the rank after the change, and the lane before an update
  ([Realtime](renderer-pages.md#realtime)). With the rank as the order of
  the lanes, the renderer places the card itself and does not read the
  lanes again:
  - It reads the one card again (for the viewer), and puts it in its lane
    at the place of its rank. The ranks compare by their bytes: the rank
    column has the `C` collation, so the order of the database is the
    byte order. A card after the last card read of a lane that has more
    is left to **Load more**.
  - The counts of the lanes change with the card (from its lane before to
    its lane after).
  - A change that gives the lane and the rank that the board shows already
    is the echo of a move of this user: nothing changes.
  - The renderer reads the lanes again only when it cannot place the card:
    `:reload`, a bulk message, a sort that is not the rank, or a lane that
    it cannot know (a card that it did not show, with a filter of the user
    that the card may not match).
  - A move of a lane is at once too, and does not read the cards.
- **Moves of others.** With `track_presence? true`, a card that a user
  picks up is on the presence of the move action, with its drop target
  ([Presence](renderer-pages.md#the-page)). The other users see:
  - the card marked as moving, with the user (a name, or an avatar with a
    text name); the mark MUST NOT change the size of the card or move the
    other cards;
  - the drop target, a bar at its place, in a style that is not the drop
    bar of their own drags;
  - nothing else: no card moves on their screen before the drop. The drop
    is a change like any other.
- **Motion.** A card that changes its place (a drop, a change of another
  user) SHOULD slide from its old place to the new one, and its
  neighbours to theirs; the card of a drop SHOULD flash once it is there.
  Only a change of the order or of a lane animates: a presence update, a
  read of a card, or a scroll does not. With `prefers-reduced-motion`,
  nothing slides; the flash stays.
- **The empty state.** A board without cards shows its lanes, with the
  message of [the frame](#the-frame-of-a-list-view) above them.

### Dynamic lanes

The UI and the DSL: [Dynamic lanes](../tutorials/views.md#dynamic-lanes).

A `lane` that is a `belongs_to` gives dynamic lanes: the records of its
destination are the lanes (`PyroManiac.KanBan.Info.dynamic_lanes?/1`). The
destination is an existing resource (the stages of a project) or a lane
resource with `PyroManiac.KanBan.Lanes` (`id`, `name`, `decoration`, the
order, and the actions `read`, `create`, `update`, `destroy`, and `move`).
`PyroManiac.KanBan.Info.lane_resource/1` gives the destination.

- **The lanes.** `lanes/2` reads them with the `read_action` of the
  `lane` (`lane_read_action/1`; default: the primary read action of the
  lane resource), sorted by its `sort` (`lane_sort/1`; default: the rank
  of the lane resource when it is ordered), with the
  `actor`, the `tenant`, and `authorize?` of the page. For the lanes of a
  scope (the lanes of one project), the renderer MUST pass `query:` (a
  query of the lane resource with the filter of the scope).
- **No lane.** When the foreign key allows `nil` and a card has none, the
  board MUST show a lane "No lane" (`value: nil`); it SHOULD be first. It
  has no lane controls. A drop on it sets the foreign key to `nil`.
- **The move of a card.** A drop on a dynamic lane runs the kanban move
  action with the foreign key (`lane_attribute!/1`) set to the `value` of
  the lane, and the arguments `target_id` and `placement`.
- **Decoration.** A lane record with a `decoration` styles its header
  ([Decorations](renderer-decorations.md)).

The `lane` resolves the lane actions at compile time:
`PyroManiac.KanBan.Info.lane_action(resource, :create | :update |
:destroy | :move)` gives each one, or `nil` (turned off with `false`, or
no default on the lane resource). The board MUST offer the control of
each lane action that is not `nil`, and none of the others
(`manage_lanes?/1`: one of `:create`, `:update`, `:destroy` is set). It MUST hide a control that the
actor cannot run (`Ash.can?/3`):

- **Add lane** (`:create`). A button after the last lane: a name input
  (and the `decoration`) that runs the create action. For the lanes of a
  scope, the create sets the scope (for example `project_id`). The new
  lane is at the end.
- **Edit** (`:update`). In the menu of the lane header: the name input
  in place, Enter saves (the update action), Escape cancels.
- **Delete** (`:destroy`). In the menu of the lane header: the
  `destroy_confirm` of the lane (a message: a
  [confirmation](renderer-actions.md#confirmations) with that message;
  `false`: none), then the destroy action. A board that deletes lanes
  does not compile without `destroy_confirm`; the renderer never adds a
  confirmation. What happens to the cards is
  the business of the lane resource (a cascade, a nilify, or a refusal):
  the renderer MUST show the errors of Ash (for example a foreign key
  error) and keep the lane.
- **Move** (`:move`). When `lane_action(resource, :move)` is not `nil`
  (by default, the move action of an ordered lane resource), each lane
  header has a drag handle ("Move lane Review"). It does not depend on
  `:update`. A drop runs that action of the lane resource with the
  arguments `target_id` and `placement`, as [Reorder](renderer-actions.md#reorder). The
  keyboard alternative: Space or Enter picks the lane up, Left and Right
  arrows move it, Space or Enter drops it, Escape cancels; a live region
  announces each step ("Review, lane 2 of 4"). The renderer MAY also offer
  **Move left** and **Move right** in the menu of the lane header.

After a lane control, the renderer MUST reload the lanes (or apply the
notification) and keep the cards of the other lanes.

The lanes of one scope:

```elixir
PyroManiac.KanBan.Info.lanes(Brewery.Task,
  actor: actor,
  query: Ash.Query.filter(Brewery.Stage, project_id == ^project.id)
)
```

## Lists

The UI and the DSL: [Lists](../tutorials/views.md#lists).

The renderer, for a flat list:

- MUST render a list (`<ul>`, or `role="list"`), one item for each record,
  in the order of the sort. The values of a line are on one line when
  there is room, and wrap on a phone. A `decoration` of a value styles it
  ([Decorations](renderer-decorations.md)).
- The whole line opens the record (one link or button), its `link_to`
  values stay links, and its actions are buttons at the end of the line or
  in a menu (⋯).
- Up and Down SHOULD move the focus between the lines.
- The empty state, the loading, and the pages are those of [the
  frame](#the-frame-of-a-list-view).

The renderer, for a tree (`parent_field`):

- **The relationship.** PyroManiac does not check `parent_field` at
  compile time. The renderer MUST check that
  `Ash.Resource.Info.relationship(resource, parent_field)` is a
  `belongs_to` to the resource of the view, and raise a clear error
  otherwise. Its `source_attribute` (`parent_id`) is the key of the tree.
- **The levels.** The roots are the records without a parent
  (`parent_id` is `nil`); the children of a record are the records whose
  `parent_id` is its ID. Each level is the same read action of the view,
  with the filter of the level joined to the filter of the user (and), and
  the sort of the view.
- **Lazy loading.** The renderer reads the roots first, and the children
  of a record when it opens for the first time: the toggle shows a busy
  state (`aria-busy="true"` on the group, "Loading…" in it). A record that
  has no children after the read loses its toggle. A level with more
  records than a page has **Load more** at its end, inside its group.
- **Expand and collapse.** Each record with children (or not read yet) has
  a toggle (▸ closed, ▾ open) with `aria-expanded`. The children are
  indented under their parent, one step for each level. The open records
  SHOULD stay open after a reload of the data (a notification, a page) and
  SHOULD be in the URL (a param of the renderer).
- **Keyboard.** The tree follows the ARIA tree pattern: `role="tree"`
  (or `role="treegrid"` when the line has columns and buttons), items with
  `aria-level`, `aria-setsize`, `aria-posinset`, and `aria-expanded`, and
  the children in a `role="group"`. Up and Down move between the visible
  items; Right opens a closed item, or goes to its first child; Left
  closes an open item, or goes to its parent; Home and End go to the first
  and the last visible item; Enter opens the card; `*` opens the siblings
  of the item. One item is in the tab order (a roving `tabindex`).
- **Filters.** A child can match a filter when its parent does not. With a
  filter of the user, the renderer SHOULD show each match with the path of
  its ancestors (the ancestors dim, or a breadcrumb on each match).
- **Reorder.** With `reorder? true`, the scope of `PyroManiac.Ordering`
  SHOULD be the foreign key of the parent (`scope :parent_id`): the
  children of one parent reorder among themselves. A move does not cross
  scopes, so a drop on another parent is not a move; the drop position
  stays among the siblings.

## The render view

The UI and the DSL: [The render view](../tutorials/views.md#the-render-view).
The implementations and their verifier are in [Custom
renders](renderer-custom-renders.md).

`PyroManiac.Render.implementation/2` gives the implementation for a
renderer, or `nil`. A `:render` view is not a primary view.

The renderer:

- MUST call the implementation with the records of the read action (with
  `loads`), the state of the list ([Filters and
  sorts](renderer-filters-and-sorts.md)) and a way to change it, the
  actor, and the page.
- SHOULD show the same filter bar above the component ([Filters and
  sorts](renderer-filters-and-sorts.md)), and the toolbar actions of the
  view, so a filter changes the component as it changes a table.
- The empty state and the loading of [the frame](#the-frame-of-a-list-view)
  are the renderer's; the inside of the component (its keyboard, its
  accessible names, a text alternative of a chart) is the component's.
