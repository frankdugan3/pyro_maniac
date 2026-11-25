# Runtime introspection

`PyroManiac.Info` is the runtime API renderers use to read a compiled
PyroManiac module. Application code rarely calls these directly; they
are documented here so renderers and integrations can rely on a stable
surface.

If you are writing a renderer, prefer these functions over reaching
into Spark internals — the persisted layout is an implementation
detail.

## Page-level

| Function               | Returns                                                                                        |
| ---------------------- | ---------------------------------------------------------------------------------------------- |
| `resource/1`           | The Ash resource module bound to the page                                                      |
| `default_label/1`      | The resource's `default_label` field (atom)                                                    |
| `title/1`              | Page title: `title`, else the plural (or short) name of the resource, humanized                |
| `description/1`        | The `description` entities of `page`: a text, and implementations for some renderers (`PyroManiac.Content.resolve/2`) |
| `page?/1`              | Whether the module is a page (it has a `page` section). A module without it declares views and searches that the pages reuse, and is never routed |
| `route/1`              | The route of the page (`page do route ... end`), or nil when the module is not a page. A renderer declares the routes from it |
| `track_presence?/1`    | Boolean (default `false`)                                                                      |
| `custom_filters?/1`    | Whether the user builds filters (the advanced filter view)                                     |
| `filter_storage/1`     | `:client`, a `PyroManiac.FilterPresets` resource, or nil                                       |
| `shared_filters?/1`    | Whether a user can share a saved filter                                                        |
| `page_extra_actions/1` | List of page-level `ExtraAction` structs                                                       |
| `default_label_load/1` | `(resource)`: the load of the `default_label` (calculation/aggregate) — empty list for attributes |

## Views

| Function               | Returns                                                                         |
| ---------------------- | ------------------------------------------------------------------------------- |
| `views/1`              | All top-level view entities                                                     |
| `view_for/3`           | View matching `{action_name, type}`                                             |
| `views_of_type/2`      | All views of a given type                                                       |
| `primary_single_view/1` | The primary single view (the `:card` with `primary? true`), or nil             |
| `primary_list_view/1`  | The primary list view, else the primary single view, or nil                     |
| `named_views/3`        | `(page, :single \| :list, name)`: the single or list views with the action `name` |
| `view_for_action/2`    | Any view containing a given action name                                         |
| `view_extra_actions/1` | Extra actions across all views (deduped by name)                                |

Removed: `default_viewer/1`, `card_view/1`, and `primary_view/2`. Use
`primary_single_view/1` and `primary_list_view/1`. `description_render/1`
is removed: `description/1` gives the entities.

## Cards, links, and renders

| Function                                    | Returns                                                       |
| ------------------------------------------- | ------------------------------------------------------------- |
| `PyroManiac.Card.param(page, view, id)`     | The `card` param: `"<id>"` (primary card) or `"<view>:<id>"`  |
| `PyroManiac.Card.parse_param(page, value)`  | `{:ok, view, id}` or `:error`                                 |
| `PyroManiac.Link.list_filter/3`             | The filter of a list link by the relationship                 |
| `PyroManiac.Content.resolve/2`              | `(entries, renderer)`: `{:impl, x}`, else `{:text, s}` or `{:expr, e}`, else nil. For `render`, `description`, and the `label` of a column |
| `PyroManiac.Content.portable/1`             | `{:text, s}`, `{:expr, e}`, or nil: the value for every renderer |
| `PyroManiac.Content.text/1`                 | The text, or nil (a label for an error message, a filter chip) |
| `PyroManiac.Content.refs/1`                 | `(entity)`: the fields that its content expressions refer to  |
| `PyroManiac.Render.resolve/2`               | `(renders, renderer)`: delegates to `PyroManiac.Content.resolve/2` |
| `PyroManiac.Render.implementation/2`        | `(renders, renderer)`: the implementation of the renderer only, or nil |
| `PyroManiac.Render.verify/3`                | For a renderer's verifier: each node with implementations (`render`, `description`, a column `label`) and no text or expression has one for the renderer, and the renderer accepts each one it has |

Refer to the renderer guides (`documentation/renderers/`, starting with
`renderer-overview.md`; custom renders: `renderer-custom-renders.md`).

## Actions

The actions of the views (`action`, the `action` of a column,
`edit_columns`) are `PyroManiac.Form.Action` entities with their resolved
form (`fields`): one entity for each action name and view. `__view__` is
the view (`{name, type}`), `__column__` the column of an inline edit, and
`__columns__` the columns of `edit_columns`. An action without inputs (a
confirmation) has no fields. `state` is `:guard`, `:recover`, or
`:discard` (a renderer implements the guard and the recovery); `confirm`
is a text, an Ash expression (its refs in `__confirm_refs__`, loaded with
the record), or nil.

| Function                     | Returns                                                                |
| ---------------------------- | ---------------------------------------------------------------------- |
| `actions/1`                  | All the action entities of the page, the actions of the cards first    |
| `actions/2`                  | `(page, view)`: the actions of one view                                |
| `action_for/2`               | The first action with a name (a card first)                            |
| `action_for/3`               | The same, scoped to a target resource (cross-resource actions)         |
| `actions_for_resource/2`     | The actions scoped to a target resource                                |
| `action_for_type/2`          | The first action of type `:create` or `:update`                        |
| `action_for_type/3`          | The same, scoped to a target resource                                  |
| `form_fields/1`              | The inputs of the form of an action, in order (flattened from the tree) |
| `form_layout/1`              | The form of an action as plain maps (`kind`, options, `children`, `depends_on`). No functions, so it encodes as JSON for other renderers |
| `bulk_actions/1`             | All `BulkAction` entities, each with `__view__`                        |
| `bulk_action_for/2`          | Bulk action by name                                                    |

A view has `__editable?__` (it names a write action) and `__actions__`
(the names of its write actions).

Removed: `form_for/2-3`, `form_actions/1`, `form_actions_for_resource/2`,
`form_for_action_type/2-3`, and `PyroManiac.Card.form/1`.

## The record tree

| Function                         | Returns                                                         |
| -------------------------------- | --------------------------------------------------------------- |
| `PyroManiac.Card.tree/1`         | `(page \| view)`: the record tree of a view in view mode (its `__tree__`), resolved. For a page, its primary card |
| `PyroManiac.Card.actions/1`      | The actions of the primary card of a page                       |
| `PyroManiac.Card.tabs/1`         | The tabs of a page (its primary card) or of a tree              |
| `PyroManiac.Card.paths/2`        | The paths that a view loads for its record tree                 |
| `PyroManiac.Form.Tree.for_action/2` | The nodes of a tree for one action (`only`); the read action of the view is view mode |
| `PyroManiac.Form.Tree.in_action?/2` | Whether a node is in an action                               |

`PyroManiac.Form.Tree` also has `inputs/1`, `values/1`, `leaves/1`,
`all/1`, and `tabs/1`. `for_mode/2` and `in_mode?/2` are removed.

| Function                                  | Returns                                                         |
| ----------------------------------------- | --------------------------------------------------------------- |
| `PyroManiac.View.decoration/3`            | `(node, record, actor)`: the decoration of a cell or a value, or nil. The refs of the expression are in `__decoration_refs__` |
| `PyroManiac.Info.decorations/0`           | The configured decorations (`config :pyro_maniac, decorations: [...]`) |
| `PyroManiac.Info.default_decorations/0`   | `[:neutral, :info, :success, :warning, :danger]`                |
| `PyroManiac.Workflow.engine/1`            | `:ash_workflow`, `:ash_state_machine`, or nil                   |
| `PyroManiac.Workflow.state_attribute/1`   | The state attribute of the resource                             |
| `PyroManiac.Workflow.states/1`            | The states (or steps) of the workflow                           |
| `PyroManiac.Workflow.loads/1`             | The loads of a `workflow` node (AshWorkflow: `:current_step`, `:steps`, `:available_actions`, `:pending_deadlines`) |

A combobox on an argument that the action passes to `manage_relationship`
(attach and detach) is in select mode with `__multiple?__: true`,
`__relationship__`, and `__resource__` (the destination).
`PyroManiac.View.Section`, `PyroManiac.View.Compound`,
`PyroManiac.View.Row`, and `PyroManiac.View.Set` are removed: the nodes of
a view are the `PyroManiac.Form` entities.

## Searches

| Function     | Returns                      |
| ------------ | ---------------------------- |
| `searches/1` | All `Search.Search` entities |

## Companion `Info` modules

Each extension provides its own `Info` module:

- `PyroManiac.Resource.Info`
  - `default_label/1` — the resource-level default label
  - `record_label/2` — render a record's label
  - (`link_to/1` and `link_through/1` are removed: a link is a `link_to`
    entity of a node)
- `PyroManiac.Navigation.Info`
  - `nav_tree/1`, `route_manifest/1`, `flat_items/1`
  - `path_for_page/2`, `item_for_page/2` (the path of a `page` item is
    the route of its page)
  - `command_palette/1` — the command palette and its commands
- `PyroManiac.KanBan.Info`
  - `lane!/1`, `priority!/1`, `move_action!/1`, `read_action!/1`
  - `per_lane/1`, `count?/1`, `has_kanban?/1`
  - `lane_relationship/1` — the `belongs_to` of dynamic lanes, or nil;
    `dynamic_lanes?/1`
  - `lane_attribute!/1` — the attribute that groups the cards (the `lane`
    attribute, or the foreign key of the `belongs_to`)
  - `lane/1` — the `lane` entity (`PyroManiac.KanBan.Lane`), with the
    actions of dynamic lanes resolved
  - `lane_resource/1`, `lane_read_action/1`, `lane_sort/1` — the lane
    resource, its read action, and the order of the lanes (nil for static
    lanes)
  - `lane_action/2` — the `:create`, `:update`, `:destroy`, or `:move`
    action of dynamic lanes, or nil; `manage_lanes?/1` — whether one of
    the first three is set
  - `lanes/2` — `{:ok, [%{value:, label:, record:}]}` in order: the values
    of a static lane (`record: nil`), or the lane records (options
    `actor`, `tenant`, `authorize?`, `query`)
- `PyroManiac.KanBan.Lanes`
  - `lanes?/1` — whether a resource is a lane resource
- `PyroManiac.Ordering.Info`
  - `ordered?/1`, `ordering/1` — `%{attribute:, scope:, move_action:,
    algorithm:}` from `PyroManiac.Ordering`, `PyroManiac.KanBan.Lanes`, or
    `PyroManiac.KanBan`, or nil
- `PyroManiac.FilterPresets`
  - `storage?/1` — whether a resource stores filter presets

## Common mistakes

- Calling `Spark.Dsl.Extension.get_entities/2` directly to read the
  views map. Use `views/1` / `view_for/3` — the persisted layout
  (`:views_by_action_and_type`) is internal.
- Treating `default_label/1` as a string. It returns the **field name**
  (atom). Use `PyroManiac.Resource.Info.record_label/2` to render a
  record's label.
