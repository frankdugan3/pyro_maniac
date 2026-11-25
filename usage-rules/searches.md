# Searches

The `search` entities declare preconfigured filter tabs that map text
input to Ash filter predicates. Each tab is non-removable in the renderer
UI; users can add/remove their own filters separately.

```elixir
search :by_number do
  field :batch_number
end

search :by_status do
  operator :or

  field :status do
    operator :eq
  end
end
```

`search` is a top-level entity — it sits at the page module's top level
alongside `page` and `view`.

Every list view has the same filter experience: the searches as simple
chips, and, with `custom_filters? true` on the page, the advanced filter
view, where the user builds and saves filters (`filter_storage`,
`shared_filters?`; refer to [page](page.md) and
[filter_presets](filter_presets.md)).

## `search`

| Key            | Default   | Notes                                                    |
| -------------- | --------- | -------------------------------------------------------- |
| `name`         | required  | Search identifier                                        |
| `label`        | humanized | Tab label                                                |
| `interactive?` | `true`    | When `false`, all inputs render disabled (read-only tab) |
| `operator`     | `:and`    | How field predicates combine: `:and` or `:or`            |

Each `search` contains one or more `field` entities.

## `field`

```elixir
field :batch_number
field :brewer do
  source [:brewer, :name]
end

field :recipe do
  source [:notes, [:recipe, :name]]
end

field :status do
  operator :in
end
```

| Key        | Default     | Notes                                                                                       |
| ---------- | ----------- | ------------------------------------------------------------------------------------------- |
| `name`     | required    | Field identifier                                                                            |
| `label`    | humanized   | Input label                                                                                 |
| `operator` | `:contains` | Operator passed to the filter (e.g. `:contains`, `:eq`, `:in`, `:gte`)                      |
| `source`   | `[name]`    | One or more source paths. Each entry may be an atom or atom list. Multiple entries are OR'd |
| `value`    | nil         | Default value to pre-fill the input                                                         |

`source` accepts either a single path or a list:

```elixir
# Search both `:batch_number` and `:notes`
field :q do
  source [:batch_number, :notes]
end

# Search nested relationship fields
field :recipe_or_brewer do
  source [[:recipe, :name], [:brewer, :name]]
end
```

## Common mistakes

- Forgetting that `search` is **top-level** — placing it inside `page`
  or a `view`, or wrapping it in `searches do`, breaks compilation.
- Operator atoms are not validated against Ash's known operators; a typo
  (`:contians`) will only fail at runtime when the filter is built.
- `source` for a relationship traversal must be a list-of-lists when you
  want OR-across-paths; a single nested list is one path, not two.
