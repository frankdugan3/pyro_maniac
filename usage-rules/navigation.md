# Navigation

`PyroManiac.Navigation` declares an app's navigation tree as a single
Spark DSL module. It compiles to a tree (groups + items) plus a flat
route manifest, both available via `PyroManiac.Navigation.Info`. The
core library does **not** generate routes or render markup —
that's the renderer's job. Each renderer (e.g. `pyro_maniac_live_view`)
provides its own routing macro and layout components.

## Defining a navigation module

```elixir
defmodule MyAppWeb.Navigation do
  use PyroManiac.Navigation

  nav do
    item :home do
      path "/"
      module MyAppWeb.HomeLive
      image "/images/logo.svg"
      image_alt "Acme Brewery"
    end

    group :brewery do
      label "Brewery"
      icon :beer

      item :recipes do
        path "/recipes"
        page MyAppWeb.RecipeLive
      end

      item :batches do
        path "/batches"
        page MyAppWeb.BatchLive
      end
    end

    item :docs do
      href "https://docs.example.com"
      label "Docs"
      icon :book
    end
  end
end
```

## `item`

Each item must have **exactly one** of `page`, `module`, or `href`:

| Key         | Notes                                                            |
| ----------- | ---------------------------------------------------------------- |
| `name`      | Required atom. Unique identifier                                 |
| `path`      | Required for `page`/`module`. Must start with `/`                |
| `label`     | Display text. Defaults to capitalized name                       |
| `icon`      | Atom passed to the renderer (e.g. `:beer`, `:home`)              |
| `image`     | Path/URL to an image (e.g. logo). Mutually exclusive with `icon` |
| `image_alt` | Alt text for the image                                           |
| `page`      | A PyroManiac page module — validated, authorization-aware        |
| `module`    | A non-PyroManiac module — always visible                         |
| `href`      | External URL — opens in a new tab. No `path` required            |

Examples:

```elixir
# A PyroManiac page
item :recipes do
  path "/recipes"
  page MyAppWeb.RecipeLive
end

# A non-PyroManiac module (e.g. a custom dashboard)
item :dashboard do
  path "/dashboard"
  module MyAppWeb.DashboardLive
end

# An external link
item :docs do
  href "https://docs.example.com"
  label "Docs"
end
```

## `group`

Groups are collapsible containers. They are recursive — groups can
contain items and nested groups.

```elixir
group :brewery do
  label "Brewery"
  icon :beer

  item :recipes do
    path "/recipes"
    page MyAppWeb.RecipeLive
  end

  group :archived do
    label "Archived"
    default_open? false

    item :legacy_recipes do
      path "/legacy/recipes"
      module MyAppWeb.LegacyRecipeLive
    end
  end
end
```

| Key             | Default   | Notes                                           |
| --------------- | --------- | ----------------------------------------------- |
| `name`          | required  | Unique identifier                               |
| `label`         | humanized | Display text                                    |
| `icon`          | nil       | Renderer-passed icon name                       |
| `image`         | nil       | Image path/URL (mutually exclusive with `icon`) |
| `image_alt`     | nil       | Alt text                                        |
| `default_open?` | `true`    | Whether the group starts expanded               |

## Introspection: `PyroManiac.Navigation.Info`

The compiled module exposes:

| Function           | Returns                                                      |
| ------------------ | ------------------------------------------------------------ |
| `nav_tree/1`       | The full tree of groups and items, with defaults applied     |
| `route_manifest/1` | `[{path, module}, ...]` — only items with `page` or `module` |
| `flat_items/1`     | Flat list of every item, regardless of nesting               |
| `path_for_page/2`  | Lookup the path for a given page module                      |
| `item_for_page/2`  | Lookup the full item record for a given page module          |
| `items_by_page/1`  | Map keyed by page module                                     |

Renderers use `route_manifest/1` to build their own routing (e.g. Phoenix
`live` routes), and `nav_tree/1` to render the sidebar/menu.

## Common mistakes

- Specifying multiple of `page`/`module`/`href` on the same item — the
  validator rejects this.
- Omitting `path` on a `page`/`module` item — required.
- Setting both `icon` and `image` on the same item or group — they are
  mutually exclusive.
- Pointing `page` at a non-PyroManiac module — the validator checks the
  target uses `use PyroManiac, ...`.
