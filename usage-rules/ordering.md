# Ordering extension

`PyroManiac.Ordering` is an Ash resource extension that keeps the records
in a user-defined order: an attribute that holds the rank of each record,
and an action that moves a record before or after another one. A view
with `reorder? true` lets the user drag the records.

## Adding the extension

```elixir
defmodule Brewery.RecipeIngredient do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource, PyroManiac.Ordering]

  ordering do
    attribute :position
    scope :recipe_id
    algorithm :fractional_index
    move_action :move
  end
end
```

| Key           | Default             | Notes                                                                          |
| ------------- | ------------------- | ------------------------------------------------------------------------------ |
| `attribute`   | required            | The rank attribute (a `:string`). Added when the resource does not have it      |
| `scope`       | nil                 | An attribute whose records have their own order. `nil`: one order for all      |
| `algorithm`   | `:fractional_index` | A move changes the rank of the moved record only                               |
| `move_action` | `:move`             | The update action that the extension adds to move a record                     |

## What the extension adds

- The rank attribute (`:string`, `COLLATE "C"`, so the database sorts the
  keys by byte), and a unique index on the scope and the rank.
- The rank of a new record: the end of its scope.
- The move action. Its context has `:order_target_id` (the record to move
  before or after) and `:order_position` (`"before"`, `"after"`, or
  `"last"`). The rank is computed in Postgres by `pyro_order_compute_rank`:
  add `PyroManiac.KanBan.PostgresExtension` (version 3 or later) to the
  `installed_extensions` of the repo. Other data layers are not supported
  yet.

The extension adds the move action: an existing action with that name is
a compile error (rename it, or set another `move_action`).

## Wiring it to a view

```elixir
view :read do
  type :data_table
  primary? true
  default_sort "position"
  reorder? true
  column :name
end
```

- `reorder? true` is for `:data_table`, `:grid`, and `:list` views. The
  user drags the records when the list is sorted by the rank.
- The move action counts as used by the view: the page does not exclude
  it.
- `PyroManiac.KanBan` uses the same ordering for the cards of a lane, so
  `reorder?` also works on a kanban resource.

## Introspection

`PyroManiac.Ordering.Info.ordering(resource)` gives `%{attribute:, scope:,
algorithm:, move_action:}`, or `nil`. For a kanban resource, it gives the
`priority` (the attribute) and the `lane` (the scope).

## Common mistakes

- `reorder? true` on a view whose resource has neither `PyroManiac.Ordering`
  nor `PyroManiac.KanBan`. It does not compile.
- A rank attribute that is not a `:string`, or an existing action with the
  name of `move_action`. Both are compile errors.
- Forgetting `PyroManiac.KanBan.PostgresExtension` in the
  `installed_extensions` of the repo, or an older version of it: the move
  fails at runtime.
- Sorting the view by another field and expecting drag to reorder: the
  drag works only when the list is sorted by the rank.
