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
