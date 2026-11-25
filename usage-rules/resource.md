# Resource extension

`PyroManiac.Resource` is a Spark DSL extension applied to any Ash resource
that backs a PyroManiac page. It is required — `PyroManiac.Dsl` has a
verifier that rejects pages whose resource lacks the extension.

## Adding the extension

```elixir
defmodule Brewery.Recipe do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource]

  pyro_maniac do
    default_label :name
  end

  # ... attributes, actions, etc.
end
```

## `default_label`

The `default_label` is the field renderers use as the human-readable name
for a record. It can be an attribute, calculation, or aggregate:

```elixir
pyro_maniac do
  default_label :name           # attribute
end

pyro_maniac do
  default_label :name_email     # calculation
end
```

Renderers consume it via `PyroManiac.Info.default_label/1` and
`PyroManiac.Resource.Info.default_label/1`.

A verifier checks that the field exists on the resource at compile time.
If it doesn't, compilation fails with a clear error.

## `expose` (the surface)

A page can use only the actions and fields that the resource exposes. The
lists are explicit: also list the `default_label` and the fields of
`decoration` and `confirm` expressions that a page loads.

```elixir
pyro_maniac do
  default_label :name

  expose :read do
    loads [:name, :type, supplier: [:name]]
    filter [:name, :type]
    sort [:name]
  end

  expose [:create, :update]
end
```

- `filter` and `sort` are only for read actions.
- `:*` in a field list is all the public attributes, calculations, and
  aggregates (not the relationships): `loads [:*, supplier: [:name]]`. Prefer it
  to a list of all the fields. In `filter` and `sort`, `:*` skips the fields
  with `filterable? false` / `sortable? false`. Set those on a field (for
  example a password) that no filter or sort may use, also through RPC.
- A relationship atom (`:supplier`) is the relationship with `:*` of its
  resource, one level deep. A deeper load is always explicit.
- Each option defaults to `[:*]` (`filter` and `sort` only for a read action):
  `expose :read` exposes all the fields. Opt out explicitly: `filter []`.
  There is no `expose :*` for all actions.
- Each field must be public. Each action must be public.
- The `exclude` of a view names only exposed fields. The `exclude` of the
  `page` section names only exposed actions, and each exposed action is
  used by a view of the page or is in it. A module without the `page`
  section (not a page) is not checked.

## `realtime`

Required for views with `on_create`, `on_update`, `on_destroy`, or
`on_bulk`. Prefer `mode :auto` (it writes the `Ash.Notifier.PubSub` setup).
Use `PyroManiac.Realtime.topic/2` for topic strings in app code.

```elixir
pyro_maniac do
  realtime do
    mode :auto
    except [:activate]
    # One `PyroManiac.Realtime.Bulk` message for each bulk operation of
    # :create, and an event for `PyroManiac.Realtime.broadcast_bulk/3`.
    bulk [:create, :truncate]
  end
end
```

- Each exposed create, update, and destroy action of a view option
  (`on_create`, `on_update`, `on_destroy`) must be published to a static
  topic, or be in `except`.
- `on_bulk` needs `bulk`. An action cannot be in `bulk` and in `except`.
- Add `PyroManiac.Realtime.BulkCoalescer` to the supervision tree when
  `bulk` has actions.

## AshTypescript (optional)

`PyroManiac.Domain.Typescript` on the domain makes (`mode :auto`) or checks
(`mode :validate`) the `typescript_rpc` of the exposed actions. Each resource
with `expose` also needs `AshTypescript.Resource` and `type_name`.

## Combining with other extensions

`PyroManiac.Resource` is independent of, and composes with, other Ash
extensions. Common combinations:

- `[PyroManiac.Resource, AshAuthentication]` — auth-protected resources
- `[PyroManiac.Resource, PyroManiac.KanBan]` — kanban-aware resources
  (refer to [kan_ban](kan_ban.md))
- `[PyroManiac.Resource, PyroManiac.Ordering]` — records in a user-defined
  order, for `reorder? true` (refer to [ordering](ordering.md))
- `[PyroManiac.Resource, AshStateMachine]` (or AshWorkflow) — the
  `workflow` node of a record tree (refer to [views](views.md))
- `[PyroManiac.Resource, AshStorage]` — file-attachment resources

When using `PyroManiac.KanBan` or `PyroManiac.Ordering`, you still need
`PyroManiac.Resource` — they're separate extensions.
`PyroManiac.FilterPresets` is for the resource that stores the filter
presets of the users; it needs no `PyroManiac.Resource` (refer to
[filter_presets](filter_presets.md)).

## Common mistakes

- Forgetting `default_label` — it's required and the verifier will halt
  compilation.
- Pointing `default_label` at a relationship (not an attribute,
  calculation, or aggregate). Renderers cannot stringify a relationship.
- Adding `pyro_maniac do ... end` without listing `PyroManiac.Resource`
  in the resource's `extensions:` — the section won't compile.
