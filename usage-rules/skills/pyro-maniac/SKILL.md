---
name: pyro-maniac
description: Use this skill when defining or modifying PyroManiac DSL on Ash resources or PyroManiac page modules.
---

# PyroManiac

PyroManiac is a declarative, framework-agnostic UI DSL for Ash Framework
resources. It compiles UI configuration at build time via Spark and exposes
it through `PyroManiac.Info` for renderers to consume. Rendering itself
lives in separate libraries (e.g. `pyro_maniac_live_view`); the core
package is render-agnostic by design.

## Non-negotiable rules

- **Never** import or reference Phoenix/LiveView/Hologram modules from
  PyroManiac DSL or extension code. Rendering and routing live in renderer
  libraries — keep the DSL clean.
- **Spark DSL entity keyword options cannot be passed inline** when a `do`
  block is present. The compiler rejects:

  ```elixir
  view :read, type: :data_table do
    column :name
  end
  ```

  Always put the option inside the block:

  ```elixir
  view :read do
    type :data_table
    column :name
  end
  ```

- **DSL validations belong in transformers**, not verifiers. Validation
  tests use `assert_raise` + inline `defmodule`, which only catches errors
  raised during the transformer phase.
- **The `pyro_maniac do default_label :field end` block on the resource
  is required.** A verifier rejects any page whose resource lacks the
  `PyroManiac.Resource` extension.
- **Page modules are data, not views.** Do not define `render/1`, do not
  import `Phoenix.Component`, do not reference any renderer module.

## Minimal example

Resource:

```elixir
defmodule MyApp.Brewery.Recipe do
  use Ash.Resource,
    domain: MyApp.Brewery,
    extensions: [PyroManiac.Resource]

  pyro_maniac do
    default_label :name
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :status, :atom,
      constraints: [one_of: ~w[draft active retired]a],
      allow_nil?: false,
      public?: true,
      default: :draft
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :list do
      prepare build(sort: [:name])
    end
  end
end
```

Page module:

```elixir
defmodule MyAppWeb.RecipeLive do
  use PyroManiac, resource: MyApp.Brewery.Recipe

  page do
    title "Recipes"
  end

  views do
    view :read do
      type :data_table
      default_sort "name"
      column :name
      column :status
    end
  end
end
```

Navigation (optional, one module per app):

```elixir
defmodule MyAppWeb.Navigation do
  use PyroManiac.Navigation

  nav do
    group :brewery do
      label "Brewery"
      icon :beer

      item :recipes do
        path "/recipes"
        page MyAppWeb.RecipeLive
      end
    end
  end
end
```

## DSL surface — quick reference

### `page` section

`title` (required string), `description`, `route`, `default_viewer`
(`:data_table` | `:grid` | `:calendar` | `:gantt` | `:kanban` | `:list`,
default `:data_table`), `track_presence?` (default `true`).

Nested entities: `extra_action` (custom toolbar/row buttons).

### `views` section

`view :name do ... end` — `name` is one or more action names. Each view
must declare `type:`. View types and their characteristic entities:

- `:data_table` — interactive table; uses `column` entities
- `:grid` — card grid; uses `field`, `section`, `relationship`
- `:calendar` — keyed on `date_field` (+ optional `end_date_field`, `granularity`)
- `:gantt` — `start_field`, `end_field`, optional `progress_field`/`group_by`
- `:kanban` — `group_by`, `kanban_action`, `priority`
- `:list` — optional `parent_field` for tree
- `:render` — a `render` module, or `component` + `props` + `loads`
- `:delegated` — `delegate_to` another PyroManiac module (required for this type, forbidden elsewhere)

Views are recursive (`recursive_as: :views`) — nest to drill into
relationships or mount sub-Viewers.

`set` maps parent record fields into a cross-resource view's read
action when the nested view has an explicit `resource:` but no
`relationship:`.

### `forms` section

The DSL declares meaning, not styles: no `class` options and no
functions anywhere. See `forms.md` for the details.

Section schema: `description`, `exclude`.

`action :name do ... end` — single-record forms. Schema: `description`,
`label`, `max_columns`, `name` (required, atom or list), `resource`
(cross-resource), `delegate_to` (mutually exclusive with inline items).

`bulk_action :name do ... end` — multi-record forms. Adds
`set_all_fields?` (default `false`).

Input entities (common options: `label`, `description`, `autofocus`,
`path`, `size` (`:auto`/`:code`/`:term`/`:name`/`:phrase`/`:prose`),
`visible?` (an Ash expression; `parent(field)` refers to the level above)):

- `field :name` — a native control; `type` (default `:default`, inferred).
  A `field` on a `belongs_to` foreign key or on a closed set of values is
  a compile error.
- `select :name` — a closed set of values (`one_of`, `Ash.Type.Enum`, a
  new type of them, arrays); `prompt`, `options`.
- `combobox :name` — a foreign key (select mode) or a `:string` /
  `:ci_string` (free-text suggestions). Inline query: `read_action`,
  `argument :name, value` entities, `search`, `filter` (`^search()`,
  `^input(:name)`), `sort`,
  `limit`, `label_key`, `value_key`. Validated at compile time.
- `input :name, Module` or `{Module, opts}` — a custom
  `PyroManiac.Form.InputType`.

Layout entities:

- `group "Label" do ... end` — recursive; `description`, `path`,
  `density`, `max_columns`, `collapsible?`, `collapsed?`, `visible?`.
- `row do ... end` — layout only: inputs on one line (2+ children).
- `compound "Label" do ... end` — one value of tiny inputs (a value and
  its unit): a legend and one error list; `show_labels?`.
- `step :name do ... end` — wizard steps; `label`, `path`, `render`
  (a module), `review?`, `density`, `max_columns`, `visible?`.
- `set :name, :source` — only inside `action`; cross-resource form
  parent → child mapping.

### `searches` section (top-level)

`search :name do ... end` — preconfigured filter tabs. Schema:
`interactive?` (default `true`), `label`, `operator` (`:and` | `:or`).

`field :name do ... end` — `operator` (default `:contains`),
`source` (atom or `[atom | [atom]]` for OR-across-paths), `value`,
`label`.

## Extensions on resources

### `PyroManiac.Resource` (required for any page-backed resource)

```elixir
pyro_maniac do
  default_label :name   # attribute, calculation, or aggregate
end
```

A verifier checks that `default_label` exists on the resource.

### `PyroManiac.KanBan` (optional, for kanban views)

```elixir
kan_ban do
  lane :status              # required atom — must be enum or `one_of`-constrained
  priority :kanban_priority # required atom — integer; auto-created if missing
  move_action :move_card    # required atom — generated update action
  read_action :kanban_read  # required atom — generated read action
  per_lane 20               # default 20
  count? false              # default false; `true` adds count queries per lane
end
```

The transformer auto-generates the priority attribute, `move_action`,
and `read_action` if not already present. Pair with a `view :read do
type :kanban; group_by :status; kanban_action :move_card; priority
:kanban_priority` to render the board.

## Navigation

`use PyroManiac.Navigation` declares the app's nav tree. Each `item`
must have **exactly one** of `page`, `module`, or `href`. Items with
`page`/`module` require `path:`. Renderers consume the compiled tree
via `PyroManiac.Navigation.Info` (`nav_tree/1`, `route_manifest/1`,
`path_for_page/2`, etc.) and provide their own routing — this library
does **not** ship a routes generator.

## Runtime introspection

`PyroManiac.Info` is the stable runtime API renderers use:

- `resource/1`, `default_label/1`, `loads/1`
- `title/1`, `description/1`, `route/1`, `default_viewer/1`, `track_presence?/1`
- `page_extra_actions/1`, `view_extra_actions/1`
- `views/1`, `view_for/3`, `views_of_type/2`, `primary_view/2`,
  `view_for_action/2`
- `form_actions/1`, `form_actions_for_resource/2`, `form_for/2-3`,
  `form_for_action_type/2-3`
- `bulk_actions/1`, `bulk_action_for/2`
- `searches/1`

Companion `Info` modules: `PyroManiac.Resource.Info`,
`PyroManiac.Navigation.Info`, `PyroManiac.KanBan.Info`.

Do not read persisted Spark keys (`:views_by_action_and_type`,
`:route_manifest`, etc.) directly — those are internal.

## Common mistakes

- Inline keyword opts on entities with `do` blocks (`view :read, type:
:data_table do ...`) — fails to compile.
- Defining `render/1` or importing renderer modules in a page module.
- Forgetting `PyroManiac.Resource` in the resource's `extensions:` list.
- `default_label` pointing at a relationship — renderers cannot stringify it.
- Multiple of `page`/`module`/`href` on one nav item — validator rejects.
- `set` inside a `bulk_action` — only valid inside `action`.
- `field` on a foreign key or an enum (use `combobox` / `select`), or an
  unknown `type:` (use an `input` type module).
- A `class`, `input_class`, `cell_class`, or `render_fn` option, or a
  function for `visible?`/`render`. Use `size`, `density`, `tone`, an Ash
  expression, or a render module.
- A read action on a resource only for a combobox. Declare the query in
  the combobox.
- Mixing `delegate_to` with inline fields/groups/steps on `action`/
  `bulk_action` — they're mutually exclusive.
