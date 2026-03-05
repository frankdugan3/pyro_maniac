# Searches

The `searches` section declares preconfigured filter tabs that map text
input to Ash filter predicates. Each tab is non-removable in the renderer
UI; users can add/remove their own filters separately.

```elixir
searches do
  search :by_name do
    field :name
  end

  search :by_status do
    operator :or

    field :status do
      operator :eq
    end
  end
end
```

`searches` is a top-level section — it sits at the page module's
top-level alongside `page`, `views`, `forms`.

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
field :name
field :brewer do
  source [:brewer, :first_name]
end

field :tags do
  operator :in
  source [:tags, [:related_tags, :name]]
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
# Search both `:title` and `:body`
field :q do
  source [:title, :body]
end

# Search nested relationship fields
field :brewer_name do
  source [[:brewer, :first_name], [:brewer, :last_name]]
end
```

## Common mistakes

- Forgetting that `searches` is **top-level** — placing it inside `page`
  or `views` breaks compilation.
- Operator atoms are not validated against Ash's known operators; a typo
  (`:contians`) will only fail at runtime when the filter is built.
- `source` for a relationship traversal must be a list-of-lists when you
  want OR-across-paths; a single nested list is one path, not two.
