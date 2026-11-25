---
name: pyro-maniac
description: Use this skill when defining or modifying PyroManiac DSL on Ash resources or PyroManiac page modules.
---

# PyroManiac

PyroManiac is a declarative, framework-agnostic UI DSL for Ash Framework
resources. It compiles UI configuration at build time via Spark and exposes
it through `PyroManiac.Info` for renderers to consume. Rendering itself
lives in separate libraries; the core package is render-agnostic by design.

## Non-negotiable rules

- **Never** import or reference renderer or web framework modules from
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
- **Every action interface is authorized with the scope.** No exceptions:
  never `authorize?: false` in UI code. A UI decides what it shows with
  `Ash.can?(subject, scope, maybe_is: true, run_queries?: false)` on the
  server, or with AshTypescript on a client. That answer is exact only when
  the strict check decides the policy: put the simple checks of the actor
  (a role, an active account) before the expression checks, and forbid an
  absent actor in a strict policy (`documentation/tutorials/policies.md`).

## Minimal example

Resource:

```elixir
defmodule Brewery.Recipe do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource]

  pyro_maniac do
    default_label :name

    expose [:read, :list]
    expose [:create, :update, :destroy]
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
defmodule BreweryWeb.RecipeLive do
  use PyroManiac, resource: Brewery.Recipe

  page do
    title "Recipes"
    route "/recipes"                    # required: the URL path of the page
    exclude [:list]
  end

  view :read do
    type :data_table
    primary? true
    default_sort "name"
    exclude [:id]
    column :name
    column :status

    action :create, :guard do
      delegate_to BreweryWeb.RecipeLive   # the form of the card below
    end

    action :destroy, :discard do           # no inputs: a confirmation
      confirm "Delete the recipe?"
    end
  end

  view :read do
    type :card
    primary? true
    action [:create, :update], :guard     # the tree of the card is their form

    section :recipe do
      field :name, autofocus: true
      select :status
    end
  end
end
```

Navigation (optional, one module per app):

```elixir
defmodule BreweryWeb.Navigation do
  use PyroManiac.Navigation

  nav do
    group :brewery do
      label "Brewery"
      icon :beer

      item :recipes do
        page BreweryWeb.RecipeLive        # opens the route of the page
      end
    end
  end
end
```

## DSL surface — quick reference

A page module has the `page` section and the top-level entities `view` and
`search`. There is no `views do` block and no `forms` section: the actions
are in the views.

The `page` section is optional. A module with it is a page
(`PyroManiac.Info.page?/1`): it has a route, and the renderer routes it. A
module without it is not a page: it declares views and searches that the
pages reuse, has no route, and is never routed; the check of the exposed
actions (and `exclude`) does not apply to it.

### `page` section

`title` (default: the plural or short name of the resource), `route`
(required; the URL path, starts with `/`; the navigation does not set it),
`track_presence?` (default `false`), `exclude` (the exposed actions that the
page does not use), and the filters: `custom_filters?` (default `false`;
the user builds filters in the advanced filter view), `filter_storage`
(`:client`, or a resource with `PyroManiac.FilterPresets`; requires
`custom_filters? true`), `shared_filters?` (default `false`; requires a
resource storage, whose policies control the sharing).

Each exposed action of the resource (read, create, update, destroy,
generic) is used by a view or is in `exclude`. `exclude` names exposed
actions only. This check runs last.

Nested entities: `description` (`description "text"`, and `description
Renderer, implementation` for one renderer; no expression, no page-level
`render`), `extra_action` (custom toolbar/row buttons; one `render R,
Impl` for each renderer renders the button and the content).

Each exposed action is used by the name of a view (a read action, also
one with public arguments), an `action`, a `bulk_action`, the `action` of
a column, or `edit_columns`.

### `view`

`view :name do ... end` — `name` is one or more read action names. Each
view must declare `type:`. View types and their characteristic entities:

- `:data_table` — interactive table; `column` entities (a column can have
  an inline edit), `edit_columns`
- `:grid` — card grid; its own record tree, or `card? true` (the tree of
  the primary card)
- `:card` — one record (a single view): its own record tree (required);
  `action [:create, :update]` without nodes makes that tree their form;
  `presentation`. A page can have several cards
- `:calendar` — keyed on `date_field` (+ optional `end_date_field`, `granularity`)
- `:gantt` — `start_field`, `end_field`, optional `progress_field`/`group_by`
- `:kanban` — `group_by`, `kanban_action`, `priority`, and `default_sort`
  come from the `kan_ban` section of the resource (setting them is an error)
- `:list` — optional `parent_field` for tree
- `:timeline` — the records as events in time order: `date_field`
  (required), `end_date_field` (a span); the content is the record tree
- `:render` — `render Renderer, implementation` (required, one for each
  renderer) and `loads`

View options: `clone? true` (a Clone action for each record: a prefilled
create form; the view names a create action), `new_row? true`
(`:data_table` only: an inline new row; the view names a create action,
and each required input of it is a column inline edit `action :create,
:discard do <input> end`), `reorder? true` (`:data_table`, `:grid`,
`:list`: drag to reorder when sorted by the rank; the resource has
`PyroManiac.Ordering` or `PyroManiac.KanBan`; the move action counts as
used).

The record tree is the nodes of the view: `field`, `select`, `combobox`,
`input`, `section`, `row`, `compound`, `related`, `attachments`,
`workflow`, `tabs`/`tab`, `step`. A `:list`, `:kanban`, `:calendar`,
`:gantt`, or `:timeline` view has top-level `field` entities; `path` gives a related value (`field :name, path:
[:recipe]`, no `source`). View mode is the read action of the view. A view
that names no write action has no inputs (`field` only).

`only [names]` limits a node to some actions: the read action of the view
(view mode, `only [:read]`) and the actions of the tree (`only [:create]`).
The names are checked.

Primary views: each page needs `primary? true` on a `:card` (the primary
single view). At most one list view can have `primary? true` (the primary
list view); without one, the primary card is also the primary list view.
A `:render` view is not primary. The card URL param is `card=<id>` (the
primary card) or `card=<view>:<id>` (another card).

Views do not nest. The related records of a record are `related` nodes of
its record tree.

Links: `link_to Page` on columns, fields, comboboxes, and `related`
navigates to another page. One for each node; a node without it has no
link. Options in a `do` block: `single_view :name` (a `:card` view;
default the primary single view) and `list_view :name` (default the
primary list view; relationships to many only). On `related`, each record
links to its single view, and a list link opens the list view filtered by
the relationship.

Content (`PyroManiac.Content`): `render`, `description`, and the `label`
of a column are entities with three forms: `"text"` and `expr(...)` (an
Ash expression on the record) for every renderer, and `Renderer,
implementation` for one renderer (it overrides the text or the
expression). At most one text or expression, and one implementation for
each renderer. A node with a text or an expression satisfies every
renderer.

```elixir
column :status do
  label "Stage"
  description "The production stage of the batch."
  render expr(if status == :cancelled, do: "Cancelled", else: "In production")
  render PyroManiac.LiveView, BreweryWeb.Cells.Status
end

field :notes do
  type :textarea
  description :inherit     # the description of the attribute
end
```

- `render` on views, columns, the values of the record tree, compounds,
  sections, steps, `tabs`/`tab`, `related`, and extra actions. The inputs
  (`field`, `select`, `combobox`, `input`) take `render Renderer,
  implementation` only.
- `description` on views, columns, inputs, sections, compounds, steps,
  actions, bulk actions, `related`, `attachments`, and the page. Not a
  keyword option. `description :inherit` (views, columns, inputs, actions, bulk actions)
  takes the description of the attribute, argument, or action.
- `label` is an entity on columns only (default: the capitalized name);
  the other nodes have a `label` option.
- A view and the page have no record: no expression in their own
  `render` or `description`. The refs of an expression are validated and
  loaded with the record.
- An implementation is any term that the renderer validates; wrap a
  keyword list in a tuple (`{Mod, props: [...]}`). Refer to
  `documentation/tutorials/custom-renders.md` and the renderer guides in
  `documentation/renderers/`.

### The actions of a view

The DSL declares meaning, not styles: no `class` options and no
functions anywhere. See `forms.md` for the details.

`action name_or_names, state` — a create, update, destroy, or generic
action of the resource. `state` is required, with no default: the optional
second argument (`action :update, :guard`) or `state :guard` in the block.
`:guard` warns before the user leaves with unsaved changes, `:recover`
restores the inputs after a reload or a lost connection, `:discard` does
neither; renderers implement guard and recovery. Schema: `label`,
`confirm` (a text, or an Ash expression on the record that gives a message
or `nil`; its refs are validated and loaded), `presentation` (`:modal`,
`:drawer`, `:page`), `max_columns`, `resource` (cross-resource, with
`set`), `delegate_to` (mutually exclusive with nodes). Entity:
`description` (`:inherit` takes the description of the action).

- In a card without nodes: the tree of the card is the form.
- With nodes: its own tree (a button opens it).
- `delegate_to Page`: the tree of the same action in a view of that page
  (this page: the tree of its card).
- In a list view: its own tree or `delegate_to`; an action without inputs
  (a destroy, a status change) is a confirmation with no tree.
- In a column: `column :status do action :update, :discard do select
  :status, autofocus: true end end` (one for each column; inputs only:
  `field`, `select`, `combobox`, `input`, `compound`; no `delegate_to`, no
  `resource`; no completeness or `autofocus` check). `edit_columns :update,
  [:target_og, :target_fg], :discard do ... end` edits some cells of a row
  together (the state is the third argument).

Completeness: the form of each action has each accepted attribute and each
public argument (or a `set`), and exactly one `autofocus` when it has
inputs.

`bulk_action :name, state do ... end` in a list view — the selected rows.
Takes `state` and `confirm` as `action`, and `set_all_fields?` (default
`false`). A bulk action uses its action (no `exclude` needed).

Input entities (common options: `label`, `autofocus`, `path`, `size`
(`:auto`/`:code`/`:term`/`:name`/`:phrase`/`:prose`), `only`, `decoration`
(a decoration or an Ash expression; the set is `config :pyro_maniac,
decorations: [...]`, default `[:neutral, :info, :success, :warning,
:danger]`),
`empty_text`, `visible?` (an Ash expression; `parent(field)` refers to the
level above); entities: `description`, `render`):

- `field :name` — a value, or a native control; `type` (default
  `:default`, inferred). A `field` input on a `belongs_to` foreign key or
  on a closed set of values is a compile error.
- `select :name` — a closed set of values (`one_of`, `Ash.Type.Enum`, a
  new type of them, arrays); `prompt`, `options`.
- `combobox :name` — a foreign key (select mode), an argument that the
  action passes to `manage_relationship` such as a `many_to_many` (select
  many: attach and detach; `__multiple?__: true`), or a `:string` /
  `:ci_string` (free-text suggestions). Inline query: `read_action`,
  `argument :name, value` entities, `search`, `filter` (`^search()`,
  `^input(:name)`), `sort`,
  `limit`, `label_key`, `value_key`. Validated at compile time.
- `input :name, Module` or `{Module, opts}` — a custom
  `PyroManiac.Form.InputType`.

Layout entities:

- `section :name do ... end` — recursive; `label` (default the humanized
  name), `description` (entity), `path`, `density`, `max_columns`, `collapsible?`,
  `collapsed?`, `only`, `visible?`, and `render`.
- `row do ... end` — layout only: inputs or sections on one line (2+ children).
- `tabs do tab :name do ... end end` — one, last at the top level; `count`.
- `related :rel do ... end` — read-only records; `delegate_to` (a
  delegated viewer) or `type` (`:list`, `:data_table`, `:grid`, `:count`,
  `:badge`); `presentation` (`:inline`, `:modal`, `:drawer`), `count`,
  `limit`, `link_to`, `description`, `render`, `visible?`.
- `attachments :name` — the files of an AshStorage attachment; `label`,
  `description`, `only`, `visible?`.
- A `field` that is not an input of the action is read-only.
- `compound :name do ... end` — one value of tiny inputs (the OG and the
  FG of a batch): `label` (the legend), `description`, one error list;
  `show_labels?`; `render`.
- `step :name do ... end` — wizard steps; `label`, `description` (entity), `path`,
  `review?`, `density`, `max_columns`, `visible?`, and `render` entities.
- `set :name, :source` — only inside `action`; cross-resource form
  parent → child mapping, set on submit (no input). With `overridable?:
  true`, set when the form opens; the user can change it in an input of
  that name (required).
- `workflow do ... end` — the status of AshStateMachine or AshWorkflow
  (an error if the resource uses neither): `type` (`:steps` | `:badge`),
  `transitions?` (default `true`: buttons for the available transitions
  that are actions of the view), `history` (a relationship to the
  transition log, as a timeline), `label`, `only`, `visible?`,
  `description`, `render`. `PyroManiac.Workflow` gives `engine/1`,
  `state_attribute/1`, `states/1`, `loads/1`.

### `search` (top level)

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
  lane :status              # required entity, exactly one — an enum/`one_of` attribute, or a `belongs_to`
  priority :kanban_priority # required atom — string (fractional index); auto-created
  move_action :move_card    # required atom — generated update action
  read_action :kanban_read  # required atom — generated read action
  per_lane 20               # default 20
  count? false              # default false; `true` adds count queries per lane
end

# dynamic lanes (a `belongs_to`); these options on an attribute lane: compile error
lane :stage do
  read_action :read         # default: the primary read of the lane resource (required)
  create_action :create     # default: the primary create, else none; `false`: off
  update_action :update     # default: the primary update, else none; `false`: off
  destroy_action :destroy   # default: the primary destroy, else none; `false`: off
  move_action :move         # moves the lanes; default: the move of an ordered lane resource, else none; `false`: off
  sort "position"           # default: the rank of an ordered lane resource
end
```

The transformer auto-generates the priority attribute, `move_action`,
and `read_action` if not already present. Pair with a `view :kanban_read do
type :kanban end` to render the board: the view takes `group_by`,
`kanban_action`, `priority`, and `default_sort` from the `kan_ban`
section. An existing action with the name of `move_action` or
`read_action` is a compile error. The order uses the shared ordering setup
of `PyroManiac.Ordering`.

Static lanes are the values of an attribute. Dynamic lanes are the records
of the destination of a `belongs_to` lane: the cards are ordered by its
foreign key (`PyroManiac.KanBan.Info.lane_attribute!/1`), and a card with a
`nil` foreign key is in "No lane". `PyroManiac.KanBan.Info.lanes/2` reads
the lanes (`query:` for the lanes of one scope, such as one project).
The lane actions are resolved at compile time on the lane resource: a
named action that it does not have, or of another type, is a compile
error. `PyroManiac.KanBan.Info.lane_action/2` gives each one (`nil`: the
board does not add, edit, delete, or move lanes). The `move_action` of the
`lane` moves the lanes; the `move_action` of the `kan_ban` section moves
the cards.

### `PyroManiac.KanBan.Lanes` (optional, a resource of dynamic lanes)

```elixir
kan_ban_lanes do
  scope :project_id   # optional — each project has its own lanes
  position :position  # default :position — the rank attribute
  move_action :move   # default :move — the update action that moves a lane
end
```

Adds (unless present) `id`, `name`, `decoration`, the ordering of the
lanes, and the primary `read`, `create`, `update`, `destroy` actions, plus
the move action. Create and update accept `name`, `decoration`, and the
`scope`.

### `PyroManiac.Ordering` (optional, for `reorder? true`)

```elixir
ordering do
  attribute :position         # required: the rank (:string, COLLATE "C"); auto-created
  scope :recipe_id            # optional: records with their own order
  algorithm :fractional_index # default
  move_action :move           # default; generated update action
end
```

Adds the rank attribute, a unique index (scope, rank), the rank of a new
record (end of its scope), and the move action (context
`:order_target_id`, `:order_position` `"before"`/`"after"`/`"last"`). The
rank is computed in Postgres (`PyroManiac.KanBan.PostgresExtension`
version 3 in the `installed_extensions` of the repo).
`PyroManiac.Ordering.Info.ordering/1` reads it (also for a kanban
resource).

### `PyroManiac.FilterPresets` (optional, for `filter_storage`)

```elixir
filter_presets do
  owner MyApp.User            # belongs_to :owner, related to the actor on create
end
```

Adds `id`, `name`, `page`, `view`, `filter` (map), `sort`, `inputs` (map),
`interactive?`, `shared?`, the timestamps, and the actions `read`,
`create`, `update`, `destroy`, and `for_page` (argument `page`). Its
policies control who reads and shares the presets.

## Navigation

`use PyroManiac.Navigation` declares the app's nav tree. Each `item`
must have **exactly one** of `page`, `module`, or `href`. A `page` item has
no `path` (a compile error): it opens `PyroManiac.Info.route/1` of its page,
which is a module with a `page` section and a route without parameters
(`:id`, `*glob`). A `module` item requires `path`; an `href` item has none.
Groups are not part of a route. No two routes (page routes and module
paths) overlap: one URL matches both when each pair of segments is equal
or either is a `:param`, up to a `*glob` (`"/recipes/:id"` overlaps
`"/recipes/new"`). Items and groups have `decoration` (no
`class`). The `command_palette` section (`enabled?` default `true`,
`hotkey` default `"mod+k"`, `navigation?` default `true`, `placeholder`
default `"Search"`) has `command :name` entities (`label`, `description`,
`group`, `keywords`, `icon`, `authorizer`, and exactly one target: `page`
(opens the route of the page; an optional `path` starts with it, e.g.
`"/recipes?new"`), `module` + `path`, `href`, or `render`). Renderers consume the compiled tree
via `PyroManiac.Navigation.Info` (`nav_tree/1`, `route_manifest/1`,
`path_for_page/2`, etc.) and provide their own routing — this library
does **not** ship a routes generator.

## Runtime introspection

`PyroManiac.Info` is the stable runtime API renderers use:

- `resource/1`, `default_label/1`, `default_label_load/1`
- `title/1` (with its default), `description/1` (the `description`
  entities of the page), `page?/1`, `route/1` (a renderer declares the
  routes of the pages from it), `track_presence?/1`,
  `custom_filters?/1`, `filter_storage/1`, `shared_filters?/1`
- `page_extra_actions/1`, `view_extra_actions/1`
- `views/1`, `view_for/3`, `views_of_type/2`, `primary_single_view/1`,
  `primary_list_view/1`, `named_views/3`, `view_for_action/2`
- `actions/1` (all action entities, card ones first, each with `__view__`,
  `__column__`, `__columns__`), `actions/2` (page, view), `action_for/2-3`,
  `actions_for_resource/2`, `action_for_type/2-3`
- `bulk_actions/1`, `bulk_action_for/2`
- `form_fields/1`, `form_layout/1`
- `searches/1`

`PyroManiac.Card.tree/1` (the resolved view-mode tree of a view),
`PyroManiac.Card.actions/1` (the actions of the primary card),
`PyroManiac.Card.tabs/1`, and `PyroManiac.Card.paths/2`.
`PyroManiac.Form.Tree.for_action/2` and `in_action?/2` filter a tree by
`only`. `PyroManiac.Card.param/3` and `parse_param/2` encode and decode the
`card` param. `PyroManiac.Content.resolve(entries, renderer)` reads a
`render`, a `description`, or a column `label`: `{:impl, x}`, else
`{:text, s}` or `{:expr, e}`, else `nil` (`PyroManiac.Render.resolve/2`
delegates to it; `Content.portable/1`, `Content.text/1`, `Content.refs/1`).
`PyroManiac.Render.implementation/2` gives only the implementation of a
renderer, and `PyroManiac.Render.verify/3` is for the verifier of a
renderer (it skips the nodes with a text or an expression).

Companion `Info` modules: `PyroManiac.Resource.Info`,
`PyroManiac.Navigation.Info` (with `command_palette/1`),
`PyroManiac.KanBan.Info` (with `lanes/2` and the dynamic lane functions),
`PyroManiac.Ordering.Info`.
`PyroManiac.View.decoration/3` evaluates a decoration for a record.

Do not read persisted Spark keys (`:views_by_action_and_type`,
`:route_manifest`, etc.) directly — those are internal.

## Common mistakes

- Inline keyword opts on entities with `do` blocks (`view :read, type:
:data_table do ...`) — fails to compile.
- `views do`, `forms do`, `searches do`, or `form :update` on a card
  (removed). `view` and `search` are top level; a card has its own tree
  and `action [:create, :update]`.
- An exposed action that no view uses and that is not in `page do exclude
  [...] end`.
- An action with inputs in a list view without nodes or `delegate_to`.
- A form that misses an accepted attribute or public argument, or without
  exactly one `autofocus`.
- `only :view` / `only :edit` (removed). Use `only [:read]` /
  `only [:create, :update]`.
- `edit_with` on a column (removed). Use `action :update do <inputs> end`
  in the column, or `edit_columns`.
- `source` on a `field` of a view. Use `path`.
- `Info.form_for/2`, `Info.form_actions/1`, `Card.form/1`,
  `Tree.for_mode/2`, or `PyroManiac.View.Section`/`Compound`/`Row`/`Set`
  (removed). Use `Info.action_for/2`, `Info.actions/1`,
  `Card.actions/1`, `Tree.for_action/2`, and the `PyroManiac.Form`
  entities.
- Defining `render/1` or importing renderer modules in a page module.
- Forgetting `PyroManiac.Resource` in the resource's `extensions:` list.
- `default_label` pointing at a relationship — renderers cannot stringify it.
- Multiple of `page`/`module`/`href` on one nav item — validator rejects.
- A `page` section without `route`, a `path` on a `page` nav item, a nav
  item whose `page` has no `page` section or a route with parameters, or
  two overlapping routes — compile errors.
- `set` inside a `bulk_action` — only valid inside `action`.
- `field` input on a foreign key or an enum (use `combobox` / `select`), or
  an unknown `type:` (use an `input` type module).
- A `class`, `input_class`, `cell_class`, or `render_fn` option, or a
  function for `visible?`/`render`. Use `size`, `density`, `decoration`,
  an Ash expression, or `render Renderer, implementation`.
- `tone` (renamed `decoration`), or `recover?`/`guard?` (use `state`).
- An `action`, `bulk_action`, or `edit_columns` without a `state`.
- `set ..., overridable?: true` without an input of that name.
- `clone?`/`new_row?` without a create action in the view, or `reorder?`
  on a resource without `PyroManiac.Ordering` or `PyroManiac.KanBan`.
- `filter_storage` without `custom_filters? true`, or `shared_filters?
  true` with `filter_storage :client`.
- A page without `primary? true` on a `:card`, or `default_viewer` (removed).
- Removed DSL: nested views, `relationship`/`lazy?`/`multiple?`/`set` on
  views, `:delegated` views, card `key`, `link_to false`, `type`/`action`
  on `link_to`, the resource-level `link_to`, `link_through`, `display` on
  `related` (now `type`), `component`/`props` on `:render` views, and the
  `button`/`render` options of `extra_action`.
- `section "Title" do`. Use `section :title do` (add `label` only when the
  humanized name differs).
- A read action on a resource only for a combobox. Declare the query in
  the combobox.
- Mixing `delegate_to` with inline nodes on `action`/`bulk_action` —
  they're mutually exclusive.
- `description: "..."` as a keyword, or `label:` on a column. Both are
  entities: `field :notes do description "..." end`, `column :abv do
  label "ABV" end`.
- `render` in the `page` section, `Info.description_render/1` (removed), or
  an expression in the description of the page or the own content of a
  view. Use `description "text"` / `description Renderer, implementation`.
- `render "text"` or `render expr(...)` on an input. Use `render Renderer,
  implementation`.
