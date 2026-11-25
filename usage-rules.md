# Rules for working with PyroManiac

PyroManiac is a declarative, framework-agnostic UI DSL for Ash Framework
resources. The DSL compiles at build time via Spark and exposes the result
through `PyroManiac.Info`. Rendering belongs to a separate renderer library;
this package is render-agnostic by design.

Read the relevant sub-rule under `usage-rules/` _before_ writing PyroManiac
code. Do not assume prior knowledge of the DSL — the surface has changed
across recent versions.

## Non-negotiable rules

- **Do not** import or reference renderer or web framework modules from
  PyroManiac DSL or extension code. The DSL is framework-agnostic;
  rendering and routing live in renderer libraries.
- Spark DSL entity keyword options **cannot** be passed inline when a `do`
  block is present. Use the entity macro inside the block:

  ```elixir
  # right
  view :read do
    type :data_table
  end

  # wrong — fails to compile
  view :read, type: :data_table do
    column :name
  end
  ```

- DSL validations belong in **transformers**, not verifiers. Validation
  tests use `assert_raise` + inline `defmodule`, which only catches errors
  raised during transformer phase.
- The `pyro_maniac do default_label :field end` block on the resource is
  **required**. `PyroManiac.Dsl` has a verifier that rejects any page whose
  resource lacks the `PyroManiac.Resource` extension.
- There is no `views do` block and no `forms` section. `view` is top
  level, and a view names its actions (`action`, `bulk_action`). Each
  exposed action of the resource is used by a view or is in `page do
  exclude [...] end`.
- Each `action` and `bulk_action` has a required `state` (`:guard`,
  `:recover`, or `:discard`), with no default: `action :update, :guard`,
  or `state :guard` in its block. `edit_columns` takes it as the third
  argument. Refer to [forms](usage-rules/forms.md).
- Every action interface is authorized with the scope of the user. No
  exceptions: never `authorize?: false` in UI code. What a UI shows comes
  from `Ash.can?(subject, scope, maybe_is: true, run_queries?: false)` on
  the server, or from AshTypescript on a client. Write policies whose
  strict check decides (simple checks of the actor first), so the answers
  are exact. Refer to `documentation/tutorials/policies.md`.
- The **surface** is required: a page can use only the actions and fields
  that its resources `expose`. When a page does not compile because of the
  surface, add the action or field to the `expose` of the resource. Do not
  add fields that no page uses. Refer to [resource](usage-rules/resource.md).

## Sub-rules

| Topic                                   | When to read                                                                 |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| [page](usage-rules/page.md)             | Defining a page module: `use PyroManiac`, the `page` section, `exclude`, the filters, `extra_action` |
| [views](usage-rules/views.md)           | `view` (top level): every view type, the record tree, `workflow`, columns, inline edits, `clone?`/`new_row?`/`reorder?`, decorations |
| [forms](usage-rules/forms.md)           | The actions of a view: `action`, `bulk_action`, `state`, `confirm`, inputs, sections, tabs, steps, `set` |
| [searches](usage-rules/searches.md)     | `search` (top level): filter tabs                                            |
| [resource](usage-rules/resource.md)     | Adding `PyroManiac.Resource` to an Ash resource                              |
| [navigation](usage-rules/navigation.md) | Declaring a `PyroManiac.Navigation` module, and the command palette          |
| [kan_ban](usage-rules/kan_ban.md)       | Adding `PyroManiac.KanBan` to a resource for kanban support: static or dynamic lanes, and `PyroManiac.KanBan.Lanes` for a lane resource |
| [ordering](usage-rules/ordering.md)     | Adding `PyroManiac.Ordering` to a resource for a user-defined order (`reorder?`) |
| [filter_presets](usage-rules/filter_presets.md) | Adding `PyroManiac.FilterPresets` to the resource that stores saved filters |
| [info](usage-rules/info.md)             | Runtime introspection via `PyroManiac.Info`                                  |

## Generating code

Always prefer generators over hand-written boilerplate:

1. Run `mix help` (or `list_generators` in Tidewave) to find available tasks.
2. Pass `--yes` to non-interactive generator runs.
3. Use the generator output as a starting point and modify from there.
