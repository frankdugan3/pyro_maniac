# Resource extension

`PyroManiac.Resource` is a Spark DSL extension applied to any Ash resource
that backs a PyroManiac page. It is required — `PyroManiac.Dsl` has a
verifier that rejects pages whose resource lacks the extension.

## Adding the extension

```elixir
defmodule MyApp.Brewery.Recipe do
  use Ash.Resource,
    domain: MyApp.Brewery,
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
  default_label :full_name      # calculation
end
```

Renderers consume it via `PyroManiac.Info.default_label/1` and
`PyroManiac.Resource.Info.default_label/1`.

A verifier checks that the field exists on the resource at compile time.
If it doesn't, compilation fails with a clear error.

## `expose` (the surface)

A page can use only the actions and fields that the resource exposes. The
lists are explicit: also list the `default_label` and the fields of `tone`
expressions that a page loads.

```elixir
pyro_maniac do
  default_label :name

  expose :read do
    loads [:name, :status, supplier: [:name]]
    filter [:name, :status]
    sort [:name]
  end

  expose [:create, :update]
end
```

- `filter` and `sort` are only for read actions.
- `:*` in a field list is all the public attributes, calculations, and
  aggregates (not the relationships): `loads [:*, owner: [:name]]`. Prefer it
  to a list of all the fields. In `filter` and `sort`, `:*` skips the fields
  with `filterable? false` / `sortable? false`. Set those on a field (for
  example a password) that no filter or sort may use, also through RPC.
- A relationship atom (`:owner`) is the relationship with `:*` of its
  resource, one level deep. A deeper load is always explicit.
- Each option defaults to `[:*]` (`filter` and `sort` only for a read action):
  `expose :read` exposes all the fields. Opt out explicitly: `filter []`.
  There is no `expose :*` for all actions.
- Each field must be public. Each action must be public.
- `exclude` lists on pages can name only exposed things.

## `realtime`

Required for views with `on_create`, `on_update`, `on_destroy`, or
`on_bulk`. Prefer `mode :auto` (it writes the `Ash.Notifier.PubSub` setup).
Use `PyroManiac.Realtime.topic/2` for topic strings in app code.

```elixir
pyro_maniac do
  realtime do
    mode :auto
    except [:punch_in]
    # One `PyroManiac.Realtime.Bulk` message for each bulk operation of
    # :import, and an event for `PyroManiac.Realtime.broadcast_bulk/3`.
    bulk [:import, :truncate]
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
- `[PyroManiac.Resource, AshStorage]` — file-attachment resources

When using `PyroManiac.KanBan`, you still need `PyroManiac.Resource` —
they're separate extensions.

## Common mistakes

- Forgetting `default_label` — it's required and the verifier will halt
  compilation.
- Pointing `default_label` at a relationship (not an attribute,
  calculation, or aggregate). Renderers cannot stringify a relationship.
- Adding `pyro_maniac do ... end` without listing `PyroManiac.Resource`
  in the resource's `extensions:` — the section won't compile.
