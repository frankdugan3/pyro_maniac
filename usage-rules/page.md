# Page modules

A PyroManiac page module binds an Ash resource and configures the UI for
that resource. The compiled module is consumed at runtime by a renderer
through `PyroManiac.Info`.

## Defining a page

```elixir
defmodule MyAppWeb.RecipeLive do
  use PyroManiac, resource: MyApp.Brewery.Recipe

  page do
    title "Recipes"
  end

  views do
    view :read do
      type :data_table
      column :name
      column :style
      column :status
    end
  end
end
```

- The `resource:` option is required. It must be a valid Ash resource that
  uses `PyroManiac.Resource` (a verifier rejects pages whose resource lacks
  the extension).
- The page module name is what you reference from `PyroManiac.Navigation`
  items (`page MyAppWeb.RecipeLive`) and from delegated views
  (`delegate_to MyAppWeb.RecipeLive`).
- Do not add `def render(...)` or any rendering code. The module is data;
  rendering belongs to the renderer library.

## The `page` section

The `page` section configures page-level metadata. Schema:

| Key               | Type                                                                        | Default       | Notes                                                              |
| ----------------- | --------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------ |
| `title`           | `:string`                                                                   | required      | Document title and page header                                     |
| `description`     | `:string` or render fn                                                      | nil           | Rendered below the title                                           |
| `route`           | `:string`                                                                   | nil           | URL path (e.g. `"/recipes"`, `"/recipes/:id"`). Renderer uses this |
| `default_viewer`  | `:data_table` \| `:grid` \| `:calendar` \| `:gantt` \| `:kanban` \| `:list` | `:data_table` | Initial viewer when the page has multiple                          |
| `track_presence?` | `:boolean`                                                                  | `true`        | Toggle presence tracking via the configured presence backend       |

```elixir
page do
  title "Recipes"
  description "Browse all brewing recipes."
  route "/recipes"
  default_viewer :data_table
end
```

## Multi-tenancy: `tenant_from`

`tenant_from` is a singleton entity inside the `page` section. It declares
how the renderer should resolve the active tenant.

```elixir
page do
  title "Recipes"

  tenant_from :scope
end
```

Modes:

- `:scope` — Tenant is set by the Ash scope (plug, hook, etc.). No selector UI.
- `:select` — Renderer renders a `<select>` populated from a tenant resource.
- `:combobox` — Same as `:select` but renderer should use a searchable combobox.

`:select` and `:combobox` require additional keys:

```elixir
tenant_from :select do
  resource MyApp.Accounts.Organization
  label_field :name
  param "org"
  read_action :read_active
end
```

| Key           | Required when         | Notes                                          |
| ------------- | --------------------- | ---------------------------------------------- |
| `resource`    | `:select`/`:combobox` | Tenant resource to read from                   |
| `label_field` | `:select`/`:combobox` | Display field on the tenant resource           |
| `param`       | optional              | URL query parameter name (default `"tenant"`)  |
| `read_action` | optional              | Read action to load tenants (default: primary) |

## Custom toolbar buttons: `extra_action`

`extra_action` adds a custom action button rendered by the renderer in
the page toolbar, on data table rows, or on cards.

```elixir
page do
  title "Recipes"

  extra_action :export_csv do
    label "Export CSV"
  end
end
```

Schema:

| Key      | Type      | Notes                                                                                            |
| -------- | --------- | ------------------------------------------------------------------------------------------------ |
| `name`   | `:atom`   | Required. Unique identifier                                                                      |
| `label`  | `:string` | Required. Display text                                                                           |
| `button` | render fn | Optional. Custom button renderer; receives `:action`, `:base_path`, `:params`, optionally `:row` |
| `render` | render fn | Optional. Renders the action target (modal, panel, etc.) with the same assigns                   |

If neither `button` nor `render` is supplied, the renderer uses its
default link/action treatment.

## Common mistakes

- **Inline keyword options on entities with `do` blocks fail to compile.**
  Spark cannot parse `view :read, type: :data_table do ... end`. Always
  use the entity macro inside the block.
- **Forgetting `PyroManiac.Resource` on the resource.** The `pyro_maniac`
  resource block is required; missing it raises a verifier error from
  `PyroManiac.Dsl.Verifiers.ResourceHasExtension`.
- **Mixing render concerns into the page module.** Do not import
  `Phoenix.Component`, define `render/1`, or reference renderer modules.
  The page module exists only to configure data.
