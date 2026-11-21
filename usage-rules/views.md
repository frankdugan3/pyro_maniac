# Views

The `views` section declares one or more views over the page's resource.
Each view is bound to a read action and renders records using a specific
view type.

```elixir
views do
  view :read do
    type :data_table
    column :name
    column :status
  end
end
```

## View types

| Type          | What it renders                                                      |
| ------------- | -------------------------------------------------------------------- |
| `:data_table` | Paginated, sortable, filterable table; uses `column` entities        |
| `:grid`       | Card grid; uses `field`, `section`, and `relationship` entities      |
| `:calendar`   | Calendar/timeline keyed on a date field                              |
| `:gantt`      | Gantt chart for scheduling data with start/end dates                 |
| `:kanban`     | Board with swimlanes grouped by an enum/atom field                   |
| `:list`       | Tree/outline list, optionally hierarchical via `parent_field`        |
| `:render`     | Escape hatch — custom render function or renderer-specific component |
| `:delegated`  | Mount a full sub-Viewer from another PyroManiac module               |

## View entity reference

`view :name do ... end` — `name` is one or more action names. Required for
all types except `:delegated`. May be a single atom (`view :read`) or a
list (`view [:read, :list]`).

Top-level schema (selected; see `PyroManiac.View.View` for the full set):

| Key                                        | Type                               | Notes                                                                        |
| ------------------------------------------ | ---------------------------------- | ---------------------------------------------------------------------------- |
| `type`                                     | atom (one of the view types above) | Required                                                                     |
| `resource`                                 | Ash resource module                | Defaults to the page's resource, or the relationship destination when nested |
| `relationship`                             | atom                               | When nested, traverse this relationship                                      |
| `read_action`                              | atom                               | Override which read action backs the view                                    |
| `default_sort`                             | sort spec (string or list)         | e.g. `"name"`, `"-batch_number"`                                             |
| `pagination`                               | pagination spec                    | Auto-detected from the action if not set                                     |
| `default_page_size`                        | `:pos_integer`                     | Falls back to action's `default_limit`, then 25                              |
| `page_sizes`                               | `[pos_integer]`                    | Available page-size options                                                  |
| `exclude`                                  | `[atom]`                           | Fields to exclude from the view                                              |
| `on_create`/`on_update`/`on_destroy`       | PubSub handler spec                | How to handle resource notifications                                         |
| `on_bulk`                                  | `:none`, `:reload`, `:notify`      | How to handle the single message of a bulk operation (needs `bulk`)          |
| `lazy?`                                    | boolean (default `true`)           | Load nested view data only when expanded                                     |
| `multiple?`                                | boolean (default `false`)          | Allow multiple rows expanded simultaneously                                  |
| `selectable?`                              | boolean (default `true`)           | Enable row selection (data_table only)                                       |

The DSL has no `class` options and no functions. A renderer maps the
meaning (`tone`, `size`) to its own styles, and a `render` option takes a
**render module**, which implements the render behaviour of the renderer.

Type-specific keys:

- `:data_table` — `default_display`, `selectable?`
- `:kanban` — `group_by`, `kanban_action`, `priority`
- `:calendar` — `date_field`, `end_date_field`, `granularity` (`:day`/`:week`/`:month`)
- `:gantt` — `start_field`, `end_field`, `progress_field`, `group_by`
- `:list` — `parent_field`
- `:render` — `render` (a render module), or `component`+`component_id_suffix`+`props`+`loads`
- `:delegated` — `delegate_to` (the sub-Viewer's PyroManiac module). Required for `:delegated`, forbidden otherwise.

## Nested views

Views are recursive (`recursive_as: :views`). Use this to drill into
relationships or mount cross-resource sub-views.

```elixir
view :read do
  type :data_table
  column :batch_number
  column :status

  view do
    type :delegated
    relationship :quality_tests
    delegate_to BreweryWeb.QualityTestLive
  end
end
```

## `column` (data_table only)

Columns are interactive — users sort, filter, hide, and reorder them.

```elixir
column :name
column :status do
  filterable? true
  tone expr(cond do
    status == :overdue -> :danger
    status == :due_soon -> :warning
    true -> nil
  end)
end
```

| Key                          | Default        | Notes                                                                 |
| ---------------------------- | -------------- | --------------------------------------------------------------------- |
| `name`                       | required       | Attribute, calculation, or aggregate                                  |
| `label`                      | humanized name | Header label                                                          |
| `description`                | nil            | Inheritable description text                                          |
| `source`                     | `[name]`       | Path; allows relationship traversal                                   |
| `type`                       | `:default`     | One of `:default`, `:long_text`, `:attachment`                        |
| `sortable?`                  | `true`         | Auto-disabled if technically unsortable                               |
| `keyset_sortable?`           | `true`         | Auto-disabled if technically unsortable                               |
| `filterable?`                | `true`         | Auto-disabled if technically unfilterable                             |
| `edit_with`                  | nil            | `:type`, `{action, type}`, or `nil` to disable inline edit            |
| `tone`                       | nil            | A tone, or an Ash expression that gives a tone or `nil` (see below)   |
| `render`                     | nil            | A render module for the cell (default: `render_cell_data/1`)          |

## `field` (non-table views)

Fields display individual values within `:grid`, `:list`, `:kanban`,
`:calendar`, `:gantt`. Unlike columns, fields are pre-laid-out and not
user-controlled.

```elixir
field :name
field :status do
  empty_text "—"
end
```

| Key          | Default   | Notes                                                   |
| ------------ | --------- | ------------------------------------------------------- |
| `name`       | required  | Attribute/calculation/aggregate                         |
| `label`      | humanized | Display label                                           |
| `source`     | `[name]`  | Path; allows traversal                                  |
| `size`       | `:auto`   | The content role, as in forms (`:code` … `:prose`)      |
| `tone`       | nil       | A tone, or an Ash expression (see below)                |
| `empty_text` | `"—"`     | Shown when value is nil/unloaded                        |
| `render`     | nil       | A render module for the value                           |

## `section` (grid views)

Sections group fields and relationships into logical areas in `:grid`.

```elixir
view :read do
  type :grid

  section "Basics" do
    field :name
    field :style
  end

  section "Stats" do
    collapsible? true
    collapsed? true

    field :target_abv
    field :target_og
    field :target_fg
  end
end
```

| Key            | Default           | Notes                                             |
| -------------- | ----------------- | ------------------------------------------------- |
| `name`         | required (string) | Section heading                                   |
| `collapsible?` | `false`           | User can collapse/expand                          |
| `collapsed?`   | `false`           | Starts collapsed (only with `collapsible?: true`) |
| `render`       | nil               | A render module for the entire section            |

## `relationship` (within a section)

Renders a related record set inside a section.

```elixir
section "Ingredients" do
  relationship :recipe_ingredients do
    display :table
    limit 25
  end
end
```

| Key          | Default   | Notes                                                            |
| ------------ | --------- | ---------------------------------------------------------------- |
| `name`       | required  | Relationship on the resource                                     |
| `display`    | `:list`   | One of `:list`, `:table`, `:grid`, `:count`, `:badge`            |
| `label`      | humanized | Display label                                                    |
| `limit`      | nil       | Maximum related records to display                               |
| `link?`      | `true`    | Link records to their show page                                  |
| `empty_text` | `"None"`  | Shown when no related records                                    |
| `render`     | nil       | A render module for the related records                          |

## `tone`

A column or a view field can have a `tone`: the meaning of the value, not
a color. The tones are `:neutral`, `:info`, `:success`, `:warning`, and
`:danger`. The value is a tone or an Ash expression that gives a tone or
`nil`. The refs of the expression are validated at compile time and loaded
with the rows (they can be calculations or aggregates). A navigation item
or group has a `tone` too (a tone only).

```elixir
column :calibration_due_on do
  tone expr(if calibration_due_on < today(), do: :danger)
end
```

## `set` (cross-resource views)

`set` declares how to map values from the parent record into the nested
view's read action. Used when the nested view has an explicit `resource`
but no `relationship`.

```elixir
view do
  type :data_table
  resource MyApp.AuditLog
  read_action :for_record

  set :record_id, :id
  set :record_type, :__resource__
end
```

| Key      | Notes                                                |
| -------- | ---------------------------------------------------- |
| `name`   | Target field on the read action (argument or filter) |
| `source` | Field on the parent record to read                   |

## Common mistakes

- Setting `type` as an inline keyword on `view :read, type: :data_table do`
  fails to compile — always put it inside the block.
- Using `column` in a non-table view, or `field`/`section` in a
  `:data_table`. Each entity is restricted to specific view types.
- Forgetting `delegate_to` on a `:delegated` view (required) or supplying
  it on any other type (forbidden).
- Using `set` without an explicit `resource` on the nested view (no effect).
- A `class`, `cell_class`, `header_class`, or `render_cell_data` option, or a
  function for `render`. They are removed: use `tone`, `size`, or a render
  module.
