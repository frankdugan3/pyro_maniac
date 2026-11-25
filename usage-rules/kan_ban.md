# KanBan extension

`PyroManiac.KanBan` is a Spark DSL extension applied to an Ash resource
that should support a kanban board (lanes + drag-to-reorder cards).
It's separate from `PyroManiac.Resource` — typically you use both.

## Adding the extension

```elixir
defmodule Brewery.Batch do
  use Ash.Resource,
    domain: Brewery.Domain,
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
    attribute :status, Brewery.BatchStatus,
      allow_nil?: false,
      default: :planned,
      public?: true

    # `kanban_priority` will be added automatically by the transformer
    # if you do not declare it.
  end

  # ...
end
```

## `kan_ban` schema

| Key                | Type           | Default  | Notes                                                                                                                                  |
| ------------------ | -------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `lane`             | entity         | required | The lanes (exactly one). An attribute (static lanes): an Ash enum or an atom/string with `one_of`. Or a `belongs_to` (dynamic lanes)   |
| `priority`         | `:atom`        | required | String attribute (a fractional index) for card ordering within a lane. Auto-created if missing                                         |
| `move_action`      | `:atom`        | required | Name of the generated update action that handles drag-to-move                                                                          |
| `read_action`      | `:atom`        | required | Name of the generated read action used to load a single lane                                                                           |
| `per_lane`         | `:pos_integer` | `20`     | Maximum cards loaded per lane. "Load more" handles the rest                                                                            |
| `count?`           | `:boolean`     | `false`  | When `true`, renderer shows the total card count in each lane header (one count query/lane)                                            |

### The `lane` entity

`lane :status` (no block) or `lane :stage do ... end`. The options are for
dynamic lanes only:

| Key              | Type      | Default          | Notes                                                                                     |
| ---------------- | --------- | ---------------- | ----------------------------------------------------------------------------------------- |
| `read_action`    | `:atom`   | primary read     | The read action of the lane resource that gives the lanes. Required: no read is an error  |
| `create_action`  | `:atom`   | primary create   | Adds a lane. `false`, or no primary create: the board does not add lanes                  |
| `update_action`  | `:atom`   | primary update   | Edits a lane (name, decoration). `false`, or no primary update: the board does not edit lanes |
| `destroy_action` | `:atom`   | primary destroy  | Deletes a lane. `false`, or no primary destroy: the board does not delete lanes           |
| `move_action`    | `:atom`   | ordering move    | Moves a lane in the order of the lanes (an update action). Defaults to the move action of an ordered lane resource; `false`, or an unordered lane resource: the lanes do not move |
| `sort`           | `:string` | rank             | The order of the lanes, an Ash sort input (`"position"`). Defaults to the rank of an ordered lane resource |

The actions are resolved at compile time, on the destination of the
`belongs_to`. A named action that the lane resource does not have, or that
has another type, is a compile error. `read_action` gives the lanes;
`create_action`, `update_action`, and `destroy_action` manage them;
`move_action` of the `lane` moves the lanes, and `move_action` of the
`kan_ban` section moves the cards.

## Static and dynamic lanes

- **Static lanes.** `lane` is an attribute: the lanes are its values (an
  enum or `one_of`), fixed at compile time. Adding a lane is a code change.
- **Dynamic lanes.** `lane` is a `belongs_to`: the lanes are the records of
  its destination, so the users can add them. The cards are ordered in each
  lane by the foreign key (`stage_id`). The destination is an existing
  resource (the stages of a project), or a lane resource with
  `PyroManiac.KanBan.Lanes`. A card with a `nil` foreign key (when the
  relationship allows it) is in the lane "No lane".

```elixir
defmodule Brewery.Task do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource, PyroManiac.KanBan]

  relationships do
    belongs_to :stage, Brewery.Stage, public?: true
  end

  kan_ban do
    lane :stage do
      # read, create, and update: the primary actions of Brewery.Stage
      destroy_action false
    end

    priority :rank
    move_action :move_card
    read_action :kanban_read
  end
end
```

The move action accepts the foreign key (`stage_id`), not the
relationship name.

## The `PyroManiac.KanBan.Lanes` extension

A resource extension for a resource whose records are only lanes. Section
`kan_ban_lanes`:

| Key           | Type    | Default     | Notes                                                                       |
| ------------- | ------- | ----------- | --------------------------------------------------------------------------- |
| `scope`       | `:atom` | `nil`       | An attribute whose records have their own lanes (`:project_id`). `nil`: one set of lanes |
| `position`    | `:atom` | `:position` | The rank attribute of the order of the lanes                                |
| `move_action` | `:atom` | `:move`     | The update action that moves a lane                                         |

```elixir
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
```

It adds, unless the resource has them:

- the attributes `id` (UUID primary key), `name` (the label of the lane),
  and `decoration` (one of `PyroManiac.Info.decorations/0`, or `nil`);
- the order: the `position` rank attribute (a fractional index, a unique
  index on the `scope` and the position), a new lane at the end, and the
  `move_action` (the same machinery as `PyroManiac.Ordering`);
- the primary actions `read`, `create`, `update`, and `destroy`. Create and
  update accept `name`, `decoration`, and the `scope`.

`PyroManiac.KanBan.Lanes.lanes?/1` tells whether a resource has it.
`PyroManiac.Ordering.Info.ordering/1` reads a lane resource (the
`position`, the `scope`, the `move_action`), so its lanes also sort and
move as an ordered resource.

## Info functions

`PyroManiac.KanBan.Info`:

| Function             | Returns                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------ |
| `lane/1`             | The `lane` entity (`PyroManiac.KanBan.Lane`), with the actions of dynamic lanes resolved, or `nil` |
| `lane!/1`            | The name of the `lane` (an attribute or a relationship name)                                    |
| `lane_relationship/1`| The `belongs_to` of dynamic lanes, or `nil`                                                      |
| `dynamic_lanes?/1`   | Whether the lanes are dynamic                                                                    |
| `lane_attribute!/1`  | The attribute that groups the cards: the `lane` attribute, or the foreign key of the `belongs_to` |
| `lane_resource/1`    | The destination of dynamic lanes, or `nil`                                                       |
| `lane_read_action/1` | The `read_action` of the `lane`, else the primary read of the lane resource; `nil` for static lanes |
| `lane_action/2`      | The `:create`, `:update`, `:destroy`, or `:move` action of dynamic lanes, or `nil` (off, none, or static lanes) |
| `manage_lanes?/1`    | Whether `lane_action/2` is set for `:create`, `:update`, or `:destroy`                            |
| `lane_sort/1`        | The `sort` of the `lane`, else the rank of an ordered lane resource, else `nil`                 |
| `lanes/2`            | `{:ok, [%{value:, label:, record:}]}`, in order                                                  |

`lanes/2` takes `actor`, `tenant`, `authorize?`, and `query` (a query of
the lane resource to start from). Static lanes are the values of the
attribute (`record: nil`, the label of the enum or the humanized value).
Dynamic lanes are the records of the lane read action: `value` is the
primary key, `label` the record label (`PyroManiac.Resource`), else the
`name`. The "No lane" lane is not in the list: the renderer adds it.

```elixir
# the lanes of one project
PyroManiac.KanBan.Info.lanes(Brewery.Task,
  actor: actor,
  query: Ash.Query.filter(Brewery.Stage, project_id == ^project_id)
)
```

## What the transformer generates

`PyroManiac.KanBan.Transformers.Setup` runs at compile time. The order of
the cards is the ordering of `PyroManiac.Ordering`, scoped by the lane (the
shared `PyroManiac.Ordering.Setup`; refer to [ordering](ordering.md)). It
adds:

- The `priority` string attribute (a fractional index, `COLLATE "C"`), if
  not already defined, and a unique index on the lane and the priority.
- The priority of a new card: the end of its lane. An update that changes
  the lane but not the priority puts the card at the end of its new lane.
- An update action with the configured `move_action` name. It accepts
  the lane and the neighbors of the card, and gives the moved card a key
  between them. The other cards do not change.
- A read action with the configured `read_action` name. It accepts a
  `lane_value` argument and limits results to `per_lane`.

The extension creates these actions: an existing action with the name of
`move_action` or `read_action` is a compile error. The database functions
need `PyroManiac.KanBan.PostgresExtension` (version 3) in the
`installed_extensions` of the repo.

With a `belongs_to` lane, the lane of the ordering (the scope, the unique
index, the move action) is its foreign key.

`PyroManiac.Ordering.Info.ordering/1` also reads a kanban resource (the
`priority` as the attribute, `lane_attribute!/1` as the scope), so `reorder? true`
works on its other list views.

## Wiring kanban to a view

Use a `:kanban` view inside the page module. The view takes its keys from
the `kan_ban` config of the resource:

```elixir
defmodule BreweryWeb.BatchLive do
  use PyroManiac, resource: Brewery.Batch

  page do
    route "/batches"
    exclude [:list, :create, :update, :start_brewing, :advance_status, :complete, :destroy]
  end

  view :kanban_read do
    type :kanban
    primary? true

    field :batch_number
    field :name, path: [:recipe], label: "Recipe"
    field :brew_date
    field :volume_liters
  end

  view :read do
    type :card
    primary? true

    section :batch do
      field :batch_number
      field :status
      field :brew_date
    end
  end
end
```

The board uses the move action (`move_card`), so the page does not
exclude it. Setting `group_by`, `kanban_action`, `priority`, or
`default_sort` on a `:kanban` view is an error: they come from the
resource. The `lane_value` argument of the read action is public: like
any public argument of the read action of a view, it is a resolved input
in the private `__arguments__` of the view.

| View key        | From the resource's |
| --------------- | ----------------------- |
| `group_by`      | `lane`                  |
| `kanban_action` | `move_action`           |
| `priority`      | `priority`              |
| `default_sort`  | `priority`              |

## Common mistakes

- Using a non-enum, non-`one_of` attribute for `lane` — static lanes need
  a fixed set of values to render columns. For lanes the users add, make
  `lane` a `belongs_to`. A `lane` that is neither an attribute nor a
  `belongs_to` does not compile.
- Setting `read_action`, `create_action`, `update_action`,
  `destroy_action`, `move_action`, or `sort` in the `lane` of an attribute
  lane. They are
  for dynamic lanes: a compile error.
- Naming a lane action that the lane resource does not have, or of another
  type (`update_action :read`). It does not compile. A lane resource
  without a read action does not compile either.
- Expecting lane controls without lane actions. The board adds, edits,
  and deletes lanes with the actions of the `lane` (default: the primary
  actions; `PyroManiac.KanBan.Lanes` adds them). Set `false` to turn one
  off. Moving lanes is `move_action` of the `lane`, not `update_action`; it
  defaults to the move action of an ordered lane resource
  (`PyroManiac.KanBan.Lanes` or `PyroManiac.Ordering`), so an unordered
  lane resource needs `move_action` set, or the lanes do not move.
- Confusing the two `move_action`s. The one of the `kan_ban` section is
  created on the card resource and moves the cards; the one of the `lane`
  is an action of the lane resource and moves the lanes.
- Reading all the lanes of a scoped lane resource. For the lanes of one
  project, pass `query:` to `PyroManiac.KanBan.Info.lanes/2` with the
  filter of the scope.
- Passing the relationship name (`stage`) to the move action. It accepts
  the foreign key (`stage_id`, `lane_attribute!/1`).
- Setting `priority` to an attribute that is not a `:string` (the
  fractional index is a string). It does not compile.
- Defining the move/read actions yourself. The transformer generates them
  with the names of the `kan_ban` block; an existing action with one of
  those names does not compile.
- Forgetting `PyroManiac.Resource` alongside `PyroManiac.KanBan` —
  pages backed by the resource still require the `pyro_maniac do
default_label end` block.
