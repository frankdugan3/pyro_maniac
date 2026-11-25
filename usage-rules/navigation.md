# Navigation

`PyroManiac.Navigation` declares an app's navigation tree as a single
Spark DSL module. It compiles to a tree (groups + items) plus a flat
route manifest, both available via `PyroManiac.Navigation.Info`. The
core library does **not** generate routes or render markup —
that's the renderer's job. Each renderer provides its own routing and
layout components.

## Defining a navigation module

```elixir
defmodule BreweryWeb.Navigation do
  use PyroManiac.Navigation

  nav do
    item :home do
      path "/"
      module BreweryWeb.HomeLive
      image "/images/logo.svg"
      image_alt "Acme Brewery"
    end

    group :brewery do
      label "Brewery"
      icon :beer

      item :recipes do
        page BreweryWeb.RecipeLive
      end

      item :batches do
        page BreweryWeb.BatchLive
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

The route of a page is in the page (`page do route "/recipes" end`), not
in the navigation: a `page` item opens `PyroManiac.Info.route/1` of its
page and has no `path`.

## `item`

Each item must have **exactly one** of `page`, `module`, or `href`:

| Key         | Notes                                                            |
| ----------- | ---------------------------------------------------------------- |
| `name`      | Required atom. Unique identifier                                 |
| `path`      | Required for `module`, must start with `/`. Not allowed for `page` (it opens the route of the page) or `href` |
| `label`     | Display text. Defaults to capitalized name                       |
| `icon`      | Atom passed to the renderer (e.g. `:beer`, `:home`)              |
| `image`     | Path/URL to an image (e.g. logo). Mutually exclusive with `icon` |
| `image_alt` | Alt text for the image                                           |
| `page`      | A PyroManiac page (a module with a `page` section) whose route has no parameters — validated, authorization-aware |
| `module`    | A non-PyroManiac module — always visible                         |
| `href`      | External URL — opens in a new tab. No `path`                     |
| `decoration` | A decoration: by default `:neutral`, `:info`, `:success`, `:warning`, or `:danger` |

A `group` has a `decoration` too. There is no `class`: the renderer maps
the decoration to its styles. For example, `decoration :danger` marks an
experimental item. The set of decorations is configurable (`config
:pyro_maniac, decorations: [...]`, refer to [views](views.md)).

Examples:

```elixir
# A PyroManiac page: it opens the route of the page
item :recipes do
  page BreweryWeb.RecipeLive
end

# A non-PyroManiac module (e.g. a custom LiveView)
item :ingredients do
  path "/ingredients"
  module BreweryWeb.IngredientLive
end

# An external link
item :docs do
  href "https://docs.example.com"
  label "Docs"
end
```

## Routes

The routes of the navigation are the routes of its `page` items and the
`path` of its `module` items. Groups are not part of a route (no
prefixing). No two routes may overlap: they overlap when one URL matches
both, segment by segment equal, or either is a `:param`, up to a `*glob`.
`"/recipes/:id"` overlaps `"/recipes/new"`; `"/recipes"` and
`"/recipes/new"` do not. An overlap is a compile error.

## `group`

Groups are collapsible containers. They are recursive — groups can
contain items and nested groups.

```elixir
group :brewery do
  label "Brewery"
  icon :beer

  item :recipes do
    page BreweryWeb.RecipeLive
  end

  group :inventory do
    label "Inventory"
    default_open? false

    item :suppliers do
      path "/suppliers"
      module BreweryWeb.SupplierLive
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
| `decoration`    | nil       | The meaning of the group                        |

## `command_palette`

The command palette is a search of the navigation items and of the
commands, opened with a hotkey. It is a section next to `nav`.

```elixir
command_palette do
  hotkey "mod+k"

  command :new_batch do
    label "New batch"
    group "Batches"
    keywords ["brew", "schedule"]
    page BreweryWeb.BatchLive
    path "/batches?new"
  end
end
```

| Key           | Default    | Notes                                                        |
| ------------- | ---------- | ------------------------------------------------------------ |
| `enabled?`    | `true`     | Show the command palette                                     |
| `hotkey`      | `"mod+k"`  | The key that opens it (`mod` is Cmd on macOS, else Ctrl)     |
| `navigation?` | `true`     | The palette finds the navigation items that the user can open |
| `placeholder` | `"Search"` | The text of the empty search input                           |

`command :name` has `label`, `description`, `group`, `keywords`, `icon`,
`authorizer`, and exactly one target: `page`, `module` (with `path`),
`href`, or a `render` entity for each renderer (custom content or
behaviour, for example a search of the records). Zero or two targets is a
compile error. A `page` command opens the route of the page; its optional
`path` starts with that route (`"/batches?new"`). `PyroManiac.Navigation.Info.command_palette/1` gives the
section with its `commands`.

## Introspection: `PyroManiac.Navigation.Info`

The compiled module exposes:

| Function           | Returns                                                      |
| ------------------ | ------------------------------------------------------------ |
| `nav_tree/1`       | The full tree of groups and items, with defaults applied     |
| `route_manifest/1` | `[{path, module}, ...]` — only items with `page` (the route of the page) or `module` (its `path`) |
| `flat_items/1`     | Flat list of every item, regardless of nesting               |
| `path_for_page/2`  | Lookup the path (the route) for a given page module          |
| `item_for_page/2`  | Lookup the full item record for a given page module          |
| `command_palette/1` | The `command_palette` section and its commands (a `page` command without `path` has the route of the page) |

Renderers use `route_manifest/1` to build their own routing (e.g. Phoenix
`live` routes), and `nav_tree/1` to render the sidebar/menu. A page that
is not in the navigation still has its route (`PyroManiac.Info.route/1`);
a module without a `page` section has none.

## Common mistakes

- Specifying multiple of `page`/`module`/`href` on the same item — the
  validator rejects this.
- Omitting `path` on a `module` item — required.
- Setting `path` on a `page` item — a compile error: set `page do route
  "/recipes" end` in the page.
- Pointing `page` at a module without a `page` section, or at a page whose
  route has parameters (`"/recipes/:id"`).
- Two routes that overlap (`"/recipes/:id"` and `"/recipes/new"`).
- A `page` command whose `path` does not start with the route of the page.
- Setting both `icon` and `image` on the same item or group — they are
  mutually exclusive.
- Pointing `page` at a non-PyroManiac module — the validator checks the
  target uses `use PyroManiac, ...`.
- `tone` on an item or a group — it is renamed `decoration`.
- A `command` with no target or with more than one.
