# Views

A view shows the records of a read action of the page. Its `type` gives
the layout: a table, a grid of cards, a calendar, a board, ... This guide
shows each view type and the actions of the views: what the user sees, and
the DSL that declares it. For the contract of a renderer, refer to
[Views](../renderers/renderer-views.md) and
[Actions](../renderers/renderer-actions.md).

Each example has two tabs: the **UI** that the renderer produces and the
**DSL** that declares it. A yellow tag in a figure names the DSL of the
part. Click a figure (or focus it and press Enter) to see it large.

The examples use the Brewery domain of the tests: the resources
`Brewery.Recipe`, `Brewery.RecipeIngredient`, `Brewery.Ingredient`,
`Brewery.Supplier`, `Brewery.Batch`, `Brewery.QualityTest`,
`Brewery.Staff`, and `Brewery.Shipment`, and the pages
`BreweryWeb.RecipeLive`, `BreweryWeb.BatchLive`, and the others.

<svg width="0" height="0" style="position:absolute" aria-hidden="true">
<style>
.dg-svg{width:100%;height:auto}
.dg-p{fill:none;stroke:currentColor;stroke-opacity:.5}
.dg-s{fill:currentColor;fill-opacity:.03;stroke:currentColor;stroke-opacity:.35}
.dg-c{fill:none;stroke:currentColor;stroke-opacity:.35;stroke-dasharray:4 3}
.dg-i{fill:currentColor;fill-opacity:.05;stroke:currentColor;stroke-opacity:.5}
.dg-h{font:600 15px system-ui,sans-serif;fill:currentColor}
.dg-st{font:600 13px system-ui,sans-serif;fill:currentColor}
.dg-l{font:11px system-ui,sans-serif;fill:currentColor;fill-opacity:.65}
.dg-v{font:13px system-ui,sans-serif;fill:currentColor}
.dg-a{font:13px system-ui,sans-serif;fill:#2563eb;text-decoration:underline}
.dg-tb{fill:#fef3c7;stroke:#d97706}
.dg-t{font:11px ui-monospace,monospace;fill:#92400e}
.dg-b{fill:currentColor;fill-opacity:.08;stroke:currentColor;stroke-opacity:.5}
.dg-pri{fill:#1e3a5f}
.dg-bt{font:12px system-ui,sans-serif;fill:currentColor}
.dg-bw{font:12px system-ui,sans-serif;fill:#fff}
.dg-ok{fill:#dcfce7;stroke:#16a34a}
.dg-okt{font:11px system-ui,sans-serif;fill:#166534}
.dg-info{fill:#dbeafe;stroke:#2563eb}
.dg-infot{font:11px system-ui,sans-serif;fill:#1e40af}
.dg-warn{fill:#ffedd5;stroke:#ea580c}
.dg-warnt{font:11px system-ui,sans-serif;fill:#9a3412}
.dg-bad{fill:#fee2e2;stroke:#dc2626}
.dg-badt{font:11px system-ui,sans-serif;fill:#991b1b}
.dg-err{fill:#dc2626}
.dg-errt{font:11px system-ui,sans-serif;fill:#dc2626}
.dg-tab{font:13px system-ui,sans-serif;fill:currentColor;fill-opacity:.7}
.dg-on{stroke:#2563eb;stroke-width:2}
.dg-foc{fill:none;stroke:#2563eb;stroke-width:2}
.dg-f{font:13px system-ui,sans-serif;fill:currentColor;fill-opacity:.5}
.dg-u{font:12px ui-monospace,monospace;fill:currentColor}
.dg-m{fill:Canvas;stroke:currentColor;stroke-opacity:.5}
.dg-g{stroke:currentColor;stroke-opacity:.25}
.dg-hl{fill:#2563eb;fill-opacity:.1}
.dg-bar{fill:#2563eb;fill-opacity:.25;stroke:#2563eb}
</style>
</svg>

`view` is a top-level entity of the page (no `views do` block). A view
shows the records of its read action (its name, or `read_action`) and runs
the actions that it names ([Actions](#actions)). A page has one primary
card and at most one primary list view ([Pages](pages.md)); the other list
views are tabs of the page.

## View types

| Type | Section | For | Key options |
|---|---|---|---|
| `:data_table` | [Data tables](#data-tables) | Rows and columns: sort, filter, hide, and edit the cells; select rows for the bulk actions. | `column`, `default_display`, `selectable?`, `new_row?`, `reorder?` |
| `:grid` | [Grids](#grids) | A card for each record, in a responsive grid. | its own record tree, or `card? true`; `reorder?` |
| `:card` | [Cards](#cards) | One record: the single view. One card for each record when it is the list view. | the record tree, `action`, `presentation` |
| `:calendar` | [Calendars](#calendars) | The records on a day, a week, or a month. | `date_field` (required), `end_date_field`, `granularity` |
| `:gantt` | [Gantt charts](#gantt-charts) | A bar for each record on a time scale, in lanes. | `start_field`, `end_field` (required), `progress_field`, `group_by` |
| `:timeline` | [Timelines](#timelines) | The records as events in time order, on a vertical or a horizontal axis. | `date_field` (required), `end_date_field`, `orientation` |
| `:kanban` | [Kanban boards](#kanban-boards) | Lanes of cards; a card moves between lanes. | the `kan_ban` section of the resource |
| `:list` | [Lists](#lists) | One line for each record; a tree with `parent_field`. | the `field` entities, `parent_field`, `reorder?` |
| `:render` | [The render view](#the-render-view) | The component of the renderer: the escape hatch. | `render` (required), `loads` |

An option of one type on another type is a compile error:
`granularity` is for a `:calendar` only, `orientation` for a `:timeline`
or a `:kanban` only. `date_field` is required on a `:calendar` and a `:timeline`;
`start_field` and `end_field` on a `:gantt`; `render` on a `:render`. A
`:kanban` takes `group_by`, `priority`, `kanban_action`, and
`default_sort` from the resource (a compile error on the view).

### The options of every list view

| Option | The UI |
|---|---|
| `label`, `description` | The tab of the view, and text below it. `description` is an entity: a text, or an implementation for one renderer (a view has no record, so no expression). |
| `width` | The width of the view: `:full` (the whole content area), `:record`, `:form`, or `:prose`. Default: the `width` of the page, `:full` by default ([Pages](pages.md#the-page)). |
| `read_action` | The read action, when it is not the name of the view. |
| `resource` | Another resource than the resource of the page. |
| `exclude` | The exposed fields of the read action that the view does not show. (The actions that the page does not use are in `page exclude`.) |
| `default_sort` | The first sort: a sort input string (`"-batch_number"`) or a sort list ([Filters and sorts](pages.md)). |
| `pagination` | `:offset` (numbered pages), `:keyset` (next and previous), or `:none`. Without it, the action decides (`PyroManiac.DataLoader.pagination_type/3`). |
| `default_page_size`, `page_sizes` | The first page size, and the sizes that the user can select. |
| `count?` | The total count ("1–25 of 112"). Default: `true` for offset pages. |
| `ensure_loaded` | Loads that the view always adds (for a `render`, or an extra action). |
| `field` | The values of each item of a calendar, a gantt, a timeline, a kanban, or a list. `path` reads a related record: `field :name, path: [:recipe]`. |
| `action` | A toolbar button (create) or a row button (the others), with its form, or without inputs with its `confirm` ([Actions of a list view](#actions-of-a-list-view)). |
| `bulk_action` | A button for the selected records ([Bulk actions](#bulk-actions)). |
| `edit_columns` | Some cells of a row, edited together ([Inline edits](#inline-edits)). |
| `extra_action` | A button on each record ([Extra actions](#extra-actions)). |
| `clone?` | A **Clone** button on each record: the create form, filled from the record ([Clone](#clone)). |
| `new_row?` | An inline new row at the top of a `:data_table` ([New rows](#new-rows)). |
| `reorder?` | Drag handles on the records of a `:data_table`, `:grid`, or `:list`, when the list is sorted by the rank ([Reorder](#reorder)). |
| `selectable?` | A checkbox on each record for the bulk actions (default `true`). |
| `on_create`, `on_update`, `on_destroy`, `on_bulk` | The notifications ([Pages](pages.md)). |

Every list view has the same frame around its records:

- the list views of a page are tabs (`label`), with the `description`
  below the tab;
- the filter bar, the chips, the presets, and the sort, all in the URL
  ([Pages](pages.md));
- a create action is a toolbar button; the other actions, the extra
  actions, and **Clone** are on each record (buttons on a row, or a menu
  on a card, an event, a bar, or a line); with bulk actions, a checkbox on
  each record;
- a click on a record (or Enter on the focused record) opens the primary
  card; the links of its values stay links;
- a message when there are no records ("No batches yet", or "No batches
  match the filter" with **Clear the filter**), and the page controls.

A view that names no write action shows values only: each `field` is
read-only, and a `select`, `combobox`, or `input` is a compile error.

## Data tables

A `:data_table` shows each exposed field of its read action as a column, or
excludes it (a compile error otherwise). The columns of `default_display`
show at first; the user shows the others. `selectable?` (default `true`)
adds the row checkboxes for the bulk actions.

| Column option | The UI |
|---|---|
| `label`, `description` | Entities: the header (default: the capitalized name), and its help text. Each is a text, an Ash expression (its refs load with the rows), or an implementation for one renderer ([Custom renders](custom-renders.md)). |
| `source` | The path of the value, for a value of a related record (`[:recipe, :style]`). |
| `sortable?`, `keyset_sortable?` | The header sorts (offset and no pages; keyset pages). Off when the field cannot sort. |
| `filterable?` | The column is a field of the filter UI. Off when the field cannot filter. |
| `decoration` | The meaning of each cell: a decoration, or an expression that gives one or `nil` (its refs load with the row). [Decorations](decorations.md). |
| `type` | `:default`, `:textarea` (long text, clipped), or `:attachment` (the files). |
| `action` (in `column`) | An inline edit of the cell: an action and its inputs ([Inline edits](#inline-edits)). |
| `link_to` | The cell links to another page ([Pages](pages.md)). |
| `render` | A custom cell ([Custom renders](custom-renders.md)). |

| View option | The UI |
|---|---|
| `column` | A column. Each exposed field of the read action is a column or is in `exclude` (a compile error otherwise). |
| `default_display` | The columns that show at first (`:data_table` only). Each is a column of the view; `[]` is a compile error. |
| `selectable?` | The row checkboxes (default `true`). |
| `new_row?` | An inline new row at the top ([New rows](#new-rows)). |
| `edit_columns`, the `action` of a column | Inline edits of the cells ([Inline edits](#inline-edits)). |
| `reorder?`, `clone?` | Drag handles on the rows ([Reorder](#reorder)), and **Clone** on each row ([Clone](#clone)). |
| `default_sort` | The first sort: each key is a column of the view (a compile error otherwise). |

The user sorts with the headers, shows and hides the columns with a column
menu, and selects rows for the bulk actions (the selection stays across
the pages). A long text is clipped to one line. On a phone, the table
scrolls on its own, or shows one card for each row.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 360" role="img" aria-labelledby="dg-dt-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-dt-t">The batches table: two selected rows with the bulk actions, sorted and decorated columns, an inline edit, a row action, and the pages</title>
<rect class="dg-p" x="10" y="10" width="980" height="340" rx="8"/>
<text class="dg-h" x="26" y="42">Batches</text>
<rect class="dg-b" x="742" y="24" width="108" height="26" rx="4"/><text class="dg-bt" x="756" y="41">Columns (8/14) ▾</text>
<rect class="dg-tb" x="600" y="28" width="134" height="16" rx="3"/><text class="dg-t" x="605" y="40">default_display [...]</text>
<rect class="dg-pri" x="862" y="24" width="112" height="26" rx="4"/><text class="dg-bw" x="882" y="41">+ New batch</text>
<rect class="dg-hl" x="22" y="58" width="956" height="28" rx="4"/>
<text class="dg-st" x="34" y="77">2 selected</text>
<rect class="dg-b" x="120" y="62" width="108" height="20" rx="4"/><text class="dg-bt" x="130" y="76">Advance status</text>
<rect class="dg-b" x="236" y="62" width="100" height="20" rx="4"/><text class="dg-bt" x="246" y="76">Start brewing</text>
<rect class="dg-tb" x="346" y="64" width="196" height="16" rx="3"/><text class="dg-t" x="351" y="76">bulk_action · selectable? true</text>
<rect class="dg-tb" x="742" y="4" width="232" height="16" rx="3"/><text class="dg-t" x="747" y="16">action :create · delegate_to</text>
<rect class="dg-tb" x="48" y="94" width="200" height="16" rx="3"/><text class="dg-t" x="53" y="106">default_sort "-batch_number"</text>
<rect class="dg-tb" x="300" y="94" width="234" height="16" rx="3"/><text class="dg-t" x="305" y="106">column :status · action :advance_status</text>
<rect class="dg-tb" x="800" y="94" width="104" height="16" rx="3"/><text class="dg-t" x="805" y="106">type :textarea</text>
<rect class="dg-tb" x="160" y="114" width="60" height="16" rx="3"/><text class="dg-t" x="165" y="126">link_to</text>
<rect class="dg-tb" x="610" y="114" width="72" height="16" rx="3"/><text class="dg-t" x="615" y="126">decoration</text>
<rect class="dg-tb" x="700" y="114" width="80" height="16" rx="3"/><text class="dg-t" x="705" y="126">no link_to</text>
<rect class="dg-tb" x="806" y="114" width="172" height="16" rx="3"/><text class="dg-t" x="811" y="126">extra_action :print_label</text>
<rect class="dg-i" x="30" y="134" width="12" height="12" rx="2"/>
<text class="dg-l" x="52" y="144">Batch ↓</text><text class="dg-l" x="160" y="144">Recipe ▾</text><text class="dg-l" x="320" y="144">Status ▾</text><text class="dg-l" x="440" y="144">Brew date ▾</text><text class="dg-l" x="540" y="144">ABV</text><text class="dg-l" x="610" y="144">Pass rate</text><text class="dg-l" x="700" y="144">Brewer ▾</text><text class="dg-l" x="800" y="144">Notes</text>
<line class="dg-g" x1="22" y1="152" x2="978" y2="152"/>
<rect class="dg-pri" x="30" y="160" width="12" height="12" rx="2"/><polyline points="32,166 35,169 40,162" fill="none" stroke="#fff" stroke-width="1.6"/>
<text class="dg-v" x="52" y="171">B-2026-044</text><text class="dg-a" x="160" y="171">Hazy Daze IPA</text><rect class="dg-info" x="320" y="159" width="76" height="18" rx="9"/><text class="dg-infot" x="331" y="172">Fermenting</text><text class="dg-v" x="440" y="171">2026-11-12</text><text class="dg-v" x="540" y="171">—</text><text class="dg-v" x="610" y="171">—</text><text class="dg-v" x="700" y="171">Ana Ruiz</text><text class="dg-v" x="800" y="171">Dry hop day 3…</text>
<rect class="dg-b" x="904" y="159" width="70" height="20" rx="4"/><text class="dg-bt" x="912" y="173">Print label</text>
<rect class="dg-pri" x="30" y="184" width="12" height="12" rx="2"/><polyline points="32,190 35,193 40,186" fill="none" stroke="#fff" stroke-width="1.6"/>
<text class="dg-v" x="52" y="195">B-2026-043</text><text class="dg-a" x="160" y="195">Midnight Stout</text>
<rect class="dg-i" x="316" y="181" width="112" height="22" rx="3"/><text class="dg-v" x="322" y="196">Conditioning</text><text class="dg-v" x="414" y="196">▾</text><rect class="dg-foc" x="315" y="180" width="114" height="24" rx="4"/>
<text class="dg-v" x="440" y="195">2026-11-05</text><text class="dg-v" x="540" y="195">7.1 %</text><text class="dg-v" x="610" y="195">100 %</text><text class="dg-v" x="700" y="195">Ben Okafor</text><text class="dg-v" x="800" y="195">—</text>
<rect class="dg-i" x="30" y="208" width="12" height="12" rx="2"/>
<text class="dg-v" x="52" y="219">B-2026-042</text><text class="dg-a" x="160" y="219">Harbor Lager</text><rect class="dg-info" x="320" y="207" width="74" height="18" rx="9"/><text class="dg-infot" x="331" y="220">Packaging</text><text class="dg-v" x="440" y="219">2026-10-28</text><text class="dg-v" x="540" y="219">4.9 %</text><rect class="dg-warn" x="606" y="207" width="44" height="18" rx="9"/><text class="dg-warnt" x="614" y="220">75 %</text><text class="dg-v" x="700" y="219">Dev Patel</text><text class="dg-v" x="800" y="219">Lagered 4 weeks.</text>
<rect class="dg-i" x="30" y="232" width="12" height="12" rx="2"/>
<text class="dg-v" x="52" y="243">B-2026-041</text><text class="dg-a" x="160" y="243">Cherry Sour</text><rect class="dg-bad" x="320" y="231" width="72" height="18" rx="9"/><text class="dg-badt" x="331" y="244">Cancelled</text><text class="dg-v" x="440" y="243">2026-10-20</text><text class="dg-v" x="540" y="243">—</text><rect class="dg-warn" x="606" y="231" width="44" height="18" rx="9"/><text class="dg-warnt" x="614" y="244">40 %</text><text class="dg-v" x="700" y="243">Chloe Park</text><text class="dg-v" x="800" y="243">Infected: see th…</text>
<rect class="dg-i" x="30" y="256" width="12" height="12" rx="2"/>
<text class="dg-v" x="52" y="267">B-2026-040</text><text class="dg-a" x="160" y="267">Old Mill Porter</text><rect class="dg-ok" x="320" y="255" width="70" height="18" rx="9"/><text class="dg-okt" x="331" y="268">Complete</text><text class="dg-v" x="440" y="267">2026-10-14</text><text class="dg-v" x="540" y="267">6.1 %</text><text class="dg-v" x="610" y="267">100 %</text><text class="dg-v" x="700" y="267">Ana Ruiz</text><text class="dg-v" x="800" y="267">—</text>
<line class="dg-g" x1="22" y1="280" x2="978" y2="280"/>
<text class="dg-v" x="26" y="302">1–25 of 112</text>
<text class="dg-l" x="400" y="302">Rows</text><rect class="dg-i" x="430" y="288" width="52" height="22" rx="3"/><text class="dg-v" x="438" y="304">25 ▾</text>
<text class="dg-v" x="800" y="302">‹</text><rect class="dg-pri" x="816" y="288" width="22" height="22" rx="3"/><text class="dg-bw" x="823" y="303">1</text><text class="dg-v" x="848" y="302">2</text><text class="dg-v" x="866" y="302">3</text><text class="dg-v" x="884" y="302">4</text><text class="dg-v" x="902" y="302">5</text><text class="dg-v" x="920" y="302">›</text>
<rect class="dg-tb" x="26" y="316" width="82" height="16" rx="3"/><text class="dg-t" x="31" y="328">count? true</text>
<rect class="dg-tb" x="400" y="316" width="246" height="16" rx="3"/><text class="dg-t" x="405" y="328">default_page_size 25 · page_sizes [...]</text>
<rect class="dg-tb" x="800" y="316" width="128" height="16" rx="3"/><text class="dg-t" x="805" y="328">pagination :offset</text>
</svg>
<figcaption>The batches table. Two rows are selected for a bulk action. The status of the second row is in an inline edit. The decoration of a cell comes from an expression of its record. The brewer has no <code>link_to</code>: it is text.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive
view :read do
  type :data_table
  primary? true
  label "All batches"
  description "Every batch, the newest first."
  read_action :list
  default_sort "-batch_number"
  pagination :offset
  count? true
  default_page_size 25
  page_sizes [10, 25, 50]
  selectable? true
  ensure_loaded [recipe: [:style]]
  exclude [:id, :recipe_id, :brewer_id, :kanban_priority]

  default_display [
    :batch_number,
    :recipe,
    :status,
    :brew_date,
    :actual_abv,
    :pass_rate,
    :brewer,
    :notes
  ]

  column :batch_number

  column :recipe do
    link_to BreweryWeb.RecipeLive
  end

  column :status do
    decoration expr(if status == :cancelled, do: :danger, else: :info)

    action :advance_status, :discard do
      select :status, autofocus: true
    end
  end

  column :brew_date
  column :package_date

  column :actual_abv do
    label "ABV"
    description "Measured alcohol by volume."
  end

  column :pass_rate do
    decoration expr(if pass_rate < 80, do: :warning)
    filterable? false
    keyset_sortable? false
  end

  column :brewer

  column :notes do
    type :textarea
    sortable? false
  end

  column :actual_og
  column :actual_fg
  column :volume_liters
  column :test_count
  column :passed_test_count

  action :create, :guard do
    delegate_to BreweryWeb.BatchLive
  end

  bulk_action :advance_status, :guard do
    select :status
  end

  bulk_action :start_brewing, :discard do
    confirm "Start brewing the selected batches?"
  end

  extra_action :print_label do
    label "Print label"
  end
end
```

<!-- tabs-close -->

The sort, the filter, and the page are in the URL ([Pages](pages.md)). The
inline edit of the status is in [Inline edits](#inline-edits); **+ New
batch** is in [Actions of a list view](#actions-of-a-list-view), and the
bulk actions in [Bulk actions](#bulk-actions).

[↑ View types](#view-types)

## Grids

A `:grid` shows a card for each record, in a responsive grid. Its cards
have their own record tree (the same nodes as a card, in view mode), or
`card? true`: the nodes of the primary card before `tabs`, without
`related` and `attachments`.

| Option | Required | The UI |
|---|---|---|
| the record tree | one of the two | The content of each card: `section`, `row`, `compound`, `field`, `related`, ... in view mode. |
| `card?` | one of the two | Each card shows the tree of the primary card ([Cards](#cards)), pruned for a grid. |
| `reorder?` | no | A drag handle on each card ([Reorder](#reorder)). |
| `selectable?` | no (`true`) | A checkbox on each card for the bulk actions. |

A grid with neither a tree nor `card? true`, or with both, is a compile
error.

The cards fit the width (one column on a phone), in the order of the sort.
The whole card opens the record; the links of its values stay links; the
actions of the record are in a menu (⋯) of the card. The arrow keys move
between the cards.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 262" role="img" aria-labelledby="dg-grid-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-grid-t">Three recipe cards of a grid: a dense section with a compound and a row, and a section for each ingredient of the recipe</title>
<rect class="dg-tb" x="10" y="2" width="330" height="16" rx="3"/><text class="dg-t" x="15" y="14">section :recipe · density :dense · max_columns 2</text>
<rect class="dg-s" x="10" y="22" width="316" height="232" rx="6"/>
<text class="dg-st" x="24" y="44">Recipe</text>
<text class="dg-l" x="24" y="64">Name</text><text class="dg-v" x="24" y="80">Hazy Daze IPA</text>
<text class="dg-l" x="170" y="64">Gravity</text><text class="dg-v" x="170" y="80">1.064 → 1.012</text>
<rect class="dg-tb" x="170" y="86" width="150" height="16" rx="3"/><text class="dg-t" x="175" y="98">compound · separator</text>
<text class="dg-l" x="24" y="116">Style</text><text class="dg-v" x="24" y="132">IPA</text>
<text class="dg-l" x="170" y="116">Status</text><text class="dg-v" x="170" y="132">Active</text>
<rect class="dg-tb" x="88" y="104" width="32" height="16" rx="3"/><text class="dg-t" x="93" y="116">row</text>
<line class="dg-g" x1="18" y1="144" x2="318" y2="144"/>
<text class="dg-st" x="24" y="164">Ingredients</text>
<rect class="dg-tb" x="110" y="152" width="208" height="16" rx="3"/><text class="dg-t" x="115" y="164">path [:recipe_ingredients]</text>
<text class="dg-v" x="24" y="186">5.5</text><text class="dg-a" x="80" y="186">Maris Otter</text>
<text class="dg-v" x="24" y="208">0.2</text><text class="dg-a" x="80" y="208">Citra</text>
<text class="dg-v" x="24" y="230">2</text><text class="dg-a" x="80" y="230">US-05</text>
<rect class="dg-s" x="342" y="22" width="316" height="232" rx="6"/>
<text class="dg-st" x="356" y="44">Recipe</text>
<text class="dg-l" x="356" y="64">Name</text><text class="dg-v" x="356" y="80">Midnight Stout</text>
<text class="dg-l" x="502" y="64">Gravity</text><text class="dg-v" x="502" y="80">1.072 → 1.018</text>
<text class="dg-l" x="356" y="116">Style</text><text class="dg-v" x="356" y="132">Stout</text>
<text class="dg-l" x="502" y="116">Status</text><text class="dg-v" x="502" y="132">Active</text>
<line class="dg-g" x1="350" y1="144" x2="650" y2="144"/>
<text class="dg-st" x="356" y="164">Ingredients</text>
<text class="dg-v" x="356" y="186">6.0</text><text class="dg-a" x="412" y="186">Maris Otter</text>
<text class="dg-v" x="356" y="208">0.5</text><text class="dg-a" x="412" y="208">Roasted Barley</text>
<rect class="dg-s" x="674" y="22" width="316" height="232" rx="6"/>
<text class="dg-st" x="688" y="44">Recipe</text>
<text class="dg-l" x="688" y="64">Name</text><text class="dg-v" x="688" y="80">Sunday Wheat</text>
<text class="dg-l" x="834" y="64">Gravity</text><text class="dg-v" x="834" y="80">—</text>
<text class="dg-l" x="688" y="116">Style</text><text class="dg-v" x="688" y="132">Wheat</text>
<text class="dg-l" x="834" y="116">Status</text><text class="dg-v" x="834" y="132">Draft</text>
<line class="dg-g" x1="682" y1="144" x2="982" y2="144"/>
<text class="dg-st" x="688" y="164">Ingredients</text>
<text class="dg-l" x="688" y="186">None</text>
</svg>
<figcaption>A grid of recipes. Each card has a dense section with at most two columns, and a section that repeats for each ingredient of the recipe. The ingredient links to its page.</figcaption>
</figure>

### DSL

```elixir
view :read do
  type :grid
  label "Grid"

  section :recipe do
    density :dense
    max_columns 2
    field :name

    compound :gravity do
      separator " → "
      field :target_og
      field :target_fg
    end

    row do
      field :style
      field :status
    end
  end

  section :ingredients do
    path [:recipe_ingredients]
    field :quantity

    field :ingredient do
      link_to BreweryWeb.IngredientLive
    end
  end
end

# or: the primary card of the page on each card of the grid
view :read do
  type :grid
  card? true
end
```

<!-- tabs-close -->

[↑ View types](#view-types)

## Cards

A `:card` is the single view: one record, with its record tree in view
mode, and the form of each write action that it names. Each page has one
primary card ([Pages](pages.md)). When the page has no primary list view,
the primary card is also the list view: one card for each record.

| Option | Required | The UI |
|---|---|---|
| the record tree | yes | The content of the card: `field`, `select`, `combobox`, `input`, `section`, `row`, `compound`, `related`, `attachments`, `workflow`, `tabs`, `step` ([The record layout](record-layout.md)). A card without nodes, or with a `column`, is a compile error. |
| `primary?` | one card of the page | The card that a link to the page and `card=<id>` open. |
| `action` | no | Without nodes: the tree of the card is the form (**Edit**, and **New** in the list). With nodes or `delegate_to`: a button of the card that opens its own tree ([The tree of a card](#the-tree-of-a-card)). |
| `presentation` | no (`:modal`) | Where the card opens: `:modal`, `:drawer`, or `:page` ([Pages](pages.md)). |
| `width` | no (`:record` in a modal or a drawer) | The width of the modal or the drawer: `:record`, `:form`, `:prose`, or `:full`. With `:page`, the width of the page, as for any view. |
| `read_action`, `resource`, `ensure_loaded` | no | The read of the record. |
| `clone?` | no | **Clone** in the card: the create form with the values of the record ([Clone](#clone)). |
| `extra_action` | no | Buttons in the header of the card ([Extra actions](#extra-actions)). |
| `label`, `description` | no | The name of the view (for example on a button that opens a second card), and the text below its header. The heading of the card is the label of the record. |

The heading of the card is the label of the record. The header has
**Edit** (when the card names an update action), the action buttons, the
extra actions, and **Close**. **Edit** puts the same tree in the update
form, in the same place; **Save** runs the action, **Cancel** and Escape
return to view mode. **Show all fields** shows the exposed fields that the
tree does not show. A record that does not exist and a record that the
user cannot read give the same "Not found".

When the primary card is the list view, each record is a card in view
mode, with the frame of a list view: a card opens with a click or Enter,
**Edit** opens it in its update form, and **New** is a toolbar button.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 270" role="img" aria-labelledby="dg-cardl-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-cardl-t">The suppliers page without a primary list view: one card for each supplier, with the fields of the card, an Edit button on each card, and a New supplier button</title>
<rect class="dg-p" x="10" y="10" width="980" height="250" rx="8"/>
<text class="dg-h" x="26" y="40">Suppliers</text>
<rect class="dg-tb" x="120" y="28" width="300" height="16" rx="3"/><text class="dg-t" x="125" y="40">type :card · primary? true (no primary list view)</text>
<rect class="dg-pri" x="846" y="24" width="128" height="26" rx="4"/><text class="dg-bw" x="864" y="41">+ New supplier</text>
<rect class="dg-tb" x="650" y="28" width="186" height="16" rx="3"/><text class="dg-t" x="655" y="40">action [:create, :update]</text>
<rect class="dg-s" x="22" y="64" width="956" height="58" rx="6"/>
<text class="dg-st" x="36" y="90">Cascade Hop Farm</text><rect class="dg-ok" x="36" y="98" width="50" height="16" rx="8"/><text class="dg-okt" x="45" y="110">Active</text>
<text class="dg-l" x="300" y="84">Code</text><text class="dg-v" x="300" y="102">CHF</text>
<text class="dg-l" x="400" y="84">Contact email</text><text class="dg-v" x="400" y="102">orders@cascadehops.example</text>
<text class="dg-l" x="640" y="84">Phone</text><text class="dg-v" x="640" y="102">555-0142</text>
<text class="dg-l" x="760" y="84">Ingredients</text><text class="dg-v" x="760" y="102">4</text>
<rect class="dg-b" x="910" y="80" width="54" height="24" rx="4"/><text class="dg-bt" x="925" y="96">Edit</text>
<rect class="dg-s" x="22" y="130" width="956" height="58" rx="6"/>
<rect class="dg-foc" x="20" y="128" width="960" height="62" rx="7"/>
<text class="dg-st" x="36" y="156">Valley Maltings</text><rect class="dg-ok" x="36" y="164" width="50" height="16" rx="8"/><text class="dg-okt" x="45" y="176">Active</text>
<text class="dg-l" x="300" y="150">Code</text><text class="dg-v" x="300" y="168">VMS</text>
<text class="dg-l" x="400" y="150">Contact email</text><text class="dg-v" x="400" y="168">sales@valleymaltings.example</text>
<text class="dg-l" x="640" y="150">Phone</text><text class="dg-v" x="640" y="168">555-0187</text>
<text class="dg-l" x="760" y="150">Ingredients</text><text class="dg-v" x="760" y="168">7</text>
<rect class="dg-b" x="910" y="146" width="54" height="24" rx="4"/><text class="dg-bt" x="925" y="162">Edit</text>
<g opacity=".5">
<rect class="dg-s" x="22" y="196" width="956" height="58" rx="6"/>
<text class="dg-st" x="36" y="222">Yeast Lab West</text><rect class="dg-b" x="36" y="230" width="58" height="16" rx="8"/><text class="dg-bt" x="44" y="242">Inactive</text>
<text class="dg-l" x="300" y="216">Code</text><text class="dg-v" x="300" y="234">YLW</text>
<text class="dg-l" x="400" y="216">Contact email</text><text class="dg-v" x="400" y="234">—</text>
<text class="dg-l" x="640" y="216">Phone</text><text class="dg-v" x="640" y="234">—</text>
<text class="dg-l" x="760" y="216">Ingredients</text><text class="dg-v" x="760" y="234">0</text>
<rect class="dg-b" x="910" y="212" width="54" height="24" rx="4"/><text class="dg-bt" x="925" y="228">Edit</text>
</g>
</svg>
<figcaption>The suppliers page has no primary list view, so its primary card is the list: one card for each supplier, in view mode. The focused card opens with Enter (<code>card=&lt;id&gt;</code>); <b>Edit</b> opens it in its update form (<code>&amp;edit</code>), in a drawer.</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.SupplierLive do
  use PyroManiac, resource: Brewery.Supplier

  page do
    route "/suppliers"
    exclude [:suggest_codes, :by_prefix, :rename, :destroy]
  end

  view :read do
    type :card
    primary? true
    presentation :drawer
    action [:create, :update], :guard

    section :supplier do
      field :name, autofocus: true
      field :code
      field :contact_email
      field :phone
      field :active
      field :notes, type: :textarea
      field :ingredient_count, only: [:read]
    end
  end
end
```

<!-- tabs-close -->

The create and the update action accept each attribute of
`Brewery.Supplier`, so the tree has each one (the completeness check of a
form). `:ingredient_count` is an aggregate: view mode only.

[↑ View types](#view-types)

## Calendars

A `:calendar` puts the records on a calendar: each record is an event on
its `date_field`, or a span from `date_field` to `end_date_field`. It is
for the records that happen on dates: the brew days and the batches in the
tanks, the deliveries, the shifts. The `field` entities are the text of
each event (`path` reads a related record).

| Option | Required | The UI |
|---|---|---|
| `date_field` | yes | The date or the start of the event: a `:date` or a datetime attribute. Without it, a compile error (with the date attributes of the resource as suggestions). |
| `end_date_field` | no | The end of the event: the event is a span over each day to the end (inclusive). A record without an end is an event of one day (one time with a datetime). |
| `granularity` | no | The period that the calendar opens with: `:day`, `:week`, or `:month`. The user switches between the three. Without it, the renderer SHOULD open on `:month`. On another view type, a compile error. |
| `field` | no | The text of each event, in order. Without fields, the event shows the label of the record. |

The user switches between the three periods (Day, Week, Month), moves by
one period with **Previous** and **Next**, and goes back with **Today**.
Today is marked. A span covers each day from its start to its end; a day
of the month with more events than room has "+2 more". The calendar reads
only the records of the visible range, with the filter of the user; it has
no page controls. Put `date_field` and `end_date_field` in the exposed
`filter` of the read action, so the read of the range is a filter.

<!-- tabs-open -->

### Day

<figure>
<svg class="dg-svg" viewBox="0 0 1000 330" role="img" aria-labelledby="dg-cald-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-cald-t">The day view of the batches calendar on Thursday, November 19, 2026: five batches that take the day, with their dates, and a small month to go to another day</title>
<rect class="dg-p" x="10" y="10" width="980" height="310" rx="8"/>
<text class="dg-h" x="26" y="40">Thursday, November 19, 2026</text>
<rect class="dg-b" x="280" y="24" width="54" height="22" rx="4"/><text class="dg-bt" x="290" y="39">Today</text>
<rect class="dg-b" x="340" y="24" width="24" height="22" rx="4"/><text class="dg-bt" x="348" y="39">‹</text>
<rect class="dg-b" x="368" y="24" width="24" height="22" rx="4"/><text class="dg-bt" x="376" y="39">›</text>
<rect class="dg-pri" x="800" y="24" width="40" height="22" rx="4"/><text class="dg-bw" x="808" y="39">Day</text>
<rect class="dg-b" x="844" y="24" width="48" height="22" rx="4"/><text class="dg-bt" x="852" y="39">Week</text>
<rect class="dg-b" x="896" y="24" width="56" height="22" rx="4"/><text class="dg-bt" x="904" y="39">Month</text>
<rect class="dg-bar" x="22" y="64" width="718" height="40" rx="4"/><text class="dg-st" x="34" y="81">B-2026-043</text><text class="dg-v" x="130" y="81">Midnight Stout</text><text class="dg-l" x="34" y="97">Nov 5 → Nov 20</text>
<rect class="dg-bar" x="22" y="110" width="718" height="40" rx="4"/><text class="dg-st" x="34" y="127">B-2026-044</text><text class="dg-v" x="130" y="127">Hazy Daze IPA</text><text class="dg-l" x="34" y="143">Nov 12 → Nov 25</text>
<rect class="dg-bar" x="22" y="156" width="718" height="40" rx="4"/><text class="dg-st" x="34" y="173">B-2026-045</text><text class="dg-v" x="130" y="173">Copper Pale Ale</text><text class="dg-l" x="34" y="189">Nov 17 → Nov 27</text>
<rect class="dg-bar" x="22" y="202" width="718" height="40" rx="4"/><text class="dg-st" x="34" y="219">B-2026-047</text><text class="dg-v" x="130" y="219">Old Mill Porter</text><text class="dg-l" x="34" y="235">Nov 19 → Nov 24</text>
<rect class="dg-bar" x="22" y="248" width="718" height="40" rx="4"/><text class="dg-st" x="34" y="265">B-2026-046</text><text class="dg-v" x="130" y="265">Sunday Wheat</text><text class="dg-l" x="34" y="281">Nov 19 (no package date: one day)</text>
<rect class="dg-tb" x="506" y="74" width="228" height="16" rx="3"/><text class="dg-t" x="511" y="86">field :batch_number · field :name</text>
<rect class="dg-s" x="764" y="56" width="210" height="164" rx="6"/>
<text class="dg-st" x="776" y="78">November 2026</text>
<text class="dg-l" x="780" y="98">M</text><text class="dg-l" x="808" y="98">T</text><text class="dg-l" x="836" y="98">W</text><text class="dg-l" x="864" y="98">T</text><text class="dg-l" x="892" y="98">F</text><text class="dg-l" x="920" y="98">S</text><text class="dg-l" x="948" y="98">S</text>
<text class="dg-l" x="948" y="118">1</text>
<text class="dg-l" x="780" y="136">2</text><text class="dg-l" x="808" y="136">3</text><text class="dg-l" x="836" y="136">4</text><text class="dg-l" x="864" y="136">5</text><text class="dg-l" x="892" y="136">6</text><text class="dg-l" x="920" y="136">7</text><text class="dg-l" x="948" y="136">8</text>
<text class="dg-l" x="780" y="154">9</text><text class="dg-l" x="808" y="154">10</text><text class="dg-l" x="836" y="154">11</text><text class="dg-l" x="864" y="154">12</text><text class="dg-l" x="892" y="154">13</text><text class="dg-l" x="920" y="154">14</text><text class="dg-l" x="948" y="154">15</text>
<text class="dg-l" x="780" y="172">16</text><text class="dg-l" x="808" y="172">17</text><text class="dg-l" x="836" y="172">18</text><rect class="dg-pri" x="860" y="161" width="20" height="15" rx="7"/><text class="dg-bw" x="864" y="172">19</text><text class="dg-l" x="892" y="172">20</text><text class="dg-l" x="920" y="172">21</text><text class="dg-l" x="948" y="172">22</text>
<text class="dg-l" x="780" y="190">23</text><text class="dg-l" x="808" y="190">24</text><text class="dg-l" x="836" y="190">25</text><text class="dg-l" x="864" y="190">26</text><text class="dg-l" x="892" y="190">27</text><text class="dg-l" x="920" y="190">28</text><text class="dg-l" x="948" y="190">29</text>
<text class="dg-l" x="780" y="208">30</text>
<text class="dg-l" x="764" y="242">A day of the small month opens that day.</text>
<text class="dg-l" x="26" y="310">A :date field has no time: each event takes the whole day.</text>
</svg>
<figcaption>The day view: every batch in the tanks on November 19 (today), with its fields and its dates in full. A batch without a package date is an event of its brew day only.</figcaption>
</figure>

### Week

<figure>
<svg class="dg-svg" viewBox="0 0 1000 330" role="img" aria-labelledby="dg-calw-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-calw-t">The week view of the batches calendar, November 16 to 22, 2026: five batches as spans over the days of the week, today marked, and the keyboard focus on one event</title>
<rect class="dg-p" x="10" y="10" width="980" height="310" rx="8"/>
<text class="dg-h" x="26" y="40">Nov 16 – 22, 2026</text>
<rect class="dg-b" x="190" y="24" width="54" height="22" rx="4"/><text class="dg-bt" x="200" y="39">Today</text>
<rect class="dg-b" x="250" y="24" width="24" height="22" rx="4"/><text class="dg-bt" x="258" y="39">‹</text>
<rect class="dg-b" x="278" y="24" width="24" height="22" rx="4"/><text class="dg-bt" x="286" y="39">›</text>
<rect class="dg-tb" x="672" y="27" width="122" height="16" rx="3"/><text class="dg-t" x="677" y="39">granularity :week</text>
<rect class="dg-b" x="800" y="24" width="40" height="22" rx="4"/><text class="dg-bt" x="808" y="39">Day</text>
<rect class="dg-pri" x="844" y="24" width="48" height="22" rx="4"/><text class="dg-bw" x="852" y="39">Week</text>
<rect class="dg-b" x="896" y="24" width="56" height="22" rx="4"/><text class="dg-bt" x="904" y="39">Month</text>
<rect class="dg-hl" x="430" y="56" width="136" height="256"/>
<rect class="dg-c" x="22" y="56" width="952" height="256"/>
<line class="dg-g" x1="22" y1="98" x2="974" y2="98"/>
<line class="dg-g" x1="158" y1="56" x2="158" y2="312"/><line class="dg-g" x1="294" y1="56" x2="294" y2="312"/><line class="dg-g" x1="430" y1="56" x2="430" y2="312"/><line class="dg-g" x1="566" y1="56" x2="566" y2="312"/><line class="dg-g" x1="702" y1="56" x2="702" y2="312"/><line class="dg-g" x1="838" y1="56" x2="838" y2="312"/>
<text class="dg-l" x="28" y="72">Mon</text><text class="dg-l" x="164" y="72">Tue</text><text class="dg-l" x="300" y="72">Wed</text><text class="dg-l" x="436" y="72">Thu</text><text class="dg-l" x="572" y="72">Fri</text><text class="dg-l" x="708" y="72">Sat</text><text class="dg-l" x="844" y="72">Sun</text>
<text class="dg-st" x="28" y="90">16</text><text class="dg-st" x="164" y="90">17</text><text class="dg-st" x="300" y="90">18</text><rect class="dg-pri" x="433" y="78" width="24" height="16" rx="8"/><text class="dg-bw" x="438" y="90">19</text><text class="dg-st" x="572" y="90">20</text><text class="dg-st" x="708" y="90">21</text><text class="dg-st" x="844" y="90">22</text>
<rect class="dg-bar" x="25" y="106" width="946" height="34" rx="4"/><text class="dg-bt" x="31" y="121">‹ B-2026-044 · Hazy Daze IPA</text><text class="dg-l" x="31" y="135">Nov 12 → Nov 25</text><text class="dg-bt" x="958" y="121">›</text>
<rect class="dg-bar" x="25" y="146" width="674" height="34" rx="4"/><text class="dg-bt" x="31" y="161">‹ B-2026-043 · Midnight Stout</text><text class="dg-l" x="31" y="175">Nov 5 → Nov 20</text>
<rect class="dg-bar" x="161" y="186" width="810" height="34" rx="4"/><text class="dg-bt" x="167" y="201">B-2026-045 · Copper Pale Ale</text><text class="dg-l" x="167" y="215">Nov 17 → Nov 27</text><text class="dg-bt" x="958" y="201">›</text>
<rect class="dg-bar" x="433" y="226" width="538" height="34" rx="4"/><text class="dg-bt" x="439" y="241">B-2026-047 · Old Mill Porter</text><text class="dg-l" x="439" y="255">Nov 19 → Nov 24</text><text class="dg-bt" x="958" y="241">›</text>
<rect class="dg-bar" x="433" y="266" width="130" height="34" rx="4"/><text class="dg-bt" x="439" y="281">B-2026-046</text><text class="dg-l" x="439" y="295">Sunday Wheat</text>
<rect class="dg-foc" x="431" y="264" width="134" height="38" rx="5"/>
<rect class="dg-tb" x="590" y="276" width="250" height="16" rx="3"/><text class="dg-t" x="595" y="288">date_field · end_date_field (a span)</text>
</svg>
<figcaption>The week view: each batch is one bar from its brew date to its package date; ‹ and › show a span that starts before the week or ends after it. Today (Thursday) is marked. The focused event opens the card with Enter.</figcaption>
</figure>

### Month

<figure>
<svg class="dg-svg" viewBox="0 0 1000 580" role="img" aria-labelledby="dg-calm-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-calm-t">The month view of the batches calendar, November 2026: spans that wrap to the next week, today marked, and the days with more events than room show a more button</title>
<rect class="dg-p" x="10" y="10" width="980" height="560" rx="8"/>
<text class="dg-h" x="26" y="40">November 2026</text>
<rect class="dg-b" x="160" y="24" width="54" height="22" rx="4"/><text class="dg-bt" x="170" y="39">Today</text>
<rect class="dg-b" x="220" y="24" width="24" height="22" rx="4"/><text class="dg-bt" x="228" y="39">‹</text>
<rect class="dg-b" x="248" y="24" width="24" height="22" rx="4"/><text class="dg-bt" x="256" y="39">›</text>
<rect class="dg-b" x="800" y="24" width="40" height="22" rx="4"/><text class="dg-bt" x="808" y="39">Day</text>
<rect class="dg-b" x="844" y="24" width="48" height="22" rx="4"/><text class="dg-bt" x="852" y="39">Week</text>
<rect class="dg-pri" x="896" y="24" width="56" height="22" rx="4"/><text class="dg-bw" x="904" y="39">Month</text>
<text class="dg-l" x="28" y="78">Mon</text><text class="dg-l" x="164" y="78">Tue</text><text class="dg-l" x="300" y="78">Wed</text><text class="dg-l" x="436" y="78">Thu</text><text class="dg-l" x="572" y="78">Fri</text><text class="dg-l" x="708" y="78">Sat</text><text class="dg-l" x="844" y="78">Sun</text>
<rect class="dg-hl" x="430" y="314" width="136" height="76"/>
<rect class="dg-c" x="22" y="86" width="952" height="456"/>
<line class="dg-g" x1="22" y1="162" x2="974" y2="162"/><line class="dg-g" x1="22" y1="238" x2="974" y2="238"/><line class="dg-g" x1="22" y1="314" x2="974" y2="314"/><line class="dg-g" x1="22" y1="390" x2="974" y2="390"/><line class="dg-g" x1="22" y1="466" x2="974" y2="466"/>
<line class="dg-g" x1="158" y1="86" x2="158" y2="542"/><line class="dg-g" x1="294" y1="86" x2="294" y2="542"/><line class="dg-g" x1="430" y1="86" x2="430" y2="542"/><line class="dg-g" x1="566" y1="86" x2="566" y2="542"/><line class="dg-g" x1="702" y1="86" x2="702" y2="542"/><line class="dg-g" x1="838" y1="86" x2="838" y2="542"/>
<text class="dg-l" x="28" y="98" opacity=".4">26</text><text class="dg-l" x="164" y="98" opacity=".4">27</text><text class="dg-l" x="300" y="98" opacity=".4">28</text><text class="dg-l" x="436" y="98" opacity=".4">29</text><text class="dg-l" x="572" y="98" opacity=".4">30</text><text class="dg-l" x="708" y="98" opacity=".4">31</text><text class="dg-l" x="844" y="98">1</text>
<text class="dg-l" x="28" y="174">2</text><text class="dg-l" x="164" y="174">3</text><text class="dg-l" x="300" y="174">4</text><text class="dg-l" x="436" y="174">5</text><text class="dg-l" x="572" y="174">6</text><text class="dg-l" x="708" y="174">7</text><text class="dg-l" x="844" y="174">8</text>
<text class="dg-l" x="28" y="250">9</text><text class="dg-l" x="164" y="250">10</text><text class="dg-l" x="300" y="250">11</text><text class="dg-l" x="436" y="250">12</text><text class="dg-l" x="572" y="250">13</text><text class="dg-l" x="708" y="250">14</text><text class="dg-l" x="844" y="250">15</text>
<text class="dg-l" x="28" y="326">16</text><text class="dg-l" x="164" y="326">17</text><text class="dg-l" x="300" y="326">18</text><rect class="dg-pri" x="433" y="316" width="22" height="14" rx="7"/><text class="dg-bw" x="437" y="327">19</text><text class="dg-l" x="572" y="326">20</text><text class="dg-l" x="708" y="326">21</text><text class="dg-l" x="844" y="326">22</text>
<text class="dg-l" x="28" y="402">23</text><text class="dg-l" x="164" y="402">24</text><text class="dg-l" x="300" y="402">25</text><text class="dg-l" x="436" y="402">26</text><text class="dg-l" x="572" y="402">27</text><text class="dg-l" x="708" y="402">28</text><text class="dg-l" x="844" y="402">29</text>
<text class="dg-l" x="28" y="478">30</text><text class="dg-l" x="164" y="478" opacity=".4">1</text><text class="dg-l" x="300" y="478" opacity=".4">2</text><text class="dg-l" x="436" y="478" opacity=".4">3</text><text class="dg-l" x="572" y="478" opacity=".4">4</text><text class="dg-l" x="708" y="478" opacity=".4">5</text><text class="dg-l" x="844" y="478" opacity=".4">6</text>
<rect class="dg-bar" x="297" y="103" width="674" height="14" rx="3"/><text class="dg-bt" x="303" y="114">B-2026-042 · Harbor Lager</text>
<rect class="dg-bar" x="25" y="179" width="946" height="14" rx="3"/><text class="dg-bt" x="31" y="190">B-2026-042 · Harbor Lager</text>
<rect class="dg-bar" x="433" y="195" width="538" height="14" rx="3"/><text class="dg-bt" x="439" y="206">B-2026-043 · Midnight Stout</text>
<rect class="dg-bar" x="25" y="255" width="402" height="14" rx="3"/><text class="dg-bt" x="31" y="266">B-2026-042 · Harbor Lager</text>
<rect class="dg-bar" x="433" y="255" width="538" height="14" rx="3"/><text class="dg-bt" x="439" y="266">B-2026-044 · Hazy Daze IPA</text>
<rect class="dg-bar" x="25" y="271" width="946" height="14" rx="3"/><text class="dg-bt" x="31" y="282">B-2026-043 · Midnight Stout</text>
<rect class="dg-bar" x="25" y="331" width="946" height="14" rx="3"/><text class="dg-bt" x="31" y="342">B-2026-044 · Hazy Daze IPA</text>
<rect class="dg-bar" x="25" y="347" width="674" height="14" rx="3"/><text class="dg-bt" x="31" y="358">B-2026-043 · Midnight Stout</text>
<rect class="dg-bar" x="161" y="363" width="810" height="14" rx="3"/><text class="dg-bt" x="167" y="374">B-2026-045 · Copper Pale Ale</text>
<text class="dg-a" x="436" y="387">+2 more</text><text class="dg-a" x="572" y="387">+1 more</text><text class="dg-a" x="708" y="387">+1 more</text><text class="dg-a" x="844" y="387">+1 more</text>
<rect class="dg-bar" x="25" y="407" width="402" height="14" rx="3"/><text class="dg-bt" x="31" y="418">B-2026-044 · Hazy Daze IPA</text>
<rect class="dg-bar" x="25" y="423" width="674" height="14" rx="3"/><text class="dg-bt" x="31" y="434">B-2026-045 · Copper Pale Ale</text>
<rect class="dg-bar" x="25" y="439" width="266" height="14" rx="3"/><text class="dg-bt" x="31" y="450">B-2026-047 · Old Mill Porter</text>
<text class="dg-l" x="436" y="504">"+2 more" opens the day: B-2026-046 and B-2026-047.</text>
<text class="dg-l" x="26" y="562">The read: the batches that overlap Oct 26 – Dec 6 (the visible weeks).</text>
<rect class="dg-tb" x="590" y="550" width="380" height="16" rx="3"/><text class="dg-t" x="595" y="562">date_field :brew_date · end_date_field :package_date</text>
</svg>
<figcaption>The month view: a span is one bar in each week that it crosses. A day has room for three lanes; "+2 more" opens the other events of the day. The days of October and December are dim.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive
view :list do
  type :calendar
  label "Calendar"
  date_field :brew_date
  end_date_field :package_date
  granularity :week
  field :batch_number
  field :name, path: [:recipe], label: "Recipe"
end
```

<!-- tabs-close -->

The three tabs are one view: the user switches the period, and
`granularity :week` opens it on the week of today.

[↑ View types](#view-types)

## Gantt charts

A `:gantt` draws a bar for each record from its `start_field` to its
`end_field`, on a time scale, with a row for each record. It is for a
schedule: the batches in the tanks, the jobs of a machine, the steps of a
project. `progress_field` fills the bar; `group_by` puts the rows in
groups.

| Option | Required | The UI |
|---|---|---|
| `start_field` | yes | The start of the bar: a date or a datetime attribute (a compile error without it, with the date attributes as suggestions). |
| `end_field` | yes | The end of the bar (inclusive for a date). |
| `progress_field` | no | A number from 0 to 100: the filled part of the bar, and its text ("60 %"). |
| `group_by` | no | A field of the record: a group of rows for each value, with a heading. |
| `field` | no | The columns of the table at the left of the chart (the first is the name of the row), and the accessible name of the bar. |

The DSL has no dependencies between the bars and no milestones. A chart
with them is a `:render` view ([The render view](#the-render-view)).

A table at the left (the `field` entities) and the time scale at the
right, with the same rows, a header of the periods, and a line for today.
A record without an end shows a marker at its start; a record without a
start stays in the table, without a bar. When the view names an update
action that accepts both fields, the renderer may let the user drag a bar
or its ends.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 350" role="img" aria-labelledby="dg-gantt-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-gantt-t">A gantt chart of six batches in groups by status: a table of the batch and the recipe, a bar for each batch over five weeks, a progress fill, a batch without an end date, and the line of today</title>
<rect class="dg-p" x="10" y="10" width="980" height="330" rx="8"/>
<rect class="dg-tb" x="22" y="18" width="118" height="16" rx="3"/><text class="dg-t" x="27" y="30">group_by :status</text>
<text class="dg-l" x="26" y="56">Batch</text><text class="dg-l" x="120" y="56">Recipe</text>
<text class="dg-l" x="274" y="56">Oct 26</text><text class="dg-l" x="414" y="56">Nov 2</text><text class="dg-l" x="554" y="56">Nov 9</text><text class="dg-l" x="694" y="56">Nov 16</text><text class="dg-l" x="834" y="56">Nov 23</text>
<line class="dg-g" x1="22" y1="64" x2="974" y2="64"/>
<rect class="dg-s" x="22" y="64" width="952" height="24"/><text class="dg-st" x="26" y="81">Complete</text>
<rect class="dg-s" x="22" y="112" width="952" height="24"/><text class="dg-st" x="26" y="129">Conditioning</text>
<rect class="dg-s" x="22" y="160" width="952" height="24"/><text class="dg-st" x="26" y="177">Fermenting</text>
<rect class="dg-s" x="22" y="232" width="952" height="24"/><text class="dg-st" x="26" y="249">Brewing</text>
<line class="dg-g" x1="266" y1="44" x2="266" y2="304"/>
<line class="dg-g" x1="410" y1="64" x2="410" y2="304"/><line class="dg-g" x1="550" y1="64" x2="550" y2="304"/><line class="dg-g" x1="690" y1="64" x2="690" y2="304"/><line class="dg-g" x1="830" y1="64" x2="830" y2="304"/><line class="dg-g" x1="970" y1="64" x2="970" y2="304"/>
<text class="dg-v" x="26" y="105">B-2026-042</text><text class="dg-v" x="120" y="105">Harbor Lager</text>
<rect class="dg-bar" x="310" y="92" width="300" height="16" rx="3"/><text class="dg-bt" x="316" y="104">Oct 28 → Nov 11</text>
<text class="dg-v" x="26" y="153">B-2026-043</text><text class="dg-v" x="120" y="153">Midnight Stout</text>
<rect class="dg-bar" x="470" y="140" width="320" height="16" rx="3"/><rect x="470" y="140" width="192" height="16" rx="3" fill="#2563eb" fill-opacity=".45"/><text class="dg-bt" x="476" y="152">Nov 5 → Nov 20 · 60 %</text>
<rect class="dg-tb" x="796" y="140" width="104" height="16" rx="3"/><text class="dg-t" x="801" y="152">progress_field</text>
<text class="dg-v" x="26" y="201">B-2026-044</text><text class="dg-v" x="120" y="201">Hazy Daze IPA</text>
<rect class="dg-bar" x="610" y="188" width="280" height="16" rx="3"/><text class="dg-bt" x="616" y="200">Nov 12 → Nov 25</text>
<rect class="dg-foc" x="608" y="186" width="284" height="20" rx="4"/>
<text class="dg-v" x="26" y="225">B-2026-045</text><text class="dg-v" x="120" y="225">Copper Pale Ale</text>
<rect class="dg-bar" x="710" y="212" width="220" height="16" rx="3"/><text class="dg-bt" x="716" y="224">Nov 17 → Nov 27</text>
<text class="dg-v" x="26" y="273">B-2026-047</text><text class="dg-v" x="120" y="273">Old Mill Porter</text>
<rect class="dg-bar" x="750" y="260" width="120" height="16" rx="3"/><text class="dg-bt" x="756" y="272">Nov 19 → Nov 24</text>
<text class="dg-v" x="26" y="297">B-2026-046</text><text class="dg-v" x="120" y="297">Sunday Wheat</text>
<rect class="dg-c" x="750" y="284" width="40" height="16" rx="3"/><text class="dg-l" x="796" y="296">no package date</text>
<line x1="760" y1="44" x2="760" y2="308" stroke="#dc2626" stroke-dasharray="3 2"/><text class="dg-errt" x="765" y="318">today</text>
<rect class="dg-tb" x="22" y="314" width="320" height="16" rx="3"/><text class="dg-t" x="27" y="326">start_field :brew_date · end_field :package_date</text>
</svg>
<figcaption>Batches from the brew date to the package date, in a group for each status. The table at the left is the fields of the view. The fill of B-2026-043 is a <code>progress_field</code> (hypothetical: <code>Brewery.Batch</code> has no percentage). B-2026-046 has no package date: a marker at its start. The focused bar opens the card with Enter.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive
view :list do
  type :gantt
  label "Schedule"
  start_field :brew_date
  end_field :package_date
  group_by :status
  field :batch_number
  field :name, path: [:recipe], label: "Recipe"

  # progress_field :percent_done  # a 0–100 number (not in the Brewery domain)
end
```

<!-- tabs-close -->

[↑ View types](#view-types)

## Timelines

A `:timeline` shows each record as an event at its `date_field`, or as a
span from `date_field` to `end_date_field`, in time order. The content of
an event is the record tree of the view (its `field`, `section`, `row`,
... in view mode, `PyroManiac.Card.tree/1`); an event opens the card.
Typical uses: the history of a record, a log, the transitions of a
workflow, the batches of a season.

| Option | Required | The UI |
|---|---|---|
| `date_field` | yes | The date or the start of an event: a date or a datetime attribute (a compile error without it). |
| `end_date_field` | no | The end: the event is a span. A record without an end is an open span ("since Nov 19"). |
| `orientation` | no (`:vertical`) | The axis of time: `:vertical` (the events from top to bottom) or `:horizontal` (the events from left to right, on a scrollable time axis). On another view type, a compile error. |
| the record tree | no | The content of each event. |
| `default_sort` | no | The order. Without it, `date_field` descending (newest first). |

**Vertical** is a list of the events from top to bottom, grouped by day
(and by month for a long range), with **Load more** at its end.
**Horizontal** is a time axis from left to right that scrolls, with zoom
levels, **Today**, and the events in lanes: a span is a bar, an event
without a span is a point. Each event shows its dates as text; an event
opens the card.

<!-- tabs-open -->

### Vertical

<figure>
<svg class="dg-svg" viewBox="0 0 1000 370" role="img" aria-labelledby="dg-tlv-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-tlv-t">A vertical timeline of batches, newest first, under a month heading and grouped by day: spans, an open span, and a Load more button</title>
<rect class="dg-p" x="10" y="10" width="980" height="350" rx="8"/>
<rect class="dg-tb" x="700" y="18" width="244" height="16" rx="3"/><text class="dg-t" x="705" y="30">orientation :vertical (the default)</text>
<text class="dg-h" x="26" y="44">November 2026</text>
<line class="dg-g" x1="60" y1="56" x2="60" y2="318"/>
<circle cx="60" cy="66" r="4" class="dg-i"/><text class="dg-st" x="80" y="70">Thursday, November 19</text>
<circle cx="60" cy="100" r="6" class="dg-info"/>
<rect class="dg-s" x="80" y="80" width="560" height="40" rx="5"/>
<rect class="dg-foc" x="78" y="78" width="564" height="44" rx="6"/>
<text class="dg-st" x="92" y="97">B-2026-047</text><text class="dg-v" x="190" y="97">Old Mill Porter</text><text class="dg-l" x="92" y="113">Nov 19 → Nov 24 · Brewing</text>
<rect class="dg-tb" x="660" y="92" width="150" height="16" rx="3"/><text class="dg-t" x="665" y="104">date_field :brew_date</text>
<circle cx="60" cy="146" r="6" class="dg-info"/>
<rect class="dg-s" x="80" y="126" width="560" height="40" rx="5"/>
<text class="dg-st" x="92" y="143">B-2026-046</text><text class="dg-v" x="190" y="143">Sunday Wheat</text><text class="dg-l" x="92" y="159">since Nov 19 · Brewing</text>
<text class="dg-l" x="660" y="150">an open span: no package date</text>
<circle cx="60" cy="186" r="4" class="dg-i"/><text class="dg-st" x="80" y="190">Tuesday, November 17</text>
<circle cx="60" cy="220" r="6" class="dg-ok"/>
<rect class="dg-s" x="80" y="200" width="560" height="40" rx="5"/>
<text class="dg-st" x="92" y="217">B-2026-045</text><text class="dg-v" x="190" y="217">Copper Pale Ale</text><text class="dg-l" x="92" y="233">Nov 17 → Nov 27 · Fermenting</text>
<rect class="dg-tb" x="660" y="212" width="198" height="16" rx="3"/><text class="dg-t" x="665" y="224">end_date_field :package_date</text>
<circle cx="60" cy="260" r="4" class="dg-i"/><text class="dg-st" x="80" y="264">Thursday, November 12</text>
<circle cx="60" cy="294" r="6" class="dg-ok"/>
<rect class="dg-s" x="80" y="274" width="560" height="40" rx="5"/>
<text class="dg-st" x="92" y="291">B-2026-044</text><text class="dg-v" x="190" y="291">Hazy Daze IPA</text><text class="dg-l" x="92" y="307">Nov 12 → Nov 25 · Fermenting</text>
<rect class="dg-tb" x="660" y="286" width="182" height="16" rx="3"/><text class="dg-t" x="665" y="298">default_sort "-brew_date"</text>
<rect class="dg-b" x="80" y="326" width="90" height="22" rx="4"/><text class="dg-bt" x="96" y="341">Load more</text>
</svg>
<figcaption>The vertical timeline: newest first, a month heading, and a heading for each day. A batch with a package date is a span; without one, it is open. <b>Load more</b> reads the next page.</figcaption>
</figure>

### Horizontal

<figure>
<svg class="dg-svg" viewBox="0 0 1000 300" role="img" aria-labelledby="dg-tlh-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-tlh-t">A horizontal timeline of batches over November 2026: a week scale, spans as bars in lanes, an open span, the line of today, zoom levels, and a scrollbar</title>
<rect class="dg-p" x="10" y="10" width="980" height="280" rx="8"/>
<text class="dg-h" x="26" y="40">November 2026</text>
<rect class="dg-b" x="170" y="24" width="54" height="22" rx="4"/><text class="dg-bt" x="180" y="39">Today</text>
<rect class="dg-b" x="230" y="24" width="24" height="22" rx="4"/><text class="dg-bt" x="238" y="39">‹</text>
<rect class="dg-b" x="258" y="24" width="24" height="22" rx="4"/><text class="dg-bt" x="266" y="39">›</text>
<rect class="dg-tb" x="420" y="27" width="162" height="16" rx="3"/><text class="dg-t" x="425" y="39">orientation :horizontal</text>
<text class="dg-l" x="764" y="39">Zoom</text>
<rect class="dg-b" x="800" y="24" width="44" height="22" rx="4"/><text class="dg-bt" x="808" y="39">Days</text>
<rect class="dg-pri" x="848" y="24" width="52" height="22" rx="4"/><text class="dg-bw" x="856" y="39">Weeks</text>
<rect class="dg-b" x="904" y="24" width="60" height="22" rx="4"/><text class="dg-bt" x="912" y="39">Months</text>
<rect class="dg-c" x="22" y="52" width="956" height="196"/>
<text class="dg-l" x="74" y="68">Nov 2</text><text class="dg-l" x="284" y="68">Nov 9</text><text class="dg-l" x="494" y="68">Nov 16</text><text class="dg-l" x="704" y="68">Nov 23</text><text class="dg-l" x="914" y="68">Nov 30</text>
<line class="dg-g" x1="22" y1="74" x2="978" y2="74"/>
<line class="dg-g" x1="70" y1="52" x2="70" y2="248"/><line class="dg-g" x1="280" y1="52" x2="280" y2="248"/><line class="dg-g" x1="490" y1="52" x2="490" y2="248"/><line class="dg-g" x1="700" y1="52" x2="700" y2="248"/><line class="dg-g" x1="910" y1="52" x2="910" y2="248"/>
<rect class="dg-bar" x="22" y="92" width="348" height="22" rx="4"/><text class="dg-bt" x="28" y="107">‹ B-2026-042 · Harbor Lager</text>
<rect class="dg-bar" x="372" y="92" width="418" height="22" rx="4"/><text class="dg-bt" x="378" y="107">B-2026-044 · Hazy Daze IPA</text>
<rect class="dg-bar" x="160" y="120" width="480" height="22" rx="4"/><text class="dg-bt" x="166" y="135">B-2026-043 · Midnight Stout</text>
<rect class="dg-bar" x="520" y="148" width="330" height="22" rx="4"/><text class="dg-bt" x="526" y="163">B-2026-045 · Copper Pale Ale</text>
<rect class="dg-bar" x="580" y="176" width="180" height="22" rx="4"/><text class="dg-bt" x="584" y="191">B-2026-047 · Old Mill Porter</text>
<rect class="dg-foc" x="578" y="174" width="184" height="26" rx="5"/>
<rect class="dg-c" x="580" y="204" width="398" height="22" rx="4"/><text class="dg-bt" x="586" y="219">B-2026-046 · Sunday Wheat · since Nov 19 ›</text>
<line x1="595" y1="74" x2="595" y2="240" stroke="#dc2626" stroke-dasharray="3 2"/><text class="dg-errt" x="600" y="86">today</text>
<rect class="dg-i" x="22" y="256" width="956" height="8" rx="4"/><rect class="dg-b" x="200" y="256" width="420" height="8" rx="4"/>
<text class="dg-l" x="26" y="282">← → scroll · Page Up / Page Down: a screen · Home: today · + −: zoom · Tab: the events in time order</text>
</svg>
<figcaption>The horizontal timeline at the zoom of weeks: each batch is a bar from its brew date to its package date, in a lane; B-2026-042 starts before the visible range (‹). The open span of B-2026-046 runs to the end of the range. The focused bar opens the card with Enter.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive
view :list do
  type :timeline
  label "Timeline"
  date_field :brew_date
  end_date_field :package_date
  orientation :horizontal
  default_sort "-brew_date"
  field :batch_number
  field :name, path: [:recipe], label: "Recipe"
  field :status
end
```

Without `orientation` (or with `orientation :vertical`), the same view is
the vertical timeline.

<!-- tabs-close -->

[↑ View types](#view-types)

## Kanban boards

A `:kanban` needs the `PyroManiac.KanBan` extension on the resource. The
`kan_ban` section gives the board; the transformer sets `group_by`,
`priority`, and `kanban_action` of the view from it, and `default_sort` to
the priority. These options on a `:kanban` view are a compile error.

| `kan_ban` | The UI |
|---|---|
| `lane` | An attribute (an enum or `one_of`): a lane for each value, in order (static lanes). A `belongs_to`: a lane for each record of its destination ([Dynamic lanes](#dynamic-lanes)). |
| `priority` | The order of the cards in a lane (a fractional index, a string). |
| `move_action` | The card move. A drop of a card runs it: the new lane, with the arguments `target_id` and `placement` (`:before`, `:after`, or `:last`). |
| `lane` options | Dynamic lanes only: `read_action` and `sort` read and order the lanes; `create_action`, `update_action`, and `destroy_action` manage them; `move_action` (of the `lane`) moves them. |
| `read_action` | Loads one lane (its `lane_value` argument), sorted, `per_lane` at a time. |
| `per_lane` | The cards of a lane before **Load more** (default 20). |
| `count?` | The count of each lane in its header. |

A lane for each value, side by side, with its count (`count?`). Each lane
loads its own cards, `per_lane` at a time, with **Load more**. The filter
of the user applies to each lane; an empty lane stays, as a drop target.
The user drags a card to another lane or position (or picks it up with
Space and moves it with the arrows); the card is at its new place at once,
the drop runs the move action, and a failure puts the card back with the
error. The order in a lane is the priority: a board has no sort menu.

With realtime options (`on_create :append`, `on_update :replace`,
`on_destroy :remove`; [Realtime](pages.md#realtime)), the board follows
the changes of the other users card by card: a moved card slides to its
lane and place, and flashes; nothing else reads again.
With `track_presence? true`, a card that another user moves is marked
"Moving" with the user, and a bar shows where it would drop; the cards do
not move until the drop.

`orientation` of the view: `:horizontal` (the default) puts the lanes side
by side; `:vertical` stacks them as rows, the cards of each lane from left
to right (for many lanes with few cards each).

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 300" role="img" aria-labelledby="dg-kb-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-kb-t">A kanban board of batches with a lane for each status, a count in each lane header, and a card that moves from Planned to Brewing</title>
<rect class="dg-p" x="10" y="10" width="980" height="280" rx="8"/>
<rect class="dg-tb" x="22" y="18" width="88" height="16" rx="3"/><text class="dg-t" x="27" y="30">lane :status</text>
<rect class="dg-tb" x="118" y="18" width="82" height="16" rx="3"/><text class="dg-t" x="123" y="30">count? true</text>
<rect class="dg-s" x="22" y="40" width="230" height="240" rx="6"/><text class="dg-st" x="34" y="62">Planned</text><text class="dg-l" x="96" y="62">3</text>
<rect class="dg-s" x="264" y="40" width="230" height="240" rx="6"/><text class="dg-st" x="276" y="62">Brewing</text><text class="dg-l" x="336" y="62">1</text>
<rect class="dg-s" x="506" y="40" width="230" height="240" rx="6"/><text class="dg-st" x="518" y="62">Fermenting</text><text class="dg-l" x="596" y="62">24</text>
<rect class="dg-s" x="748" y="40" width="230" height="240" rx="6"/><text class="dg-st" x="760" y="62">Conditioning</text><text class="dg-l" x="848" y="62">2</text>
<rect class="dg-m" x="32" y="74" width="210" height="56" rx="5"/><text class="dg-st" x="42" y="94">B-2026-046</text><text class="dg-a" x="42" y="112">Copper Pale Ale</text><text class="dg-l" x="42" y="124">Ben Okafor</text>
<rect class="dg-c" x="32" y="138" width="210" height="56" rx="5"/>
<rect class="dg-m" x="32" y="202" width="210" height="56" rx="5"/><text class="dg-st" x="42" y="222">B-2026-048</text><text class="dg-a" x="42" y="240">Sunday Wheat</text><text class="dg-l" x="42" y="252">—</text>
<rect class="dg-m" x="274" y="74" width="210" height="56" rx="5"/><text class="dg-st" x="284" y="94">B-2026-045</text><text class="dg-a" x="284" y="112">Harbor Lager</text><text class="dg-l" x="284" y="124">Dev Patel</text>
<rect class="dg-c" x="274" y="138" width="210" height="56" rx="5" stroke="#2563eb"/>
<rect class="dg-m" x="296" y="150" width="210" height="56" rx="5" stroke="#2563eb" stroke-width="2"/><text class="dg-st" x="306" y="170">B-2026-047</text><text class="dg-a" x="306" y="188">Hazy Daze IPA</text><text class="dg-l" x="306" y="200">Ana Ruiz</text>
<rect class="dg-tb" x="300" y="214" width="174" height="16" rx="3"/><text class="dg-t" x="305" y="226">move_action :move_card</text>
<rect class="dg-m" x="516" y="74" width="210" height="56" rx="5"/><text class="dg-st" x="526" y="94">B-2026-044</text><text class="dg-a" x="526" y="112">Hazy Daze IPA</text><text class="dg-l" x="526" y="124">Ana Ruiz</text>
<rect class="dg-m" x="516" y="138" width="210" height="56" rx="5"/><text class="dg-st" x="526" y="158">B-2026-040</text><text class="dg-a" x="526" y="176">Old Mill Porter</text><text class="dg-l" x="526" y="188">Chloe Park</text>
<rect class="dg-b" x="516" y="206" width="210" height="24" rx="4"/><text class="dg-bt" x="584" y="222">Load more</text>
<rect class="dg-tb" x="540" y="240" width="88" height="16" rx="3"/><text class="dg-t" x="545" y="252">per_lane 20</text>
<rect class="dg-m" x="758" y="74" width="210" height="56" rx="5"/><text class="dg-st" x="768" y="94">B-2026-043</text><text class="dg-a" x="768" y="112">Midnight Stout</text><text class="dg-l" x="768" y="124">Ben Okafor</text>
<rect class="dg-m" x="758" y="138" width="210" height="56" rx="5"/><text class="dg-st" x="768" y="158">B-2026-039</text><text class="dg-a" x="768" y="176">Hazy Daze IPA</text><text class="dg-l" x="768" y="188">Dev Patel</text>
</svg>
<figcaption>The batches board. B-2026-047 moves from Planned to Brewing, below B-2026-045. The move runs the move action. The Fermenting lane has 24 cards: <b>Load more</b> loads the next 20.</figcaption>
</figure>

### DSL

```elixir
# the resource
defmodule Brewery.Batch do
  use Ash.Resource,
    domain: Brewery.Domain,
    extensions: [PyroManiac.Resource, PyroManiac.KanBan]

  kan_ban do
    lane :status
    priority :kanban_priority
    count? true
    per_lane 20
    move_action :move_card
    read_action :kanban_read
  end
end

# the page
view :kanban_read do
  type :kanban
  label "Board"
  field :batch_number

  field :recipe do
    link_to BreweryWeb.RecipeLive
  end

  field :brewer
end
```

<!-- tabs-close -->

### Dynamic lanes

A `lane` that is a `belongs_to` gives dynamic lanes: the records of its
destination are the lanes. The destination is an existing resource (the
stages of a project) or a lane resource with `PyroManiac.KanBan.Lanes`
(`id`, `name`, `decoration`, the order, and the actions `read`, `create`,
`update`, `destroy`, and `move`). The options of the `lane` read and order
the lanes (`read_action`, `sort`); add, edit, and delete them
(`create_action`, `update_action`, `destroy_action`); and move them
(`move_action`). Each action defaults to the primary action of that type
on the lane resource (`move_action`: the move action of an ordered lane
resource); `false` turns one off. The `move_action` of the `lane` moves
the lanes; the `move_action` of the `kan_ban` section moves the cards. A named action that the lane resource does not have, or of another
type, is a compile error.

- When the foreign key allows `nil`, the board has a lane "No lane" for
  the cards without one (first). A drop on it sets the foreign key to
  `nil`.
- A lane record with a `decoration` styles its header
  ([Decorations](decorations.md)).
- The board has a lane control for each lane action: **Add lane** after
  the last lane (create), and **Edit** (update), **Delete** (destroy,
  with the `destroy_confirm` of the lane: a message, or `false`; required
  when the board deletes lanes), and **Move** (`move_action`; by default on a lane
  resource with `PyroManiac.Ordering` or `PyroManiac.KanBan.Lanes`) in the
  menu of each lane header. A control that the
  actor cannot run is hidden. What a delete does to the cards (a cascade,
  a nilify, or a refusal) is the business of the lane resource; an error
  keeps the lane.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 220" role="img" aria-labelledby="dg-kbl-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-kbl-t">A kanban board of tasks with the lanes of a project: No lane, To do, Review with a warning decoration, and Done, a lane menu, and an Add lane button</title>
<rect class="dg-p" x="10" y="10" width="980" height="200" rx="8"/>
<rect class="dg-tb" x="22" y="18" width="80" height="16" rx="3"/><text class="dg-t" x="27" y="30">lane :stage</text>
<rect class="dg-tb" x="110" y="18" width="156" height="16" rx="3"/><text class="dg-t" x="115" y="30">create_action :create</text>
<rect class="dg-s" x="22" y="40" width="190" height="160" rx="6"/><text class="dg-st" x="34" y="62">No lane</text>
<rect class="dg-s" x="222" y="40" width="190" height="160" rx="6"/><text class="dg-st" x="234" y="62">To do</text><text class="dg-l" x="384" y="62">⋮</text>
<rect class="dg-s" x="422" y="40" width="190" height="160" rx="6" stroke="#d97706" stroke-width="2"/><text class="dg-st" x="434" y="62">Review</text><text class="dg-l" x="584" y="62">⋮</text>
<rect class="dg-s" x="622" y="40" width="190" height="160" rx="6"/><text class="dg-st" x="634" y="62">Done</text><text class="dg-l" x="784" y="62">⋮</text>
<rect class="dg-m" x="32" y="74" width="170" height="40" rx="5"/><text class="dg-a" x="42" y="98">Order hops</text>
<rect class="dg-m" x="232" y="74" width="170" height="40" rx="5"/><text class="dg-a" x="242" y="98">Clean fermenter</text>
<rect class="dg-m" x="432" y="74" width="170" height="40" rx="5"/><text class="dg-a" x="442" y="98">Label artwork</text>
<rect class="dg-tb" x="440" y="124" width="150" height="16" rx="3"/><text class="dg-t" x="445" y="136">decoration :warning</text>
<rect class="dg-m" x="632" y="74" width="170" height="40" rx="5"/><text class="dg-a" x="642" y="98">Recipe review</text>
<rect class="dg-b" x="822" y="40" width="150" height="24" rx="4"/><text class="dg-bt" x="852" y="56">Add lane</text>
<rect class="dg-c" x="822" y="74" width="150" height="70" rx="5"/><text class="dg-l" x="832" y="94">Rename</text><text class="dg-l" x="832" y="112">Move left / right</text><text class="dg-l" x="832" y="130">Delete…</text>
</svg>
<figcaption>The tasks board of a project. Each stage is a lane; "No lane" holds the tasks without a stage. The menu of a lane header renames, moves, and deletes it; <b>Add lane</b> creates one at the end.</figcaption>
</figure>

### DSL

```elixir
# the lane resource
defmodule Brewery.Stage do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.KanBan.Lanes]

  kan_ban_lanes do
    scope :project_id
  end

  relationships do
    belongs_to :project, Brewery.Project
  end
end

# the cards
defmodule Brewery.Task do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource, PyroManiac.KanBan]

  relationships do
    belongs_to :stage, Brewery.Stage
  end

  kan_ban do
    # read, create, update, and destroy: the primary actions of Brewery.Stage
    lane :stage
    priority :rank
    move_action :move_card
    read_action :kanban_read
  end
end

# the renderer: the lanes of one project
PyroManiac.KanBan.Info.lanes(Brewery.Task,
  actor: actor,
  query: Ash.Query.filter(Brewery.Stage, project_id == ^project.id)
)
```

<!-- tabs-close -->

[↑ View types](#view-types)

## Lists

A `:list` shows one line for each record, with the `field` entities of
the view: a compact list, for the records that a table would show with
too many empty columns (the staff, the ingredients of a recipe). With
`parent_field`, it is a tree: each record opens to its children.

| Option | Required | The UI |
|---|---|---|
| `field` | no | The values of each line, in order. The first is the name of the line. Without fields, the line shows the label of the record. |
| `parent_field` | no | The tree: a `belongs_to` relationship of the resource to the same resource (`belongs_to :parent, __MODULE__`). |
| `reorder?` | no | A drag handle on each line ([Reorder](#reorder)). |
| `selectable?` | no (`true`) | A checkbox on each line for the bulk actions. |

A flat list is one line for each record, in the order of the sort; the
values wrap on a phone; the whole line opens the record. A tree shows the
roots first, and the children of a record when it opens (▸ closed, ▾
open), indented one step for each level. The arrow keys move between the
lines, open and close the levels. With a filter, each match shows with the
path of its ancestors. With `reorder? true`, set the `scope` of
`PyroManiac.Ordering` to the foreign key of the parent: the children of
one parent reorder among themselves.

`parent_field` is not checked at compile time: the renderer raises a clear
error at run time when it is not a `belongs_to` to the same resource.

<!-- tabs-open -->

### Flat

<figure>
<svg class="dg-svg" viewBox="0 0 1000 176" role="img" aria-labelledby="dg-list-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-list-t">An outline list of the staff: the name, the role, and the email of each person</title>
<rect class="dg-p" x="10" y="10" width="980" height="156" rx="8"/>
<rect class="dg-tb" x="22" y="18" width="160" height="16" rx="3"/><text class="dg-t" x="27" y="30">view :list · type :list</text>
<text class="dg-st" x="26" y="62">Ana Ruiz</text><rect class="dg-b" x="200" y="49" width="84" height="18" rx="9"/><text class="dg-bt" x="210" y="62">Head brewer</text><text class="dg-l" x="300" y="62">ana@brewery.example</text>
<line class="dg-g" x1="22" y1="74" x2="978" y2="74"/>
<text class="dg-st" x="26" y="94">Ben Okafor</text><rect class="dg-b" x="200" y="81" width="56" height="18" rx="9"/><text class="dg-bt" x="210" y="94">Brewer</text><text class="dg-l" x="300" y="94">ben@brewery.example</text>
<line class="dg-g" x1="22" y1="106" x2="978" y2="106"/>
<text class="dg-st" x="26" y="126">Chloe Park</text><rect class="dg-b" x="200" y="113" width="58" height="18" rx="9"/><text class="dg-bt" x="210" y="126">Quality</text><text class="dg-l" x="300" y="126">chloe@brewery.example</text>
<line class="dg-g" x1="22" y1="138" x2="978" y2="138"/>
<g opacity=".5"><text class="dg-st" x="26" y="158">Erin Walsh</text><rect class="dg-b" x="200" y="145" width="52" height="18" rx="9"/><text class="dg-bt" x="210" y="158">Admin</text><text class="dg-l" x="300" y="158">inactive</text></g>
</svg>
<figcaption>The staff as a list. Each line shows the fields of the view. An inactive person is dim (a <code>decoration</code>).</figcaption>
</figure>

### Tree

<figure>
<svg class="dg-svg" viewBox="0 0 1000 340" role="img" aria-labelledby="dg-ltree-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-ltree-t">A tree list of the locations of a brewery: nested, indented rows with expand and collapse toggles, a collapsed group, the keyboard focus on a tank, and the children of a room that load</title>
<rect class="dg-p" x="10" y="10" width="980" height="320" rx="8"/>
<rect class="dg-tb" x="22" y="18" width="228" height="16" rx="3"/><text class="dg-t" x="27" y="30">type :list · parent_field :parent</text>
<text class="dg-l" x="26" y="56">Name</text><text class="dg-l" x="420" y="56">Kind</text><text class="dg-l" x="560" y="56">Capacity (L)</text>
<line class="dg-g" x1="22" y1="62" x2="978" y2="62"/>
<rect class="dg-hl" x="22" y="192" width="956" height="26"/>
<rect class="dg-foc" x="22" y="192" width="956" height="26" rx="3"/>
<text class="dg-v" x="26" y="79">▾</text><text class="dg-st" x="42" y="79">Brewhouse</text><text class="dg-v" x="420" y="79">Area</text><text class="dg-v" x="560" y="79">—</text>
<line class="dg-g" x1="31" y1="88" x2="31" y2="140"/>
<text class="dg-v" x="64" y="105">Mash tun</text><text class="dg-v" x="420" y="105">Vessel</text><text class="dg-v" x="560" y="105">1,200</text>
<text class="dg-v" x="64" y="131">Kettle</text><text class="dg-v" x="420" y="131">Vessel</text><text class="dg-v" x="560" y="131">1,200</text>
<line class="dg-g" x1="22" y1="140" x2="978" y2="140"/>
<text class="dg-v" x="26" y="157">▾</text><text class="dg-st" x="42" y="157">Cellar</text><text class="dg-v" x="420" y="157">Area</text><text class="dg-v" x="560" y="157">—</text>
<line class="dg-g" x1="31" y1="166" x2="31" y2="270"/>
<text class="dg-v" x="48" y="183">▾</text><text class="dg-st" x="64" y="183">Fermenters</text><text class="dg-v" x="420" y="183">Group</text><text class="dg-v" x="560" y="183">—</text>
<line class="dg-g" x1="53" y1="192" x2="53" y2="244"/>
<text class="dg-v" x="86" y="209">FV-01</text><text class="dg-v" x="420" y="209">Tank</text><text class="dg-v" x="560" y="209">2,400</text>
<text class="dg-l" x="700" y="209">→ opens · ← goes to the parent</text>
<text class="dg-v" x="86" y="235">FV-02</text><text class="dg-v" x="420" y="235">Tank</text><text class="dg-v" x="560" y="235">2,400</text>
<text class="dg-l" x="700" y="235">↑ ↓ move · Enter opens the card</text>
<text class="dg-v" x="48" y="261">▸</text><text class="dg-st" x="64" y="261">Bright tanks</text><text class="dg-v" x="420" y="261">Group</text><text class="dg-v" x="560" y="261">—</text>
<text class="dg-l" x="700" y="261">closed: aria-expanded="false"</text>
<line class="dg-g" x1="22" y1="270" x2="978" y2="270"/>
<text class="dg-v" x="26" y="287">▾</text><text class="dg-st" x="42" y="287">Cold room</text><text class="dg-v" x="420" y="287">Area</text><text class="dg-v" x="560" y="287">—</text>
<line class="dg-g" x1="31" y1="296" x2="31" y2="322"/>
<text class="dg-l" x="64" y="313">Loading…</text>
<text class="dg-l" x="700" y="313">the children load on the first open</text>
</svg>
<figcaption>A tree of the locations of a brewery (a hypothetical resource). Each level is indented under its parent; ▾ and ▸ open and close a level. The focus is on FV-01, level 3. <b>Cold room</b> has just opened: its children load.</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.StaffLive do
  use PyroManiac, resource: Brewery.Staff

  page do
    route "/staff"
    exclude [:read, :autocomplete, :create, :update, :deactivate, :destroy]
  end

  view :list do
    type :list
    primary? true
    field :name

    field :role do
      size :term
    end

    field :email do
      decoration expr(if active, do: nil, else: :neutral)
    end
  end

  view :list do
    type :card
    primary? true
    field :name
    field :role
    field :email
    field :active
  end
end
```

```elixir
# a resource with a parent (not in the Brewery domain)
defmodule Brewery.Location do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource]

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :kind, :atom, constraints: [one_of: [:area, :group, :vessel, :tank]], public?: true
    attribute :capacity_liters, :integer, public?: true
  end

  relationships do
    belongs_to :parent, __MODULE__, public?: true
    has_many :children, __MODULE__, destination_attribute: :parent_id, public?: true
  end
end

# its page
view :read do
  type :list
  primary? true
  parent_field :parent
  field :name
  field :kind
  field :capacity_liters, label: "Capacity (L)"
end
```

<!-- tabs-close -->

The page reads the staff with `:list` only, and names no write action, so
its card is view mode only. `:autocomplete` is a read action of the brewer
combobox of the batches page: this page excludes it.

[↑ View types](#view-types)

## The render view

A `:render` view is the escape hatch: a view that the DSL does not
describe (a chart, a map, a floor plan of the tanks). The renderer renders
the `render` entity of the view, one for each renderer.

| Option | Required | The UI |
|---|---|---|
| `render` | yes | The implementation for each renderer: `render PyroManiac.LiveView, BreweryWeb.RecipeLive.StyleChart`. A `:render` view without one is a compile error. The view has no record, so its `render` is not a text or an expression. |
| `loads` | no | The load statement of the records that the component gets. |
| `label`, `description`, `read_action`, `default_sort`, `pagination`, ... | no | As each list view. |

The component gets the records, the state of the list and a way to change
it, the actor, and the page. The renderer shows the filter bar and the
toolbar actions above it. Refer to [Custom renders](custom-renders.md) for
the implementations and their checks.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 244" role="img" aria-labelledby="dg-rv-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-rv-t">The view tabs of the recipes page, with the Styles tab open: a custom chart of the recipes by style</title>
<rect class="dg-p" x="10" y="10" width="980" height="224" rx="8"/>
<text class="dg-tab" x="26" y="40">All recipes</text><text class="dg-tab" x="120" y="40">Grid</text><text class="dg-st" x="170" y="40">Styles</text>
<line class="dg-g" x1="22" y1="48" x2="978" y2="48"/><line class="dg-on" x1="170" y1="48" x2="214" y2="48"/>
<rect class="dg-tb" x="260" y="28" width="180" height="16" rx="3"/><text class="dg-t" x="265" y="40">view :read · type :render</text>
<rect class="dg-c" x="22" y="60" width="956" height="162" rx="6"/>
<rect class="dg-tb" x="30" y="66" width="440" height="16" rx="3"/><text class="dg-t" x="35" y="78">render PyroManiac.LiveView, BreweryWeb.RecipeLive.StyleChart</text>
<rect class="dg-bar" x="110" y="96" width="300" height="14"/><text class="dg-l" x="30" y="107">IPA</text><text class="dg-l" x="416" y="107">3 recipes, 21 batches</text>
<rect class="dg-bar" x="110" y="116" width="100" height="14"/><text class="dg-l" x="30" y="127">Stout</text><text class="dg-l" x="216" y="127">1</text>
<rect class="dg-bar" x="110" y="136" width="100" height="14"/><text class="dg-l" x="30" y="147">Lager</text><text class="dg-l" x="216" y="147">1</text>
<rect class="dg-bar" x="110" y="156" width="100" height="14"/><text class="dg-l" x="30" y="167">Wheat</text><text class="dg-l" x="216" y="167">1</text>
<rect class="dg-bar" x="110" y="176" width="100" height="14"/><text class="dg-l" x="30" y="187">Porter</text><text class="dg-l" x="216" y="187">1</text>
<rect class="dg-bar" x="110" y="196" width="200" height="14"/><text class="dg-l" x="30" y="207">Pale Ale</text><text class="dg-l" x="316" y="207">2</text>
</svg>
<figcaption>The list views of a page are tabs. <b>Styles</b> is a <code>:render</code> view: the component of the renderer draws it from the loaded records.</figcaption>
</figure>

### DSL

```elixir
view :read do
  type :render
  label "Styles"
  loads [:style, :status, :batch_count]
  render PyroManiac.LiveView, BreweryWeb.RecipeLive.StyleChart
  render PyroManiac.Solid, "~/recipes/StyleChart"
end
```

<!-- tabs-close -->

[↑ View types](#view-types)

## Actions

`action name, state` (one name or a list) in a view names a write action
of the resource: create, update, destroy, or a generic action. Its tree is
the form of the action. A read action is the name of a view, not an
`action`. The `state` is required ([Unsaved changes](#unsaved-changes-guard-and-recovery)):
the second argument (`action :update, :guard`) or an option in the block
(`state :guard`).

| Topic | For | Key DSL |
|---|---|---|
| [Unsaved changes](#unsaved-changes-guard-and-recovery) | What happens to the unsaved inputs of a form. | `state :guard`, `:recover`, `:discard` |
| [Confirmations](#confirmations) | A question before an action runs. Only when the DSL asks. | `confirm`, `confirm false` |
| [The tree of a card](#the-tree-of-a-card) | One record tree: view mode and the forms of the card. | `action [:create, :update]`, `only` |
| [Actions of a list view](#actions-of-a-list-view) | Toolbar and row buttons. | `action` with nodes, `delegate_to` |
| [Own trees and other resources](#own-trees-and-other-resources) | A form of another resource from a row. | `resource`, `set`, `overridable?` |
| [Steps](#steps) | A form in steps, a wizard. | `step`, `review?`, `visible?` |
| [Inline edits](#inline-edits) | Edit a cell, or some cells of a row together. | `column ... action`, `edit_columns` |
| [Bulk actions](#bulk-actions) | One form for the selected records. | `bulk_action`, `set_all_fields?` |
| [Clone](#clone) | The create form, filled from a record. | `clone?` |
| [New rows](#new-rows) | An inline new row at the top of a table. | `new_row?` |
| [Reorder](#reorder) | The order of the records by hand. | `reorder?`, `PyroManiac.Ordering` |
| [Extra actions](#extra-actions) | Custom buttons of the page, a row, or a card. | `extra_action`, `render` |

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
| `confirm` | A confirmation before the action runs: a text, an expression of the record that gives the message or `nil`, or `false` (none) ([Confirmations](#confirmations)). Required for an action without inputs. |
| `label` | The button and the title of the form (default: the humanized name). Two actions of a view have different labels. |
| `description` | An entity: the text below the title (a text, an expression of the record, or an implementation for one renderer). `description :inherit` takes the description of the action. None by default. |
| `presentation` | Where an own tree opens: `:modal` (the default), `:drawer`, or `:page`. |
| `width` | The width of its modal or drawer: `:record` (the default), `:form`, `:prose`, or `:full`. |
| `step_orientation` | The stepper of a form in steps: `:horizontal` or `:vertical`; without it, the one of the view ([Steps](#steps)). |
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

## Unsaved changes: guard and recovery

Each `action`, `bulk_action`, inline edit (the `action` of a column), and
`edit_columns` has a required `state`, with no default:

| `state` | What the user gets |
|---|---|
| `:guard` | A warning before they leave a form with unsaved changes: "Discard the changes to B-2026-043?", with **Keep editing** and **Discard**. |
| `:recover` | The inputs stay: after a reload or a lost connection the form opens again with them, and a notice "Unsaved changes restored" (with **Discard**). |
| `:discard` | Neither: the inputs go when the form closes. |

Use `:guard` for a long form, `:recover` for a form that takes time to
fill (the measurements of a batch), and `:discard` for a status change or
an inline edit. A password and the files of an upload are never kept. A
dirty `:guard` cell warns when the user leaves the row or the page; Escape
on a cell cancels without a warning.

```elixir
# in a card
action [:create, :update], :guard

# in a list view
action :complete, :recover do
  # the tree: refer to Actions of a list view
end

action :start_brewing do
  state :discard
end

bulk_action :advance_status, :guard do
  select :status
end

column :status do
  action :update, :discard do
    select :status
  end
end

edit_columns :update, [:target_og, :target_fg], :discard do
  field :target_og
  field :target_fg
end
```

[↑ Actions](#actions)

## Confirmations

An action never asks on its own: every confirmation is in the DSL. A
renderer never adds one, and has no default message.

- **No inputs.** An action of a view (a row, the toolbar, a card; not an
  inline edit of a column) or a bulk action without an input in its tree
  runs from its button. It must set `confirm`: a message, an expression,
  or `confirm false` (no confirmation). Without it the page does not
  compile: "action :start_brewing has no input, so its button runs it at
  once". Some buttons need no question (a status change that is easy to
  undo): `confirm false` says so.
- **`confirm`.** An action or a bulk action with `confirm` asks before it
  runs: an action without inputs, when its button is pressed; a form, on
  submit, after the form is valid in the client.

| `confirm` | The message |
|---|---|
| none | No confirmation for a form. A compile error for an action without inputs. |
| `false` | No confirmation: the action runs at once. |
| `"text"` | The text. |
| `expr(...)` | The value of the expression on the record (and `^arg(:name)` for the inputs of the form). `nil`: no confirmation, the action runs at once. |

The dialog has **Cancel** and a button with the label of the action (red
for a destroy).

```elixir
action :destroy, :discard do
  confirm "Delete the batch? Its tests are deleted too."
end

action :complete, :guard do
  confirm expr(if test_count == 0, do: "The batch has no quality test. Complete anyway?")
  field :actual_og, autofocus: true
  field :actual_fg
  field :actual_abv
  field :volume_liters
  field :package_date
end
```

[↑ Actions](#actions)

## The tree of a card

A card without action nodes is the form of each write action that it
names. `only` gives the differences: the read action of the view is view
mode.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 330" role="img" aria-labelledby="dg-ctree-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-ctree-t">One record tree of a recipe in three actions: view mode, the create form, and the update form</title>
<rect class="dg-p" x="10" y="10" width="316" height="310" rx="8"/>
<rect class="dg-tb" x="20" y="2" width="116" height="16" rx="3"/><text class="dg-t" x="25" y="14">:read · view mode</text>
<text class="dg-h" x="26" y="44">Hazy Daze IPA</text>
<rect class="dg-b" x="262" y="28" width="48" height="24" rx="4"/><text class="dg-bt" x="274" y="44">Edit</text>
<rect class="dg-s" x="22" y="60" width="292" height="128" rx="6"/>
<text class="dg-st" x="34" y="80">Recipe</text>
<text class="dg-l" x="34" y="100">Name</text><text class="dg-v" x="34" y="116">Hazy Daze IPA</text>
<text class="dg-l" x="180" y="100">Style</text><text class="dg-v" x="180" y="116">IPA</text>
<text class="dg-l" x="34" y="140">Status</text><rect class="dg-ok" x="34" y="145" width="52" height="18" rx="9"/><text class="dg-okt" x="45" y="158">Active</text>
<text class="dg-l" x="130" y="140">Batches</text><text class="dg-v" x="130" y="158">12</text>
<rect class="dg-tb" x="200" y="146" width="96" height="16" rx="3"/><text class="dg-t" x="205" y="158">only: [:read]</text>
<rect class="dg-s" x="22" y="200" width="292" height="70" rx="6"/>
<text class="dg-st" x="34" y="220">Targets</text>
<text class="dg-l" x="34" y="240">Target ABV</text><text class="dg-v" x="34" y="256">6.8 %</text>
<text class="dg-l" x="130" y="240">Target OG</text><text class="dg-v" x="130" y="256">1.064</text>
<text class="dg-l" x="226" y="240">Target FG</text><text class="dg-v" x="226" y="256">1.012</text>
<text class="dg-l" x="26" y="300">No description: it is in the forms only.</text>
<rect class="dg-p" x="342" y="10" width="316" height="310" rx="8"/>
<rect class="dg-tb" x="352" y="2" width="98" height="16" rx="3"/><text class="dg-t" x="357" y="14">action :create</text>
<text class="dg-h" x="358" y="44">New recipe</text><text class="dg-h" x="636" y="44">×</text>
<rect class="dg-s" x="354" y="60" width="292" height="128" rx="6"/>
<text class="dg-st" x="366" y="80">Recipe</text>
<text class="dg-l" x="366" y="98">Name *</text><rect class="dg-i" x="366" y="102" width="130" height="22" rx="3"/><rect class="dg-foc" x="365" y="101" width="132" height="24" rx="4"/>
<text class="dg-l" x="508" y="98">Style *</text><rect class="dg-i" x="508" y="102" width="126" height="22" rx="3"/><text class="dg-f" x="514" y="118">Select…</text><text class="dg-v" x="620" y="118">▾</text>
<text class="dg-l" x="366" y="140">Status *</text><rect class="dg-i" x="366" y="144" width="130" height="22" rx="3"/><text class="dg-v" x="372" y="160">Draft</text><text class="dg-v" x="482" y="160">▾</text>
<rect class="dg-tb" x="508" y="140" width="112" height="16" rx="3"/><text class="dg-t" x="513" y="152">only: [:create]</text>
<text class="dg-l" x="508" y="176">options: Draft, Active</text>
<rect class="dg-s" x="354" y="200" width="292" height="84" rx="6"/>
<text class="dg-st" x="366" y="218">Targets</text>
<rect class="dg-i" x="366" y="226" width="84" height="20" rx="3"/><text class="dg-f" x="372" y="241">ABV</text>
<rect class="dg-i" x="458" y="226" width="84" height="20" rx="3"/><text class="dg-f" x="464" y="241">OG</text>
<rect class="dg-i" x="550" y="226" width="84" height="20" rx="3"/><text class="dg-f" x="556" y="241">FG</text>
<rect class="dg-i" x="366" y="252" width="268" height="24" rx="3"/><text class="dg-f" x="372" y="268">Description</text>
<rect class="dg-pri" x="584" y="290" width="62" height="24" rx="4"/><text class="dg-bw" x="596" y="306">Create</text>
<rect class="dg-p" x="674" y="10" width="316" height="310" rx="8"/>
<rect class="dg-tb" x="684" y="2" width="142" height="16" rx="3"/><text class="dg-t" x="689" y="14">action :update · Edit</text>
<text class="dg-h" x="690" y="44">Hazy Daze IPA</text>
<rect class="dg-s" x="686" y="60" width="292" height="128" rx="6"/>
<text class="dg-st" x="698" y="80">Recipe</text>
<text class="dg-l" x="698" y="98">Name *</text><rect class="dg-i" x="698" y="102" width="130" height="22" rx="3"/><text class="dg-v" x="704" y="118">Hazy Daze IPA</text><rect class="dg-foc" x="697" y="101" width="132" height="24" rx="4"/>
<text class="dg-l" x="840" y="98">Style *</text><rect class="dg-i" x="840" y="102" width="126" height="22" rx="3"/><text class="dg-v" x="846" y="118">IPA</text><text class="dg-v" x="952" y="118">▾</text>
<text class="dg-l" x="698" y="140">Status *</text><rect class="dg-i" x="698" y="144" width="130" height="22" rx="3"/><text class="dg-v" x="704" y="160">Active</text><text class="dg-v" x="814" y="160">▾</text>
<rect class="dg-tb" x="836" y="140" width="148" height="16" rx="3"/><text class="dg-t" x="841" y="152">only: [:read, :update]</text>
<text class="dg-l" x="840" y="176">Draft, Active, Retired</text>
<rect class="dg-s" x="686" y="200" width="292" height="84" rx="6"/>
<text class="dg-st" x="698" y="218">Targets</text>
<rect class="dg-i" x="698" y="226" width="84" height="20" rx="3"/><text class="dg-v" x="704" y="241">6.8</text>
<rect class="dg-i" x="790" y="226" width="84" height="20" rx="3"/><text class="dg-v" x="796" y="241">1.064</text>
<rect class="dg-i" x="882" y="226" width="84" height="20" rx="3"/><text class="dg-v" x="888" y="241">1.012</text>
<rect class="dg-i" x="698" y="252" width="268" height="24" rx="3"/><text class="dg-v" x="704" y="268">Juicy and soft. Citra and Mosaic…</text>
<rect class="dg-b" x="842" y="290" width="64" height="24" rx="4"/><text class="dg-bt" x="853" y="306">Cancel</text>
<rect class="dg-pri" x="912" y="290" width="54" height="24" rx="4"/><text class="dg-bw" x="925" y="306">Save</text>
</svg>
<figcaption>One tree, three actions. View mode (the read action) shows the batch count. The create form has a status select with two options; the update form has the select with all three. The description is in the forms only. No second tree.</figcaption>
</figure>

### DSL

```elixir
view :read do
  type :card
  primary? true
  action [:create, :update], :guard

  section :recipe do
    field :name, autofocus: true
    select :style
    select :status, only: [:read, :update]
    select :status, only: [:create], options: [{"Draft", :draft}, {"Active", :active}]
    field :batch_count, label: "Batches", only: [:read]
  end

  section :targets do
    row do
      field :target_abv
      field :target_og
      field :target_fg
    end

    field :description, type: :textarea, only: [:create, :update]
  end
end
```

<!-- tabs-close -->

- `batch_count` is an aggregate: a value, not an input. In the forms it is
  read-only (here, `only` removes it).
- The status shows once in each action: a value is once in the tree of an
  action, after `only`.

[↑ Actions](#actions)

## Actions of a list view

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

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 300" role="img" aria-labelledby="dg-lact-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-lact-t">The actions of the batches table: a toolbar create, row buttons, the confirm of a delete, and the complete form in a drawer</title>
<rect class="dg-p" x="10" y="10" width="600" height="280" rx="8"/>
<text class="dg-h" x="26" y="42">Batches</text>
<rect class="dg-tb" x="288" y="29" width="190" height="16" rx="3"/><text class="dg-t" x="293" y="41">action :create · delegate_to</text>
<rect class="dg-pri" x="484" y="24" width="112" height="26" rx="4"/><text class="dg-bw" x="504" y="41">+ New batch</text>
<text class="dg-l" x="26" y="76">Batch</text><text class="dg-l" x="120" y="76">Recipe</text><text class="dg-l" x="250" y="76">Status</text>
<line class="dg-g" x1="22" y1="82" x2="598" y2="82"/>
<text class="dg-v" x="26" y="102">B-2026-047</text><text class="dg-a" x="120" y="102">Hazy Daze IPA</text><text class="dg-v" x="250" y="102">Planned</text>
<rect class="dg-b" x="356" y="88" width="90" height="20" rx="4"/><text class="dg-bt" x="364" y="102">Start brewing</text>
<rect class="dg-b" x="452" y="88" width="66" height="20" rx="4"/><text class="dg-bt" x="460" y="102">Complete</text>
<rect class="dg-b" x="524" y="88" width="58" height="20" rx="4"/><text class="dg-bt" x="534" y="102">Delete</text>
<text class="dg-v" x="26" y="130">B-2026-043</text><text class="dg-a" x="120" y="130">Midnight Stout</text><text class="dg-v" x="250" y="130">Conditioning</text>
<rect class="dg-b" x="356" y="116" width="90" height="20" rx="4"/><text class="dg-bt" x="364" y="130">Start brewing</text>
<rect class="dg-b" x="452" y="116" width="66" height="20" rx="4"/><text class="dg-bt" x="460" y="130">Complete</text><rect class="dg-foc" x="451" y="115" width="68" height="22" rx="5"/>
<rect class="dg-b" x="524" y="116" width="58" height="20" rx="4"/><text class="dg-bt" x="534" y="130">Delete</text>
<text class="dg-v" x="26" y="158">B-2026-041</text><text class="dg-a" x="120" y="158">Cherry Sour</text><text class="dg-v" x="250" y="158">Cancelled</text>
<rect class="dg-b" x="356" y="144" width="90" height="20" rx="4"/><text class="dg-bt" x="364" y="158">Start brewing</text>
<rect class="dg-b" x="452" y="144" width="66" height="20" rx="4"/><text class="dg-bt" x="460" y="158">Complete</text>
<rect class="dg-b" x="524" y="144" width="58" height="20" rx="4"/><text class="dg-bt" x="534" y="158">Delete</text><rect class="dg-foc" x="523" y="143" width="60" height="22" rx="5"/>
<rect class="dg-tb" x="330" y="172" width="142" height="16" rx="3"/><text class="dg-t" x="335" y="184">action :start_brewing</text>
<rect class="dg-tb" x="480" y="172" width="104" height="16" rx="3"/><text class="dg-t" x="485" y="184">action :destroy</text>
<rect class="dg-m" x="120" y="196" width="380" height="84" rx="8"/>
<text class="dg-st" x="136" y="220">Delete B-2026-041?</text>
<text class="dg-l" x="136" y="238">No inputs: its confirm, not a form.</text>
<rect class="dg-b" x="340" y="248" width="64" height="24" rx="4"/><text class="dg-bt" x="351" y="264">Cancel</text>
<rect x="412" y="248" width="76" height="24" rx="4" fill="#dc2626"/><text class="dg-bw" x="429" y="264">Delete</text>
<rect class="dg-p" x="630" y="10" width="360" height="280" rx="8"/>
<g opacity=".3"><text class="dg-st" x="646" y="40">Batches</text>
<text class="dg-v" x="646" y="72">B-2026-047</text><text class="dg-v" x="646" y="96">B-2026-043</text><text class="dg-v" x="646" y="120">B-2026-041</text>
</g>
<rect class="dg-m" x="740" y="22" width="242" height="260" rx="6"/>
<rect class="dg-tb" x="640" y="2" width="258" height="16" rx="3"/><text class="dg-t" x="645" y="14">action :complete · presentation :drawer</text>
<text class="dg-st" x="752" y="44">Complete B-2026-043</text>
<text class="dg-l" x="752" y="62">The final measurements of the batch.</text>
<text class="dg-l" x="752" y="84">OG</text><rect class="dg-i" x="752" y="88" width="106" height="22" rx="3"/><text class="dg-v" x="758" y="104">1.072</text><rect class="dg-foc" x="751" y="87" width="108" height="24" rx="4"/>
<text class="dg-l" x="866" y="84">FG</text><rect class="dg-i" x="866" y="88" width="106" height="22" rx="3"/><text class="dg-v" x="872" y="104">1.018</text>
<text class="dg-l" x="752" y="126">ABV</text><rect class="dg-i" x="752" y="130" width="106" height="22" rx="3"/><text class="dg-v" x="758" y="146">7.1</text>
<text class="dg-l" x="866" y="126">Volume (L)</text><rect class="dg-i" x="866" y="130" width="106" height="22" rx="3"/><text class="dg-v" x="872" y="146">1180</text>
<text class="dg-l" x="752" y="168">Package date</text><rect class="dg-i" x="752" y="172" width="220" height="22" rx="3"/><text class="dg-v" x="758" y="188">2026-11-30</text>
<rect class="dg-tb" x="752" y="206" width="96" height="16" rx="3"/><text class="dg-t" x="757" y="218">max_columns 2</text>
<rect class="dg-pri" x="916" y="246" width="56" height="26" rx="4"/><text class="dg-bw" x="929" y="263">Save</text>
</svg>
<figcaption>The actions of the batches table. <b>+ New batch</b> opens the create form of the card. <b>Start brewing</b> and <b>Delete</b> have no inputs: Delete asks with its <code>confirm</code>, Start brewing runs at once (<code>confirm false</code>). <b>Complete</b> has its own tree, in a drawer.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive
view :read do
  type :data_table
  primary? true
  # the columns: refer to Data tables

  action :create, :guard do
    delegate_to BreweryWeb.BatchLive
  end

  # No inputs: `confirm` is required (a message, or `false`).
  action :start_brewing, :discard do
    confirm false
  end

  action :destroy, :discard do
    confirm "Delete the batch?"
  end

  action :complete, :recover do
    description "The final measurements of the batch."
    presentation :drawer
    max_columns 2
    field :actual_og, label: "OG", autofocus: true
    field :actual_fg, label: "FG"
    field :actual_abv, label: "ABV"
    field :volume_liters, label: "Volume (L)"
    field :package_date
  end
end
```

<!-- tabs-close -->

[↑ Actions](#actions)

## Own trees and other resources

An action with nodes has its own tree, in any view. With `resource`, it is
an action of another resource; `set` fills a value from the record of the
row, with no input. A create on another resource is a row button.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 340" role="img" aria-labelledby="dg-form-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-form-t">The create form of the recipes toolbar in two columns, and the form of a new quality test from the row of a batch</title>
<rect class="dg-p" x="10" y="10" width="470" height="320" rx="8"/>
<rect class="dg-tb" x="20" y="2" width="270" height="16" rx="3"/><text class="dg-t" x="25" y="14">action :create · label · max_columns 2</text>
<text class="dg-h" x="26" y="44">New recipe</text><text class="dg-h" x="454" y="44">×</text>
<text class="dg-l" x="26" y="62">Draft a new recipe.</text>
<text class="dg-l" x="26" y="88">Name *</text><rect class="dg-i" x="26" y="92" width="210" height="24" rx="3"/><rect class="dg-foc" x="25" y="91" width="212" height="26" rx="4"/>
<text class="dg-l" x="252" y="88">Style *</text><rect class="dg-i" x="252" y="92" width="210" height="24" rx="3"/><text class="dg-f" x="258" y="109">Select…</text><text class="dg-v" x="446" y="109">▾</text>
<text class="dg-l" x="26" y="138">Target ABV</text><rect class="dg-i" x="26" y="142" width="210" height="24" rx="3"/>
<text class="dg-l" x="252" y="138">Status *</text><rect class="dg-i" x="252" y="142" width="210" height="24" rx="3"/><text class="dg-v" x="258" y="159">Draft</text><text class="dg-v" x="446" y="159">▾</text>
<text class="dg-l" x="26" y="188">Target OG</text><rect class="dg-i" x="26" y="192" width="210" height="24" rx="3"/>
<text class="dg-l" x="252" y="188">Target FG</text><rect class="dg-i" x="252" y="192" width="210" height="24" rx="3"/>
<text class="dg-l" x="26" y="238">Description</text><rect class="dg-i" x="26" y="242" width="436" height="40" rx="3"/>
<rect class="dg-b" x="338" y="294" width="64" height="26" rx="4"/><text class="dg-bt" x="349" y="311">Cancel</text>
<rect class="dg-pri" x="408" y="294" width="54" height="26" rx="4"/><text class="dg-bw" x="418" y="311">Create</text>
<rect class="dg-p" x="520" y="10" width="470" height="320" rx="8"/>
<g opacity=".3"><text class="dg-st" x="536" y="40">Batches</text><text class="dg-v" x="536" y="66">B-2026-044</text><text class="dg-v" x="536" y="90">B-2026-043</text></g>
<rect class="dg-b" x="880" y="76" width="90" height="20" rx="4"/><text class="dg-bt" x="892" y="90">Record test</text>
<rect class="dg-m" x="540" y="104" width="430" height="216" rx="8"/>
<rect class="dg-tb" x="550" y="96" width="290" height="16" rx="3"/><text class="dg-t" x="555" y="108">action :create · resource Brewery.QualityTest</text>
<text class="dg-h" x="556" y="134">Record test</text>
<text class="dg-l" x="556" y="156">Batch</text><text class="dg-v" x="600" y="156">B-2026-043</text>
<rect class="dg-tb" x="700" y="145" width="130" height="16" rx="3"/><text class="dg-t" x="705" y="157">set :batch_id, :id</text>
<text class="dg-l" x="556" y="180">Test type *</text><rect class="dg-i" x="556" y="184" width="196" height="22" rx="3"/><text class="dg-v" x="562" y="200">pH</text><text class="dg-v" x="738" y="200">▾</text><rect class="dg-foc" x="555" y="183" width="198" height="24" rx="4"/>
<text class="dg-l" x="764" y="180">Tested at *</text><rect class="dg-i" x="764" y="184" width="190" height="22" rx="3"/><text class="dg-v" x="770" y="200">2026-11-14 09:30</text>
<text class="dg-l" x="556" y="224">Result *</text><rect class="dg-i" x="556" y="228" width="196" height="22" rx="3"/><text class="dg-v" x="562" y="244">4.3</text>
<text class="dg-l" x="764" y="224">Tester</text><rect class="dg-i" x="764" y="228" width="190" height="22" rx="3"/><text class="dg-v" x="770" y="244">Chloe Park</text><text class="dg-v" x="940" y="244">⌕</text>
<rect class="dg-i" x="556" y="262" width="12" height="12" rx="2"/><text class="dg-v" x="576" y="273">Passed</text>
<text class="dg-l" x="640" y="273">Notes: a textarea below</text>
<rect class="dg-pri" x="896" y="286" width="58" height="24" rx="4"/><text class="dg-bw" x="905" y="302">Create</text>
</svg>
<figcaption>Left: the create form of the recipes toolbar, in two columns. Right: an action of another resource, a new quality test from the row of a batch. The batch comes from the row: it has no input.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.RecipeLive, the table
action :create, :recover do
  label "New recipe"
  max_columns 2
  field :name, autofocus: true
  select :style
  field :target_abv
  select :status
  field :target_og
  field :target_fg
  field :description, type: :textarea
end

# BreweryWeb.BatchLive, the table
action :create, :guard do
  resource Brewery.QualityTest
  label "Record test"
  set :batch_id, :id
  select :test_type, autofocus: true
  field :tested_at
  field :result
  combobox :tester_id
  field :passed
  field :notes, type: :textarea
end
```

<!-- tabs-close -->

The same form, with the tree of the quality tests page:

```elixir
action :create, :guard do
  resource Brewery.QualityTest
  set :batch_id, :id
  delegate_to BreweryWeb.QualityTestLive
end
```

With `overridable? true`, a `set` is a default, not a fixed value: the
renderer fills the input of `name` with the value `source` of the record
when the form opens, and the user can change it. The input shows and
submits as any input. Without it, the value is added to the params on
submit, and no input shows it.

```elixir
# the batch of the row is the first value; the user can select another one
action :create, :guard do
  resource Brewery.QualityTest
  set :batch_id, :id, overridable?: true
  combobox :batch_id
  select :test_type, autofocus: true
  field :tested_at
  field :result
  combobox :tester_id
  field :passed
  field :notes, type: :textarea
end
```

[↑ Actions](#actions)

## Steps

`step :name` divides a tree into steps: in a form one step at a time, with
**Back** and **Next**; in view mode each step is a section. A step has
`label`, `description`, `path` (its inputs are in the nested form of the
path), `density`, `max_columns`, `visible?` (a step that the form skips),
and `render`. `review? true` makes a read-only summary of the steps before
it (the last step only). A tree has steps or other nodes at the top level,
not both.

The stepper is a row above the form (`step_orientation :horizontal`, the
default) or a column at its side (`step_orientation :vertical`). Set it on
the view for all its forms, or on an `action` for its form only; on a form
without steps it is a compile error.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 258" role="img" aria-labelledby="dg-step-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-step-t">A wizard for a new batch: the schedule step, and the review step with a summary of the steps before it</title>
<rect class="dg-p" x="10" y="10" width="470" height="238" rx="8"/>
<text class="dg-h" x="26" y="40">New batch</text>
<circle class="dg-ok" cx="36" cy="66" r="10"/><text class="dg-okt" x="32" y="70">✓</text><text class="dg-v" x="52" y="70">Recipe</text>
<line class="dg-g" x1="104" y1="66" x2="136" y2="66"/>
<circle cx="150" cy="66" r="10" class="dg-pri"/><text class="dg-bw" x="146" y="70">2</text><text class="dg-st" x="166" y="70">Schedule</text>
<line class="dg-g" x1="234" y1="66" x2="266" y2="66"/>
<circle cx="280" cy="66" r="10" class="dg-b"/><text class="dg-bt" x="276" y="70">3</text><text class="dg-tab" x="296" y="70">Review</text>
<rect class="dg-tb" x="340" y="58" width="130" height="16" rx="3"/><text class="dg-t" x="345" y="70">step :measurements</text>
<text class="dg-l" x="346" y="88">skipped: visible?</text>
<rect class="dg-tb" x="26" y="96" width="240" height="16" rx="3"/><text class="dg-t" x="31" y="108">step :schedule · density · max_columns 2</text>
<text class="dg-l" x="26" y="132">Brew date</text><rect class="dg-i" x="26" y="136" width="210" height="22" rx="3"/><text class="dg-v" x="32" y="152">2026-11-30</text>
<text class="dg-l" x="252" y="132">Brewer</text><rect class="dg-i" x="252" y="136" width="210" height="22" rx="3"/><text class="dg-v" x="258" y="152">Ana Ruiz</text><text class="dg-v" x="446" y="152">⌕</text>
<text class="dg-l" x="26" y="176">Volume (L)</text><rect class="dg-i" x="26" y="180" width="210" height="22" rx="3"/><text class="dg-v" x="32" y="196">1200</text>
<rect class="dg-b" x="338" y="212" width="58" height="26" rx="4"/><text class="dg-bt" x="350" y="229">Back</text>
<rect class="dg-pri" x="402" y="212" width="60" height="26" rx="4"/><text class="dg-bw" x="414" y="229">Next</text>
<rect class="dg-p" x="520" y="10" width="470" height="238" rx="8"/>
<text class="dg-h" x="536" y="40">New batch</text>
<circle class="dg-ok" cx="546" cy="66" r="10"/><text class="dg-okt" x="542" y="70">✓</text><text class="dg-v" x="562" y="70">Recipe</text>
<line class="dg-g" x1="614" y1="66" x2="646" y2="66"/>
<circle class="dg-ok" cx="660" cy="66" r="10"/><text class="dg-okt" x="656" y="70">✓</text><text class="dg-v" x="676" y="70">Schedule</text>
<line class="dg-g" x1="744" y1="66" x2="776" y2="66"/>
<circle cx="790" cy="66" r="10" class="dg-pri"/><text class="dg-bw" x="786" y="70">3</text><text class="dg-st" x="806" y="70">Review</text>
<rect class="dg-tb" x="536" y="96" width="160" height="16" rx="3"/><text class="dg-t" x="541" y="108">step :review · review? true</text>
<text class="dg-st" x="536" y="134">Recipe</text><text class="dg-a" x="900" y="134">Change</text>
<text class="dg-l" x="536" y="152">Recipe</text><text class="dg-v" x="640" y="152">Hazy Daze IPA</text><text class="dg-l" x="780" y="152">Batch no.</text><text class="dg-v" x="840" y="152">B-2026-049</text>
<text class="dg-st" x="536" y="180">Schedule</text><text class="dg-a" x="900" y="180">Change</text>
<text class="dg-l" x="536" y="198">Brew date</text><text class="dg-v" x="640" y="198">2026-11-30</text><text class="dg-l" x="780" y="198">Brewer</text><text class="dg-v" x="840" y="198">Ana Ruiz</text>
<rect class="dg-b" x="842" y="212" width="58" height="26" rx="4"/><text class="dg-bt" x="854" y="229">Back</text>
<rect class="dg-pri" x="906" y="212" width="66" height="26" rx="4"/><text class="dg-bw" x="916" y="229">Create</text>
</svg>
<figcaption>A wizard. The measurements step shows only for a batch that is already complete. The review step is a read-only summary, with a link back to each step.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive, the table
action :create, :recover do
  step :recipe do
    combobox :recipe_id, autofocus: true
    field :batch_number
    select :status
  end

  step :schedule do
    label "Schedule"
    density :dense
    max_columns 2
    field :brew_date
    combobox :brewer_id
    field :volume_liters, label: "Volume (L)"
    field :notes, type: :textarea
  end

  step :measurements do
    description "The measurements of a batch that is already complete."
    visible? expr(status == :complete)
    field :actual_og
    field :actual_fg
    field :actual_abv
    field :package_date
  end

  step :review do
    review? true
  end
end
```

<!-- tabs-close -->

[↑ Actions](#actions)

## Inline edits

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

A cell with an inline edit opens with a click, or with Enter or F2 when it
has the focus; Escape cancels.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 220" role="img" aria-labelledby="dg-inl-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-inl-t">Inline edits of the recipes table: the status cell as an open select, and the gravity cells of a row edited together</title>
<rect class="dg-p" x="10" y="10" width="480" height="200" rx="8"/>
<rect class="dg-tb" x="20" y="2" width="212" height="16" rx="3"/><text class="dg-t" x="25" y="14">column :status · action :update</text>
<text class="dg-l" x="26" y="44">Name</text><text class="dg-l" x="200" y="44">Style</text><text class="dg-l" x="320" y="44">Status</text>
<line class="dg-g" x1="22" y1="50" x2="478" y2="50"/>
<text class="dg-v" x="26" y="72">Copper Pale Ale</text><text class="dg-v" x="200" y="72">Pale Ale</text><text class="dg-v" x="320" y="72">Draft</text>
<text class="dg-v" x="26" y="100">Hazy Daze IPA</text><text class="dg-v" x="200" y="100">IPA</text>
<rect class="dg-i" x="316" y="86" width="120" height="22" rx="3"/><text class="dg-v" x="322" y="101">Active</text><text class="dg-v" x="422" y="101">▴</text><rect class="dg-foc" x="315" y="85" width="122" height="24" rx="4"/>
<rect class="dg-m" x="316" y="112" width="120" height="70" rx="4"/>
<text class="dg-v" x="326" y="128">Draft</text>
<rect class="dg-hl" x="317" y="134" width="118" height="20"/><text class="dg-v" x="326" y="149">Active ✓</text>
<text class="dg-v" x="326" y="172">Retired</text>
<text class="dg-v" x="26" y="128">Midnight Stout</text><text class="dg-v" x="200" y="128">Stout</text>
<text class="dg-l" x="26" y="198">A change saves the cell: the update of the row.</text>
<rect class="dg-p" x="510" y="10" width="480" height="200" rx="8"/>
<rect class="dg-tb" x="520" y="2" width="304" height="16" rx="3"/><text class="dg-t" x="525" y="14">edit_columns :update, [:target_og, :target_fg]</text>
<text class="dg-l" x="526" y="44">Name</text><text class="dg-l" x="700" y="44">Target OG</text><text class="dg-l" x="800" y="44">Target FG</text>
<line class="dg-g" x1="522" y1="50" x2="978" y2="50"/>
<text class="dg-v" x="526" y="72">Copper Pale Ale</text><text class="dg-v" x="700" y="72">1.052</text><text class="dg-v" x="800" y="72">1.010</text>
<text class="dg-v" x="526" y="100">Hazy Daze IPA</text>
<rect class="dg-i" x="696" y="86" width="90" height="22" rx="3"/><text class="dg-v" x="702" y="101">1.064</text><rect class="dg-foc" x="695" y="85" width="92" height="24" rx="4"/>
<rect class="dg-i" x="796" y="86" width="90" height="22" rx="3"/><text class="dg-v" x="802" y="101">1.012</text>
<rect class="dg-pri" x="900" y="86" width="26" height="22" rx="4"/><text class="dg-bw" x="908" y="101">✓</text>
<rect class="dg-b" x="932" y="86" width="26" height="22" rx="4"/><text class="dg-bt" x="941" y="101">×</text>
<text class="dg-v" x="526" y="128">Midnight Stout</text><text class="dg-v" x="700" y="128">1.072</text><text class="dg-v" x="800" y="128">1.018</text>
<text class="dg-l" x="526" y="176">The two cells switch to inputs together.</text>
<text class="dg-l" x="526" y="194">One save runs the update with both values.</text>
</svg>
<figcaption>Left: the status cell of a row as a select. Right: the target gravities of a row, edited together with one save.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.RecipeLive
view :read do
  type :data_table
  primary? true
  # ...
  column :name
  column :style

  column :status do
    action :update, :discard do
      select :status, autofocus: true
    end
  end

  column :target_og
  column :target_fg

  edit_columns :update, [:target_og, :target_fg], :discard do
    field :target_og, autofocus: true
    field :target_fg
  end
end
```

<!-- tabs-close -->

[↑ Actions](#actions)

## Bulk actions

`bulk_action :name, state` (one name or a list) is a form for the
selected rows of a list view: an update or a destroy action. It has the
required `state` ([Unsaved changes](#unsaved-changes-guard-and-recovery)),
`confirm` ([Confirmations](#confirmations)), `label` (the button),
`description` (an entity; `description :inherit` takes the description of
the action), `max_columns`, `delegate_to` (the bulk action of the same
name on another page), and inputs, `section`, `row`, `compound`, and
`step` (no `related`, no `attachments`, no identity field). Its `only`
names the bulk action. A bulk action without inputs is a button, and it
sets `confirm` (a message, or `confirm false`). With `set_all_fields? false` (the default) an empty input is
left out, so it does not change the records; `true` submits each input, as
a normal form. A bulk action uses its action: it needs no `exclude`
([Pages](pages.md)).

The bulk actions show when the user selects records (`selectable?`, the
default): "3 selected", and a button for each bulk action.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 290" role="img" aria-labelledby="dg-bulk-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-bulk-t">Three selected batches and the form of the Update bulk action</title>
<rect class="dg-p" x="10" y="10" width="980" height="270" rx="8"/>
<rect class="dg-hl" x="22" y="22" width="956" height="28" rx="4"/>
<text class="dg-st" x="34" y="41">3 selected</text>
<rect class="dg-pri" x="120" y="26" width="64" height="20" rx="4"/><text class="dg-bw" x="132" y="40">Update</text>
<rect class="dg-b" x="192" y="26" width="108" height="20" rx="4"/><text class="dg-bt" x="202" y="40">Advance status</text>
<rect class="dg-b" x="308" y="26" width="100" height="20" rx="4"/><text class="dg-bt" x="318" y="40">Start brewing</text>
<g opacity=".3">
<text class="dg-v" x="34" y="80">☑ B-2026-047  Hazy Daze IPA  Planned</text>
<text class="dg-v" x="34" y="104">☑ B-2026-046  Copper Pale Ale  Planned</text>
<text class="dg-v" x="34" y="128">☑ B-2026-045  Harbor Lager  Planned</text>
<text class="dg-v" x="34" y="152">☐ B-2026-044  Hazy Daze IPA  Fermenting</text>
</g>
<rect class="dg-m" x="420" y="62" width="420" height="208" rx="8"/>
<rect class="dg-tb" x="430" y="54" width="128" height="16" rx="3"/><text class="dg-t" x="435" y="66">bulk_action :update</text>
<text class="dg-h" x="436" y="92">Update · 3 batches</text><text class="dg-h" x="816" y="92">×</text>
<text class="dg-l" x="436" y="110">Change the selected batches.</text>
<text class="dg-l" x="436" y="134">Status</text><rect class="dg-i" x="436" y="138" width="180" height="22" rx="3"/><text class="dg-v" x="442" y="154">Brewing</text><text class="dg-v" x="602" y="154">▾</text>
<text class="dg-l" x="630" y="134">Brewer</text><rect class="dg-i" x="630" y="138" width="194" height="22" rx="3"/><text class="dg-v" x="810" y="154">⌕</text>
<text class="dg-l" x="436" y="178">Notes</text><rect class="dg-i" x="436" y="182" width="388" height="22" rx="3"/>
<text class="dg-l" x="436" y="222">An empty field does not change the batches.</text>
<rect class="dg-tb" x="436" y="232" width="160" height="16" rx="3"/><text class="dg-t" x="441" y="244">set_all_fields? false</text>
<rect class="dg-pri" x="736" y="236" width="88" height="24" rx="4"/><text class="dg-bw" x="746" y="252">Apply to 3</text>
</svg>
<figcaption>A bulk action on three batches. The brewer and the notes are empty, so they keep their values.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive, the table
bulk_action :update, :guard do
  label "Update"
  description "Change the selected batches."
  max_columns 2
  set_all_fields? false
  select :status, autofocus: true
  combobox :brewer_id
  field :notes, type: :textarea
end

bulk_action :advance_status, :guard do
  select :status
end

bulk_action :start_brewing do
  state :discard
  confirm "Start brewing the selected batches?"
end
```

<!-- tabs-close -->

[↑ Actions](#actions)

## Clone

`clone? true` on a view adds a **Clone** button to each record (a row of a
table, a card of a grid, an item of a list, a card). The view names a
create action (a compile error otherwise); with more than one, the first.

**Clone** opens the form of that create action (its tree, its
`presentation`, its `state`), filled from the record: each input whose
name is an attribute of the record gets its value. The primary key, the
fields that are not inputs of the create action, the files, and the
nested forms are not copied. A unique value (an identity) is copied as
is: the user changes it, or the submit shows the error on its input.

[↑ Actions](#actions)

## New rows

`new_row? true` on a `:data_table` adds an inline new row at the top of
the table. The view names a create action, and each required input of it
(an accepted attribute or a public argument with `allow_nil? false` and
no default) is the inline edit of a column: `column :name do action
:create, :discard do field :name end end` (a compile error otherwise).

The user opens the new row (**+ Add row**, or a click on it), fills its
cells, and saves with Enter (Escape cancels; Tab moves between the
inputs). The save runs the create action with all the values in one
submit; an error shows on its cell. The new record shows as a row, and the
new row is empty again for the next record.

```elixir
# BreweryWeb.RecipeLive
view :read do
  type :data_table
  primary? true
  new_row? true
  clone? true

  column :name do
    action :create, :discard do
      field :name
    end
  end

  column :style do
    action :create, :discard do
      select :style
    end
  end

  column :status

  action :create, :guard do
    delegate_to BreweryWeb.RecipeLive
  end
end
```

[↑ Actions](#actions)

## Reorder

`reorder? true` on a `:data_table`, `:grid`, or `:list` lets the user
order the records by hand. The resource has `PyroManiac.Ordering` (or
`PyroManiac.KanBan`) (a compile error otherwise): its rank attribute, its
`scope`, and its move action. The move action is a use of the page: it
needs no `action` and no `exclude`.

Reordering is on only when the list is sorted by the rank attribute
ascending, with no other sort (`default_sort "position"`), and, with a
`scope`, filtered to one value of the scope (a `related` list of the
recipe is scoped already). Otherwise the handles are disabled, with "Sort
by position to reorder" and a button that sets the sort. Each record has a
drag handle; with the keyboard, Space or Enter picks it up, the arrows
move it, Space or Enter drops it, Escape cancels.

```elixir
# the resource
defmodule Brewery.RecipeIngredient do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource, PyroManiac.Ordering]

  ordering do
    attribute :position
    scope :recipe_id
    move_action :move
  end
end

# the page
view :read do
  type :list
  reorder? true
  default_sort "position"
  field :ingredient
  field :quantity
end
```

[↑ Actions](#actions)

## Extra actions

`extra_action :name` (with a `label`) adds a custom action:

- in the `page` section: a button of the page toolbar;
- in a view: a button of each row of a data table, or of the card of a
  record.

`render` gives the whole action for a renderer: its button and its
content (a modal, a panel). The implementation gets the action, the base
path, the params, and (on a row) the record ([Custom
renders](custom-renders.md)). Without `render`, the renderer shows a link
button and a generic action.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 236" role="img" aria-labelledby="dg-xa-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-xa-t">The export action of the recipes page with its panel, and the print label action of a batch row</title>
<rect class="dg-p" x="10" y="10" width="560" height="216" rx="8"/>
<text class="dg-h" x="26" y="42">Recipes</text>
<rect class="dg-pri" x="460" y="24" width="96" height="28" rx="4"/><text class="dg-bw" x="485" y="42">Export ▾</text>
<rect class="dg-tb" x="320" y="30" width="134" height="16" rx="3"/><text class="dg-t" x="325" y="42">extra_action :export</text>
<rect class="dg-m" x="300" y="58" width="256" height="150" rx="6"/>
<text class="dg-st" x="314" y="82">Export recipes</text>
<circle cx="320" cy="104" r="5" fill="none" stroke="currentColor"/><circle cx="320" cy="104" r="2.5" fill="currentColor"/><text class="dg-v" x="332" y="108">CSV</text>
<circle cx="380" cy="104" r="5" fill="none" stroke="currentColor"/><text class="dg-v" x="392" y="108">PDF book</text>
<rect class="dg-i" x="314" y="120" width="12" height="12" rx="2"/><text class="dg-v" x="334" y="131">Only active recipes</text>
<rect class="dg-pri" x="470" y="170" width="72" height="26" rx="4"/><text class="dg-bw" x="481" y="187">Export</text>
<text class="dg-l" x="26" y="200">The render of the action: its button and its panel.</text>
<rect class="dg-p" x="590" y="10" width="400" height="216" rx="8"/>
<text class="dg-st" x="606" y="38">Batches</text>
<text class="dg-v" x="606" y="70">B-2026-044</text><text class="dg-a" x="700" y="70">Hazy Daze IPA</text>
<rect class="dg-b" x="890" y="56" width="84" height="22" rx="4"/><text class="dg-bt" x="900" y="71">Print label</text>
<text class="dg-v" x="606" y="98">B-2026-043</text><text class="dg-a" x="700" y="98">Midnight Stout</text>
<rect class="dg-b" x="890" y="84" width="84" height="22" rx="4"/><text class="dg-bt" x="900" y="99">Print label</text>
<rect class="dg-tb" x="606" y="118" width="172" height="16" rx="3"/><text class="dg-t" x="611" y="130">extra_action :print_label</text>
<text class="dg-l" x="606" y="160">On a row: the action gets the record.</text>
<text class="dg-l" x="606" y="178">Without render: a link button and a</text>
<text class="dg-l" x="606" y="194">generic action.</text>
</svg>
<figcaption>An extra action of the page, with its own panel, and an extra action on each row of a view.</figcaption>
</figure>

### DSL

```elixir
page do
  title "Recipes"
  route "/recipes"

  extra_action :export do
    label "Export"
    render PyroManiac.LiveView, BreweryWeb.RecipeLive.ExportAction
    render PyroManiac.Solid, "~/recipes/ExportAction"
  end
end

# BreweryWeb.BatchLive
view :read do
  type :data_table
  primary? true

  extra_action :print_label do
    label "Print label"
    render PyroManiac.LiveView, {BreweryWeb.BatchLive.PrintLabel, format: :keg}
  end
end
```

<!-- tabs-close -->

[↑ Actions](#actions)
