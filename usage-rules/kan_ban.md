# KanBan extension

`PyroManiac.KanBan` is a Spark DSL extension applied to an Ash resource
that should support a kanban board (swimlanes + drag-to-reorder cards).
It's separate from `PyroManiac.Resource` — typically you use both.

## Adding the extension

```elixir
defmodule MyApp.Brewery.Batch do
  use Ash.Resource,
    domain: MyApp.Brewery,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource, PyroManiac.KanBan]

  pyro_maniac do
    default_label :batch_number
  end

  kan_ban do
    lane :status
    priority :kanban_priority
    move_action :move_card
    read_action :kanban_read
    per_lane 20
    count? true
  end

  attributes do
    attribute :status, :atom,
      constraints: [one_of: ~w[brewing fermenting packaged]a],
      allow_nil?: false,
      public?: true
    # `kanban_priority` will be added automatically by the transformer
    # if you do not declare it.
  end

  # ...
end
```

## `kan_ban` schema

| Key           | Type           | Default  | Notes                                                                                                           |
| ------------- | -------------- | -------- | --------------------------------------------------------------------------------------------------------------- |
| `lane`        | `:atom`        | required | Attribute used to group records into swimlanes. Must be an Ash enum or an atom/string with `one_of` constraints |
| `priority`    | `:atom`        | required | Integer attribute for card ordering within a lane. Auto-created if missing                                      |
| `move_action` | `:atom`        | required | Name of the generated update action that handles drag-to-move                                                   |
| `read_action` | `:atom`        | required | Name of the generated read action used to load a single lane                                                    |
| `per_lane`    | `:pos_integer` | `20`     | Maximum cards loaded per lane. "Load more" handles the rest                                                     |
| `count?`      | `:boolean`     | `false`  | When `true`, renderer shows the total card count in each lane header (one count query/lane)                     |

## What the transformer generates

`PyroManiac.KanBan.Transformers.Setup` runs at compile time and adds:

- The `priority` integer attribute, if not already defined.
- An update action with the configured `move_action` name. It accepts
  the lane and priority fields and shifts other cards' priorities
  atomically.
- A read action with the configured `read_action` name. It accepts a
  `lane_value` argument and limits results to `per_lane`.

You can write your own actions with these names — the transformer
detects existing actions and skips creation.

## Wiring kanban to a view

Use a `:kanban` view inside the page module. The view's keys must match
the resource's `kan_ban` config:

```elixir
defmodule MyAppWeb.BatchLive do
  use PyroManiac, resource: MyApp.Brewery.Batch

  views do
    view :read do
      type :kanban
      group_by :status
      kanban_action :move_card
      priority :kanban_priority

      field :batch_number
      field :brew_date
      field :recipe
    end
  end
end
```

| View key        | Should match resource's |
| --------------- | ----------------------- |
| `group_by`      | `lane`                  |
| `kanban_action` | `move_action`           |
| `priority`      | `priority`              |

## Common mistakes

- Using a non-enum, non-`one_of` attribute for `lane` — the lanes need a
  fixed set of values to render columns.
- Setting `priority` to a non-integer attribute (renderers cannot
  reorder).
- Defining the move/read actions with different names than the
  `kan_ban` block declares — the transformer generates the names you
  declared, not the names you implemented.
- Forgetting `PyroManiac.Resource` alongside `PyroManiac.KanBan` —
  pages backed by the resource still require the `pyro_maniac do
default_label end` block.
