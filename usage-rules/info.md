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
| `title/1`              | Page title (string, required)                                                                  |
| `description/1`        | Page description (string, render fn, or nil)                                                   |
| `route/1`              | Route path (string or nil)                                                                     |
| `default_viewer/1`     | Default viewer atom                                                                            |
| `track_presence?/1`    | Boolean                                                                                        |
| `tenant_from/1`        | The `TenantFrom` struct or nil                                                                 |
| `page_extra_actions/1` | List of page-level `ExtraAction` structs                                                       |
| `loads/1`              | Ash load statement for the `default_label` (calculation/aggregate) — empty list for attributes |

## Views

| Function               | Returns                                                                         |
| ---------------------- | ------------------------------------------------------------------------------- |
| `views/1`              | All top-level view entities                                                     |
| `view_for/3`           | View matching `{action_name, type}`                                             |
| `views_of_type/2`      | All views of a given type                                                       |
| `primary_view/2`       | Primary view for a type (matches primary read action, then `:read`, then first) |
| `view_for_action/2`    | Any view containing a given action name                                         |
| `view_extra_actions/1` | Extra actions across all views (deduped by name)                                |

## Forms

| Function                      | Returns                               |
| ----------------------------- | ------------------------------------- |
| `form_actions/1`              | All `Form.Action` entities            |
| `form_actions_for_resource/2` | Forms scoped to a specific resource   |
| `form_for/2`                  | Form action by name                   |
| `form_for/3`                  | Form action by name + target resource |
| `form_for_action_type/2`      | First form for `:create` or `:update` |
| `form_for_action_type/3`      | Same, scoped to a target resource     |
| `bulk_actions/1`              | All `BulkAction` entities             |
| `bulk_action_for/2`           | Bulk action by name                   |

## Searches

| Function     | Returns                      |
| ------------ | ---------------------------- |
| `searches/1` | All `Search.Search` entities |

## Companion `Info` modules

Each extension provides its own `Info` module:

- `PyroManiac.Resource.Info`
  - `default_label/1` — the resource-level default label
  - `record_label/2` — render a record's label
- `PyroManiac.Navigation.Info`
  - `nav_tree/1`, `route_manifest/1`, `flat_items/1`
  - `path_for_page/2`, `item_for_page/2`, `items_by_page/1`
- `PyroManiac.KanBan.Info`
  - `lane!/1`, `priority!/1`, `move_action!/1`, `read_action!/1`
  - `per_lane/1`, `count?/1`, `has_kanban?/1`

## Common mistakes

- Calling `Spark.Dsl.Extension.get_entities/2` directly to read the
  views map. Use `views/1` / `view_for/3` — the persisted layout
  (`:views_by_action_and_type`) is internal.
- Treating `default_label/1` as a string. It returns the **field name**
  (atom). Use `PyroManiac.Resource.Info.record_label/2` to render a
  record's label.
