# Navigation

A module with `use PyroManiac.Navigation` gives the navigation of the app:
the `item` and `group` entities of its `nav` section, and the
`command_palette` section. PyroManiac checks it at compile time and gives
the tree and the routes; the renderer draws the menu and the palette. The
route of a page is in the page (`page do route "/recipes" end`,
[Pages](pages.md#the-page)), not in the navigation: a `page` item opens it.
For the renderer contract, refer to
[Navigation](../renderers/renderer-navigation.md).

<svg width="0" height="0" style="position:absolute" aria-hidden="true">
<style>
.dg-svg{width:100%;height:auto}
.dg-p{fill:none;stroke:currentColor;stroke-opacity:.5}
.dg-s{fill:currentColor;fill-opacity:.03;stroke:currentColor;stroke-opacity:.35}
.dg-c{fill:none;stroke:currentColor;stroke-opacity:.35;stroke-dasharray:4 3}
.dg-i{fill:currentColor;fill-opacity:.05;stroke:currentColor;stroke-opacity:.5}
.dg-h{font:600 15px system-ui,sans-serif;fill:currentColor}
.dg-st{font:600 13px system-ui,sans-serif;fill:currentColor}
.dg-l{font:11px system-ui,sans-serif;fill:currentColor;fill-opacity:.65}
.dg-v{font:13px system-ui,sans-serif;fill:currentColor}
.dg-a{font:13px system-ui,sans-serif;fill:#2563eb;text-decoration:underline}
.dg-tb{fill:#fef3c7;stroke:#d97706}
.dg-t{font:11px ui-monospace,monospace;fill:#92400e}
.dg-b{fill:currentColor;fill-opacity:.08;stroke:currentColor;stroke-opacity:.5}
.dg-pri{fill:#1e3a5f}
.dg-bt{font:12px system-ui,sans-serif;fill:currentColor}
.dg-bw{font:12px system-ui,sans-serif;fill:#fff}
.dg-ok{fill:#dcfce7;stroke:#16a34a}
.dg-okt{font:11px system-ui,sans-serif;fill:#166534}
.dg-info{fill:#dbeafe;stroke:#2563eb}
.dg-infot{font:11px system-ui,sans-serif;fill:#1e40af}
.dg-warn{fill:#ffedd5;stroke:#ea580c}
.dg-warnt{font:11px system-ui,sans-serif;fill:#9a3412}
.dg-bad{fill:#fee2e2;stroke:#dc2626}
.dg-badt{font:11px system-ui,sans-serif;fill:#991b1b}
.dg-err{fill:#dc2626}
.dg-errt{font:11px system-ui,sans-serif;fill:#dc2626}
.dg-tab{font:13px system-ui,sans-serif;fill:currentColor;fill-opacity:.7}
.dg-on{stroke:#2563eb;stroke-width:2}
.dg-foc{fill:none;stroke:#2563eb;stroke-width:2}
.dg-f{font:13px system-ui,sans-serif;fill:currentColor;fill-opacity:.5}
.dg-u{font:12px ui-monospace,monospace;fill:currentColor}
.dg-m{fill:Canvas;stroke:currentColor;stroke-opacity:.5}
.dg-g{stroke:currentColor;stroke-opacity:.25}
.dg-hl{fill:#2563eb;fill-opacity:.1}
.dg-bar{fill:#2563eb;fill-opacity:.25;stroke:#2563eb}
</style>
</svg>

## The navigation

| DSL | The UI |
|---|---|
| `item :name` | A link (`label`, default: the humanized name). |
| `page` | A PyroManiac page: the item opens the `route` of the page (no `path`), and shows only if the user can read the page. |
| `module`, `path` | Another module (not checked), at `path`. Always shown. |
| `href` | An external URL, in a new tab. No `path`. |
| `authorizer` | A function of the scope that shows or hides the item, in place of the check of the page. |
| `icon`, `image`, `image_alt` | An icon name for the renderer, or an image (a logo) with its alt text. Not both. |
| `decoration` | The meaning of the item or the group; the renderer maps it to its style ([Decorations](decorations.md)). |
| `group :name` | A group that opens and closes: `label`, `icon`, `image`, `image_alt`, `decoration`, and `default_open?` (default `true`). A group holds items and groups. A group with no visible item does not show. |
| `orientation` | An option of `nav`: `:vertical` (a sidebar, the default) or `:horizontal` (a top bar; each group is a menu). |
| `command_palette` | The command palette: a search of the items and of the commands ([Command palette](#command-palette)). |

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 330" role="img" aria-labelledby="dg-nav-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-nav-t">The navigation of the brewery: a logo, three groups with icons, the active recipes item, a closed group, and an external link</title>
<rect class="dg-p" x="10" y="10" width="980" height="310" rx="8"/>
<rect class="dg-s" x="10" y="10" width="250" height="310" rx="8"/>
<rect class="dg-b" x="24" y="22" width="32" height="32" rx="6"/><text class="dg-st" x="64" y="43">Acme Brewery</text>
<rect class="dg-tb" x="150" y="31" width="104" height="16" rx="3"/><text class="dg-t" x="155" y="43">image · image_alt</text>
<text class="dg-st" x="24" y="80">▾ Brewery</text><rect class="dg-tb" x="110" y="68" width="104" height="16" rx="3"/><text class="dg-t" x="115" y="80">group · icon :beer</text>
<rect class="dg-hl" x="20" y="88" width="230" height="24" rx="4"/>
<circle cx="44" cy="100" r="6" class="dg-b"/><text class="dg-a" x="58" y="105">Recipes</text>
<rect class="dg-tb" x="136" y="92" width="104" height="16" rx="3"/><text class="dg-t" x="141" y="104">page RecipeLive</text>
<circle cx="44" cy="126" r="6" class="dg-b"/><text class="dg-v" x="58" y="131">Batches</text>
<circle cx="44" cy="152" r="6" class="dg-warn"/><text class="dg-warnt" x="58" y="157">Quality tests</text>
<rect class="dg-tb" x="140" y="145" width="116" height="16" rx="3"/><text class="dg-t" x="145" y="157">decoration :warning</text>
<text class="dg-st" x="24" y="190">▾ Inventory</text>
<circle cx="44" cy="212" r="6" class="dg-b"/><text class="dg-v" x="58" y="217">Ingredients</text>
<circle cx="44" cy="238" r="6" class="dg-b"/><text class="dg-v" x="58" y="243">Suppliers</text>
<text class="dg-st" x="24" y="274">▸ Team</text><rect class="dg-tb" x="80" y="262" width="140" height="16" rx="3"/><text class="dg-t" x="85" y="274">default_open? false</text>
<text class="dg-v" x="24" y="304">Docs ↗</text><rect class="dg-tb" x="80" y="292" width="40" height="16" rx="3"/><text class="dg-t" x="85" y="304">href</text>
<g opacity=".3"><text class="dg-h" x="280" y="44">Recipes</text>
<line class="dg-g" x1="280" y1="70" x2="974" y2="70"/><line class="dg-g" x1="280" y1="94" x2="974" y2="94"/><line class="dg-g" x1="280" y1="118" x2="974" y2="118"/><line class="dg-g" x1="280" y1="142" x2="974" y2="142"/>
</g>
<text class="dg-l" x="280" y="200">The items of pages that the user cannot read do not show.</text>
<text class="dg-l" x="280" y="216">The Staff item has an authorizer: only an admin sees it.</text>
</svg>
<figcaption>The navigation. The active item is the page of the current route. The Team group starts closed. Docs opens in a new tab.</figcaption>
</figure>

### DSL

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
        page BreweryWeb.RecipeLive      # opens the route of the page
        icon :recipe
      end

      item :batches do
        page BreweryWeb.BatchLive
        icon :batch
      end

      item :quality_tests do
        page BreweryWeb.QualityTestLive
        icon :check
        decoration :warning
      end
    end

    group :inventory do
      label "Inventory"
      icon :grain

      item :ingredients do
        path "/ingredients"
        module BreweryWeb.IngredientLive
      end

      item :suppliers do
        path "/suppliers"
        module BreweryWeb.SupplierLive
      end
    end

    group :team do
      icon :users
      default_open? false

      item :staff do
        path "/staff"
        module BreweryWeb.StaffLive
        authorizer &BreweryWeb.Scope.admin?/1
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

<!-- tabs-close -->

### Items

An item has exactly one target:

| Target | `path` | Shown |
|---|---|---|
| `page Page` | None (a compile error): the item opens the `route` of the page (`page do route "/recipes" end`). | If the user can run the read action of the primary list view of the page (`Ash.can?/3`), or by `authorizer`. |
| `module Module` | Required. | Always, or by `authorizer`. |
| `href "https://..."` | None. | Always, or by `authorizer`. Opens in a new tab. |

The page of a `page` item is a PyroManiac module with a `page` section (a
module without it is not a page and has no route), and its route has no
parameters (`:id` or `*glob`): a link of the navigation has no values for
them. A `path` starts with `/`. The names are unique at each level.

### Routes

The routes of the navigation are the routes of its `page` items and the
`path` of its `module` items. Groups are not part of a route: an item in
`group :brewery` opens `/recipes`, not `/brewery/recipes`. No two routes
overlap: they overlap when one URL matches both, that is, segment by
segment each pair is equal or one of them is a parameter (`:id`), up to a
glob (`*path`). `"/recipes/:id"` overlaps `"/recipes/new"`, and
`"/files/*path"` overlaps `"/files/report"`; `"/recipes"` and
`"/recipes/new"` do not overlap. An overlap is a compile error.

### Groups

A group opens and closes. It holds items and other groups, in order, and
shows only when it has a visible item for the user. `default_open? false`
starts it closed.

`orientation :horizontal` in `nav` puts the navigation in a top bar: each
group is a menu button that opens its items (`default_open?` does not
apply). The default, `:vertical`, is a sidebar.

```elixir
nav do
  orientation :horizontal

  item :home do
    path "/"
    module BreweryWeb.HomeLive
  end
end
```

### Authorization

The navigation shows only what the user can open:

- `authorizer &Module.fun/1` takes the scope (the actor) and gives
  `true` or `false`. It replaces the check of the page.
- A `page` item without `authorizer` checks the read action of the
  primary list view of the page, without a query
  (`Ash.can?/3` with `maybe_is: true, run_queries?: false`). The answer
  is exact when simple checks of the actor decide the read policy
  ([Policies](policies.md)).
- A `module` or `href` item without `authorizer` always shows.

The renderer filters the tree for each user; the policies of the
resources stay the real check (a hidden item is not a permission).

### Decorations and badges

`decoration` on an item or a group gives its meaning, for example
`decoration :warning` on an item that needs attention, or `:danger` on an
experimental one. It is a decoration name only, not an expression (an item
has no record). The renderer gives the style: a colored dot, a badge, or
an accent. Refer to [Decorations](decorations.md).

`icon` is a name that the renderer maps to its icon set (`:beer`,
`:home`); `image` is a URL with its `image_alt`, for a logo.

## Command palette

The `command_palette` section of the navigation module gives a palette
that opens with a hotkey and finds the items of the navigation and the
commands.

| DSL | The UI |
|---|---|
| `enabled?` (default `true`) | The palette exists. `false`: no palette, no hotkey. |
| `hotkey` (default `"mod+k"`) | The key that opens it: `mod` is Cmd on macOS, else Ctrl. |
| `navigation?` (default `true`) | The palette finds the items of the navigation that the user can open. |
| `placeholder` (default `"Search"`) | The text of the empty search input. |
| `command :name` | A command: `label` (default: the humanized name), `description`, `group`, `keywords`, `icon`, `authorizer`, and exactly one target. |

The target of a command (exactly one; a compile error otherwise):

| Target | What it does |
|---|---|
| `page Page`, optional `path` | Navigates to the `route` of the page, or to `path`, which starts with the route (`"/batches?new"`). Shown only if the user can read the page. |
| `module Module`, `path` | Navigates to `path`. |
| `href` | Opens the URL (an external URL in a new tab). |
| `render Renderer, implementation` | The implementation of the renderer runs the command, or shows its own content in the palette (for example a search of the records, or an action). One for each renderer ([Custom renders](custom-renders.md)). |

The page of a `page` command has a route without parameters, as for an
item. A `module` command needs a `path` that starts with `/`.
`authorizer` shows the command only when it gives `true` for the scope.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 340" role="img" aria-labelledby="dg-cmdp-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-cmdp-t">The command palette over the page: the search input with the query bat, the Batches group with two commands, and the Navigation group with the batches item</title>
<rect class="dg-p" x="10" y="10" width="980" height="320" rx="8"/>
<g opacity=".3"><rect class="dg-s" x="10" y="10" width="250" height="320" rx="8"/><text class="dg-h" x="280" y="44">Recipes</text>
<line class="dg-g" x1="280" y1="70" x2="974" y2="70"/><line class="dg-g" x1="280" y1="94" x2="974" y2="94"/><line class="dg-g" x1="280" y1="118" x2="974" y2="118"/></g>
<rect class="dg-b" x="880" y="22" width="90" height="24" rx="4"/><text class="dg-bt" x="892" y="38">Search ⌘K</text>
<rect class="dg-tb" x="770" y="26" width="100" height="16" rx="3"/><text class="dg-t" x="775" y="38">hotkey "mod+k"</text>
<rect class="dg-m" x="250" y="60" width="500" height="256" rx="8"/>
<rect class="dg-i" x="266" y="74" width="468" height="32" rx="6"/><text class="dg-v" x="280" y="95">bat</text><line class="dg-p" x1="303" y1="82" x2="303" y2="98"/>
<rect class="dg-tb" x="520" y="82" width="206" height="16" rx="3"/><text class="dg-t" x="525" y="94">placeholder · "Search pages and…"</text>
<text class="dg-l" x="270" y="128">Batches</text><rect class="dg-tb" x="330" y="117" width="60" height="16" rx="3"/><text class="dg-t" x="335" y="129">group</text>
<rect class="dg-hl" x="262" y="136" width="476" height="40" rx="4"/><rect class="dg-foc" x="262" y="136" width="476" height="40" rx="4"/>
<circle cx="282" cy="156" r="6" class="dg-b"/><text class="dg-st" x="298" y="152">New batch</text><text class="dg-l" x="298" y="168">Plan a batch of a recipe.</text>
<rect class="dg-tb" x="560" y="140" width="170" height="16" rx="3"/><text class="dg-t" x="565" y="152">command :new_batch · page</text>
<circle cx="282" cy="196" r="6" class="dg-b"/><text class="dg-v" x="298" y="200">Find a batch</text>
<rect class="dg-tb" x="560" y="188" width="170" height="16" rx="3"/><text class="dg-t" x="565" y="200">render · authorizer</text>
<text class="dg-l" x="270" y="232">Brewery</text><rect class="dg-tb" x="330" y="221" width="96" height="16" rx="3"/><text class="dg-t" x="335" y="233">navigation?</text>
<circle cx="282" cy="254" r="6" class="dg-b"/><text class="dg-v" x="298" y="258">Batches</text>
<text class="dg-l" x="270" y="300">↑↓ to move · Enter to run · Esc to close</text><text class="dg-l" x="640" y="300">3 results</text>
</svg>
<figcaption>The command palette. The query finds the commands (in their <code>group</code>) and the items of the navigation (in the group of their nav group). The first result is active; Enter runs it.</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.Navigation do
  use PyroManiac.Navigation

  nav do
    # the items: refer to The navigation
  end

  command_palette do
    hotkey "mod+k"
    placeholder "Search pages and commands"

    command :new_batch do
      label "New batch"
      description "Plan a batch of a recipe."
      group "Batches"
      keywords ["brew", "schedule"]
      icon :batch
      page BreweryWeb.BatchLive
      path "/batches?new"
    end

    command :docs do
      label "Documentation"
      href "https://docs.example.com"
    end

    command :find_batch do
      label "Find a batch"
      group "Batches"
      authorizer &BreweryWeb.Scope.brewer?/1
      render PyroManiac.LiveView, BreweryWeb.Commands.FindBatch
    end
  end
end
```

<!-- tabs-close -->

## Design expectations

- The navigation is short and stable: group by the work of the user (the
  brewery, the inventory), not by the resources.
- The active item is the page of the current route, and its groups are
  open.
- A label is the name of the page, not a command ("Batches", not "Manage
  batches"). A command in the palette is a command ("New batch").
- The palette is a shortcut, never the only way: each item of the
  palette is also reachable in the navigation or on a page.
- Keywords hold the other words that users type ("brew", "schedule").

## Common mistakes

- Two targets (`page`, `module`, `href`) on an item, or none. A command
  has exactly one of `page`, `module`, `href`, or `render`.
- A `path` on a `page` item (the route is in the page) or an `href` item.
- A `module` item or command without `path`, a `path` that does not start
  with `/`, or a `page` command whose `path` does not start with the route
  of the page.
- A `page` that is not a page (no `page` section), or whose route has
  parameters.
- Two overlapping routes (`"/recipes/:id"` and `"/recipes/new"`), or two
  entities with the same name at the same level.
- Both `icon` and `image` on an item or a group.
- `tone` on an item or a group: it is renamed `decoration`. An expression
  as a `decoration`: the navigation takes a decoration name only.
