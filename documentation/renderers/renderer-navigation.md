# Navigation

A navigation module (`use PyroManiac.Navigation`) gives the tree of the
menu, the routes, and the command palette. PyroManiac checks it at compile
time; the renderer filters it for the user, draws it, and can generate the
routes. The route of a page is in the page (`PyroManiac.Info.route/1`), not
in the navigation: a `page` item has no `path` of its own. For the DSL and
the design expectations, refer to the tutorial
[Navigation](../tutorials/navigation.md).

## The data

`PyroManiac.Navigation.Info`:

| Function | Gives |
|---|---|
| `nav_tree/1` | The tree: `%PyroManiac.Navigation.Item{}` and `%PyroManiac.Navigation.Group{}` (with `items`, recursive), in order, with the defaults applied (`label`, `default_open?`) and the `path` of each `page` item set to `PyroManiac.Info.route/1` of its page. |
| `orientation/1` | The `orientation` of the `nav` section: `:vertical` (a sidebar, the default) or `:horizontal` (a top bar). |
| `flat_items/1` | Every item, without the groups. |
| `route_manifest/1` | `[{path, module}]`: the items with a `page` (the route of the page) or a `module` (its `path`). No two of them overlap. |
| `path_for_page/2`, `item_for_page/2` | The path and the item of a page module, or `nil`. |
| `command_palette/1` | `%{enabled?:, hotkey:, navigation?:, placeholder:, commands:}`, `commands` the `%PyroManiac.Navigation.Command{}` entities; a `page` command without `path` has the route of its page. |

Compile-time guarantees: the page of a `page` item or command is a
PyroManiac module with a `page` section (`PyroManiac.Info.page?/1`), and
its route has no parameters (`:id` or `*glob`). Groups are not part of a
route. No two routes overlap (one URL matches both: segment by segment
equal, or either is a `:param`, up to a `*glob`; `"/recipes/:id"` overlaps
`"/recipes/new"`). The `path` of a `page` command starts with the route of
the page (`"/batches?new"`).

The fields of an item: `name`, `label`, `path`, `page`, `module`, `href`
(exactly one of the three), `icon`, `image`, `image_alt` (not with
`icon`), `decoration`, and `authorizer`. A group: `name`, `label`, `icon`,
`image`, `image_alt`, `decoration`, `default_open?` (default `true`), and
`items`. A command: `name`, `label`, `description`, `group`, `keywords`,
`icon`, `authorizer`, one target (`page`, `module` with `path`, `href`, or
`render` entities), and `path` (for a `page`: the route of the page, or a
path that starts with it).

`PyroManiac.Navigation.Authorization`:

| Function | Gives |
|---|---|
| `filter_authorized(entities, scope)` | The tree without what the user cannot see: an item with `authorizer` shows when `authorizer.(scope)` is `true`; else a `page` item when `authorized?/2`; else it shows. A group without a visible item goes. |
| `authorized?(page, scope)` | `Ash.can?/3` of the read action of the primary list view of the page (else the primary read action), with `maybe_is: true, run_queries?: false` ([Authorization](renderer-overview.md#authorization)). `true` when the resource or the action cannot be resolved. A `nil` scope is a `nil` actor. |

## The menu

The renderer:

- MUST show the tree of `filter_authorized(nav_tree(navigation), scope)`,
  in order, for the current scope, and filter again when the scope
  changes. It MUST NOT show an item that the filter removes.
- MUST render `page` and `module` items as links to their `path` in the
  app, and `href` items as links in a new tab (`target="_blank"`,
  `rel="noopener"`), marked as external (an icon with a text alternative).
- MUST mark the active item: the item of the current page
  (`item_for_page/2`), else the item whose `path` matches the current
  route. The groups of the active item are open.
- MUST open each group by `default_open?`; the user opens and closes it.
  The renderer MAY remember the state of each group.
- MUST lay the menu out by `orientation(navigation)`: `:vertical` (the
  default), a sidebar, the groups open in place; `:horizontal`, a top bar,
  each group a menu button that opens its items (`default_open?` does not
  apply). A renderer MAY show a horizontal menu as a sidebar or a menu
  button on a narrow screen.
- MUST map `icon` to its icon set (an unknown icon: no icon, no error),
  and render `image` with `image_alt` as its alt text.
- MUST map `decoration` to its style ([Decorations](renderer-decorations.md)).
- SHOULD generate the routes from `route_manifest/1` (for example the
  `live` routes of Phoenix), so the navigation and the router agree. The
  route of a page is `PyroManiac.Info.route/1`, also for a page that the
  navigation does not list ([Pages](renderer-pages.md)).
- A navigation obeys the unsaved-changes guard of an open form
  ([Actions](renderer-actions.md)).

The hidden items are a convenience: the policies of the resources stay the
check of each page.

### Accessibility

- The menu is a `nav` landmark with a label ("Main").
- The active item has `aria-current="page"`.
- A group is a button with `aria-expanded` and `aria-controls` its list;
  its label is its text. In a top bar, Escape closes an open group and
  returns the focus to its button.
- An item with an icon only (a collapsed menu) has its label as its
  accessible name; an image has its `image_alt` (an empty `alt` when the
  label is beside it).
- A decoration is not shown by color only.

## The command palette

The palette exists when `enabled?` is `true` (the default). It opens with
`hotkey` (`mod` is Cmd on macOS, else Ctrl), and from a trigger button.

### Results

- **Commands.** Each command of `commands` whose `authorizer.(scope)` is
  `true`; else a `page` command when
  `PyroManiac.Navigation.Authorization.authorized?/2`; else it shows. The
  renderer filters the commands itself (`filter_authorized/2` takes the
  items and the groups).
- **Navigation.** With `navigation?`, the items of
  `filter_authorized(nav_tree(navigation), scope)` (each item; a group is
  the group of its items).
- **Search.** A fuzzy, case-insensitive search over the label, the
  keywords, and the description (in that order of weight), and the label
  of the group of a nav item. The results are in groups: the `group` of
  each command, and "Navigation" for the items (or the label of their nav
  group). Each group keeps its order; the best match is first. An empty
  search shows the commands and the items in order (MAY show the recent
  ones first). No result: "No results".

### Run

Enter or a click runs the active result and closes the palette:

| Target | The renderer |
|---|---|
| `page Page`, `path` | Navigates to `path`: the route of the page, or a path that starts with it (`"/batches?new"`). |
| `module Module`, `path` | Navigates to `path`. |
| `href` | Opens the URL (an external URL in a new tab). |
| `render Renderer, implementation` | Calls its implementation (`PyroManiac.Render.implementation/2`): it runs the command, or renders its own content in the palette (for example a search of the records, or an action). |

A navigation obeys the unsaved-changes guard of an open form.

The commands are in the navigation module, not in a page:
`PyroManiac.Render.verify/3` does not see them. The renderer validates the
`render` implementations of the commands itself (with
`PyroManiac.Render.implementation/2` on the `render` of each command). A
`render` command without an implementation for the renderer does not
show.

### Accessibility

- The palette is a modal `dialog` with a label (the placeholder, or
  "Command palette").
- Its input is a `combobox` (`aria-expanded`, `aria-controls` the
  listbox, `aria-activedescendant` the active option); the results are a
  `listbox` with `option` entries in `group` elements labelled by their
  group.
- Up and Down move the active option, Home and End go to the first and
  the last, Enter runs it, Escape closes the palette and returns the focus
  where it was.
- A polite live region announces the count of results.
- The hotkey is shown (for example in the trigger button of the header,
  "⌘K") and does not take the key while the user types in another input,
  unless it has a modifier.

## Checklist

- [ ] The tree of `nav_tree/1`, filtered with `filter_authorized/2` for
  the scope; empty groups hidden.
- [ ] `page`, `module`, and `href` items; the active item; `default_open?`.
- [ ] `orientation/1`: a sidebar, or a top bar with a menu for each group.
- [ ] `icon`, `image`, `image_alt`, and `decoration`.
- [ ] The routes from `route_manifest/1`.
- [ ] The command palette: `enabled?`, `hotkey`, `navigation?`,
  `placeholder`, the commands with their authorization, the search, the
  four targets, and the validation of the `render` implementations.
- [ ] The unsaved-changes guard on each navigation.
- [ ] The landmarks, `aria-current`, `aria-expanded`, and the combobox of
  the palette.

Back to the [Overview](renderer-overview.md).
