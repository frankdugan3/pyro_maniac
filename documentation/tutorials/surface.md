# The surface

The **surface** of a resource is the complete list of what a PyroManiac page
can use: the actions, and the fields that a page loads, filters on, and
sorts on. You declare it with `expose` in the `pyro_maniac` section of
`PyroManiac.Resource`. The surface is required: a page that uses an action
or a field that is not exposed does not compile.

```elixir
pyro_maniac do
  default_label :batch_number

  expose :read do
    loads [:batch_number, :status, :brew_date, recipe: [:name, :style]]
    filter [:batch_number, :status, recipe: [:name]]
    sort [:batch_number, :brew_date]
  end

  expose [:create, :update]
  expose :start_brewing
end
```

- `expose` takes one action name or a list. Each action in a list gets the
  same options. Each action is exposed in one `expose` only.
- `loads`, `filter`, and `sort` are field lists: atoms, and keyword lists for
  the fields of a relationship. Each field must be public.
- `filter` and `sort` are only for read actions.
- `:*` in a field list is all the public attributes, calculations, and
  aggregates of the resource (not its relationships). A relationship atom is
  the relationship with `:*` of its resource, one level deep: `loads [:*,
  :brewer, recipe: [:name]]`. A deeper load is always explicit. The Ash
  actions and fields are explicit about `public?`, so `:*` exposes only what
  the resource makes public.
- Each option defaults to `[:*]` (`filter` and `sort` only for a read
  action), so `expose :read` exposes all the fields. To opt out of an option,
  set it: `sort []`.

## What the page must expose

The page checks each of these against the surface, at compile time:

| Page DSL | Action | Fields |
|---|---|---|
| `view` | the read action (`name`, or `read_action`) | the columns, fields, sections, `decoration` fields, the fields of the `render`, `description`, and `label` expressions, `ensure_loaded`, the special fields (`date_field`, `group_by`, ...), and the `default_label` |
| data table columns, `searches` | the read action | `filter` (filterable columns, search sources), `sort` (sortable columns, `default_sort`) |
| `action` of a view | the create, update, destroy, or generic action (of `resource` for a cross-resource action) | the relationships of nested forms |
| `bulk_action` | the action | — |
| `combobox` | the read action of the searched resource | its `label_key` and `value_key`, `search` (`filter`), `sort` |
| the `action` of a column, `edit_columns` | the update action | — |
| `kanban` view | the move action | — |

The loads are explicit: list each field that PyroManiac loads, also the
`default_label` and the fields of the `decoration`, `render`,
`description`, `label`, and `confirm` expressions. PyroManiac does not add
a field to the surface.

The `loads` of a `:render` view are loads of its read action.

## Short lists

The surface also keeps the `exclude` lists of the pages short:

- A data table shows or excludes each exposed field of its read action (not
  each public field).
- `exclude` of a view can name only exposed fields.
- `exclude` of the `page` section can name only exposed actions.
- Each exposed action (read, create, update, destroy, generic) is used by a
  view of each page or is in its `page do exclude [...] end`. A module
  without the `page` section (views and searches that the pages reuse) is
  not checked. A read action is used by a
  view with its name (or `read_action`); the other actions by `action`,
  `bulk_action`, the `action` of a column, or `edit_columns`, and the move
  action by a `:kanban` view or `reorder? true`. The AshStorage actions of
  an attachment are not checked.

## The renderers

A renderer can call Ash directly or call the AshTypescript RPC actions. The
transport is a detail of the renderer. A renderer that calls Ash directly
limits the sort and the filter that a user selects to the exposed `sort`
and `filter` of the read action (`PyroManiac.Surface.restrict_sort_input/3`,
`PyroManiac.Surface.restrict_filter/3`). The RPC actions have the same
limits from `allowed_loads`, `enable_filter?`, and `enable_sort?`.

## Realtime

The `realtime` section of `pyro_maniac` connects the resource to
`Ash.Notifier.PubSub`. A view with `on_create`, `on_update`, or `on_destroy`
needs it.

```elixir
pyro_maniac do
  realtime do
    mode :auto
  end
end
```

- `mode :validate` (the default): you write `notifiers:
  [Ash.Notifier.PubSub]` and `pub_sub`. A verifier checks them.
- `mode :auto`: PyroManiac adds the notifier and the publications (`*` for
  create, update, and destroy; `updated:<id>` and `destroyed:<id>` unless
  `record_topics? false`). Set the default PubSub module with `config
  :pyro_maniac, :realtime, module: BreweryWeb.Endpoint`. The default `prefix` is
  the module name without its first segment, in snake case.
- `except` names the actions that send no notification.
- In both modes, each exposed create, update, and destroy action (not in
  `except`) must have a publication with a static topic.

Use `PyroManiac.Realtime.topic/2` in place of a literal topic string.

The page checks each realtime option of a view against the resource:

- `on_create`, `on_update`, `on_destroy`: each exposed action of the type
  is published to a static topic, or it is in `except`. At least one
  action of the type is published, else the option has no effect.
- `on_bulk`: the resource has `bulk` in its `realtime` section.

### Bulk notifications

A bulk operation sends one notification for each record. With the action
in `bulk`, a bulk operation of the action sends one
`PyroManiac.Realtime.Bulk` message on `PyroManiac.Realtime.bulk_topic/1`.
A call for one record still sends its record notification. An atom that is
not an action is an event for `PyroManiac.Realtime.broadcast_bulk/3`, for
a change that Ash does not notify (for example a truncate).

```elixir
pyro_maniac do
  realtime do
    mode :auto
    bulk [:create, :truncate]
  end
end
```

```elixir
view :read do
  type :data_table
  on_bulk :reload
end
```

`PyroManiac.Realtime.BulkCoalescer` sends the message when the notifications
of the action stop for a short window (`config :pyro_maniac, :realtime,
bulk_window: 50`, in milliseconds). Add it to the supervision tree of the
app. In `:validate` mode, add `PyroManiac.Realtime.BulkNotifier` to
`notifiers:` and `filter: &PyroManiac.Realtime.record_notification?/1` to
each publication of a bulk action.

## AshTypescript

With AshTypescript as a dependency, the domain extension
`PyroManiac.Domain.Typescript` connects the surface to `typescript_rpc`:

```elixir
use Ash.Domain, extensions: [PyroManiac.Domain.Typescript]

pyro_maniac_typescript do
  mode :auto
end
```

- `mode :validate` (the default) checks that each exposed action has an
  `rpc_action` that allows its loads.
- `mode :auto` adds an `rpc_action` for each exposed action without a
  written one. `allowed_loads` has the loadable fields of `loads` (plain
  attributes are left out: AshTypescript cannot restrict them).
- Each resource with `expose` needs `AshTypescript.Resource` and a
  `type_name`. You write them.

