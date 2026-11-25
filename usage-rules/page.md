# Page modules

A PyroManiac page module binds an Ash resource and configures the UI for
that resource. The compiled module is consumed at runtime by a renderer
through `PyroManiac.Info`.

## Defining a page

```elixir
defmodule BreweryWeb.RecipeLive do
  use PyroManiac, resource: Brewery.Recipe

  page do
    title "Recipes"
    route "/recipes"
    exclude [:list, :activate, :retire, :destroy]
  end

  view :read do
    type :data_table
    primary? true

    exclude [:id, :description, :target_abv, :target_og, :target_fg, :gravity_spread,
             :ingredient_count, :batch_count, :recipe_ingredients, :batches, :photos,
             :photos_urls]

    column :name
    column :style
    column :status

    action :create, :guard do
      delegate_to BreweryWeb.RecipeLive
    end
  end

  view :read do
    type :card
    primary? true
    action [:create, :update], :guard

    section :recipe do
      field :name, autofocus: true
      select :style
      select :status
      field :description, type: :textarea
    end

    section :targets do
      field :target_abv
      field :target_og
      field :target_fg
    end
  end
end
```

- `view` is a top-level entity: there is no `views do` block and no
  `forms` section. The actions are in the views (refer to `views.md` and
  `forms.md`).
- Each page needs `primary? true` on a `:card` view: the primary single
  view. A link to the page opens it (refer to `views.md`).
- Each exposed action of the resource is used by a view or is in `page do
  exclude [...] end`.
- The `page` section makes the module a page (`PyroManiac.Info.page?/1`),
  and `route` is required in it. The route is in the page, not in the
  navigation: a navigation item with `page` opens it.
- A module without the `page` section is not a page: it has no route, a
  renderer does not route it, and a navigation item cannot open it. It
  declares views and searches that the pages reuse (for example a
  `delegate_to` target). The check that each exposed action is used, and
  `exclude`, apply to pages only.
- The `resource:` option is required. It must be a valid Ash resource that
  uses `PyroManiac.Resource` (a verifier rejects pages whose resource lacks
  the extension).
- The page module name is what you reference from `PyroManiac.Navigation`
  items (`page BreweryWeb.RecipeLive`), links (`link_to BreweryWeb.RecipeLive`),
  and delegated viewers (`related :recipe do delegate_to BreweryWeb.RecipeLive end`).
- Do not add `def render(...)` or any rendering code. The module is data;
  rendering belongs to the renderer library.

## The `page` section

The `page` section configures page-level metadata. Schema:

| Key               | Type                                                                        | Default       | Notes                                                              |
| ----------------- | --------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------ |
| `title`           | `:string`                                                                   | the plural (or short) name of the resource, humanized | Document title and page header |
| `exclude`         | `[atom]`                                                                    | `[]`          | The exposed actions of the resource that the page does not use     |
| `route`           | `:string`                                                                   | required      | URL path, starts with `/` (e.g. `"/recipes"`). The renderer declares the route from it. A navigation item needs a route without parameters |
| `track_presence?` | `:boolean`                                                                  | `false`       | Presence: the viewers of this page; the editors of each record, from any page |
| `custom_filters?` | `:boolean`                                                                  | `false`       | The user builds filters (the advanced filter view)                 |
| `filter_storage`  | `:client` or a `PyroManiac.FilterPresets` resource                          | nil           | Where the built filters are saved. Requires `custom_filters? true` |
| `shared_filters?` | `:boolean`                                                                  | `false`       | A user can share a saved filter. Requires a resource storage       |

Entities: `description` and `extra_action`.

```elixir
page do
  title "Recipes"
  description "Browse all brewing recipes."
  description PyroManiac.LiveView, BreweryWeb.RecipeLive.Intro
  route "/recipes"
  exclude [:list, :activate, :retire]
end
```

`description` is the text below the title: `description "text"` for every
renderer, and `description Renderer, implementation` for one renderer (it
overrides the text). The page has no record: no expression. At most one
text, and one implementation for each renderer. The page-level `render`
entity is removed. `PyroManiac.Info.description/1` gives the `description`
entities; a renderer reads them with `PyroManiac.Content.resolve/2`.

`exclude` names exposed actions only (read, create, update, destroy,
generic). Each exposed action is used by a view (the name of a view for a
read action; `action`, `bulk_action`, the `action` of a column, or
`edit_columns` for the others), or is in `exclude`. An excluded action that
a view uses is an error. The check runs after the other checks of the page,
so their errors show first. The AshStorage actions of an attachment are not
checked.

The initial view is the primary list view (`primary? true` on a view), not
a page option.

## Filters

Every list view has the same filter experience: the `search` presets as
simple chips (refer to [searches](searches.md)) and, with
`custom_filters? true`, the advanced filter view, where the user builds
filters on the filterable fields of the view.

```elixir
page do
  route "/batches"
  custom_filters? true
  filter_storage Brewery.FilterPreset
  shared_filters? true
end
```

- `filter_storage :client` saves the built filters in the client (for
  example the local storage of a browser). A resource with the
  `PyroManiac.FilterPresets` extension saves them as records (refer to
  [filter_presets](filter_presets.md)). Without it, they are not saved.
  `filter_storage` requires `custom_filters? true`.
- `shared_filters? true` lets a user share a saved filter. It requires a
  resource in `filter_storage`; the policies of that resource control who
  reads and writes each preset.
- A verifier warns when the storage resource lacks the extension.
- `PyroManiac.Info.custom_filters?/1`, `filter_storage/1`, and
  `shared_filters?/1` read them.

## Custom toolbar buttons: `extra_action`

`extra_action` adds a custom action button rendered by the renderer in
the page toolbar, on data table rows, or on cards.

```elixir
page do
  title "Recipes"
  route "/recipes"

  extra_action :export_csv do
    label "Export CSV"
    render PyroManiac.LiveView, BreweryWeb.RecipeLive.ExportAction
    render PyroManiac.Solid, "~/actions/ExportCsv"
  end
end
```

Schema:

| Key     | Type      | Notes                      |
| ------- | --------- | -------------------------- |
| `name`  | `:atom`   | Required. Unique identifier |
| `label` | `:string` | Required. Display text      |

`render Renderer, implementation` entities, one for each renderer. The
implementation renders the whole action: its button and its content (a
modal, a panel). It gets `:action`, `:base_path`, `:params`, and (on a row)
`:row`.
Without them, the renderer uses its default link/action treatment. The
`button` and `render` options are removed. The renderer validates the
implementation (refer to the renderer guide,
`documentation/renderers/renderer-custom-renders.md`).
The DSL holds no functions.

## Common mistakes

- **Inline keyword options on entities with `do` blocks fail to compile.**
  Spark cannot parse `view :read, type: :data_table do ... end`. Always
  use the entity macro inside the block.
- **Forgetting `PyroManiac.Resource` on the resource.** The `pyro_maniac`
  resource block is required; missing it raises a verifier error from
  `PyroManiac.Dsl.Verifiers.ResourceHasExtension`.
- **Mixing render concerns into the page module.** Do not import
  `Phoenix.Component` or define `render/1` in the page module. The page
  module exists only to configure data. Custom rendering goes in a
  separate module (it can be nested in the page module), and a `render
  Renderer, implementation` entity refers to it.
- **A function in the DSL** (`render &fun/1`, `when fn ... end`). Use a
  `render` entity, or an Ash expression for `visible?` and `decoration`.
- **`filter_storage` without `custom_filters? true`, or `shared_filters?
  true` with `filter_storage :client`.** Both are compile errors.
- **`default_viewer`.** It is removed: set `primary? true` on a view.
- **`render` in the `page` section, or `description expr(...)`.** The page
  description is `description "text"` and `description Renderer,
  implementation`.
- **A page without a primary card.** Set `primary? true` on a `:card`
  view.
- **`views do` or `forms do`.** They are removed: `view` is top level, and
  the actions are in the views.
- **An exposed action that no view uses.** Name it in a view, or add it to
  `page do exclude [...] end`.
- **A `page` section without `route`.** `route` is required in it. A
  module that only declares views and searches for other pages has no
  `page` section.
- **The route in the navigation.** A navigation item with `page` has no
  `path`: it opens the `route` of the page.
