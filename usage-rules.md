# Rules for working with PyroManiac

PyroManiac is a declarative, framework-agnostic UI DSL for Ash Framework
resources. The DSL compiles at build time via Spark and exposes the result
through `PyroManiac.Info`. Rendering belongs to a separate renderer library
(e.g. `pyro_maniac_live_view`); this package is render-agnostic by design.

Read the relevant sub-rule under `usage-rules/` _before_ writing PyroManiac
code. Do not assume prior knowledge of the DSL — the surface has changed
across recent versions.

## Non-negotiable rules

- **Do not** import or reference Phoenix/LiveView/Hologram modules from
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

## Sub-rules

| Topic                                   | When to read                                                                                |
| --------------------------------------- | ------------------------------------------------------------------------------------------- |
| [page](usage-rules/page.md)             | Defining a page module: `use PyroManiac`, the `page` section, `tenant_from`, `extra_action` |
| [views](usage-rules/views.md)           | The `views` section: every view type and its entities                                       |
| [forms](usage-rules/forms.md)           | The `forms` section: `action`, `bulk_action`, fields, groups, steps                         |
| [searches](usage-rules/searches.md)     | The `searches` section: filter tabs                                                         |
| [resource](usage-rules/resource.md)     | Adding `PyroManiac.Resource` to an Ash resource                                             |
| [navigation](usage-rules/navigation.md) | Declaring a `PyroManiac.Navigation` module                                                  |
| [kan_ban](usage-rules/kan_ban.md)       | Adding `PyroManiac.KanBan` to a resource for kanban support                                 |
| [info](usage-rules/info.md)             | Runtime introspection via `PyroManiac.Info`                                                 |

## Generating code

Always prefer generators over hand-written boilerplate:

1. Run `mix help` (or `list_generators` in Tidewave) to find available tasks.
2. Pass `--yes` to non-interactive generator runs.
3. Use the generator output as a starting point and modify from there.
