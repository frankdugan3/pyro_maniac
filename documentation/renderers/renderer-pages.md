# Pages

The contract of the page: its frame, its primary views, the presentation
of its cards, the links between pages, the related records, and realtime.
For the design expectations (what the user sees, and the DSL), refer to
the tutorial [Pages](../tutorials/pages.md). The filters, the sorts, and
the searches are in [Filters And Sorts](renderer-filters-and-sorts.md); the
cards and the other views in [Views](renderer-views.md).

## The page

A module with the `page` section is a page: `PyroManiac.Info.page?/1` is
`true`, and `PyroManiac.Info.route/1` gives its route (required in the
section). A module without it is not a page: it declares views and
searches that the pages reuse, `page?/1` is `false`, and `route/1` is
`nil`.

The renderer:

- MUST declare a route for each page, at `PyroManiac.Info.route/1` (for
  example a `live` route of Phoenix). The navigation does not set the
  route; its `page` items open it ([Navigation](renderer-navigation.md)).
- MUST NOT route a module that is not a page.

The `page` section gives the frame of the page
([The page](../tutorials/pages.md#the-page)):

| DSL | The renderer | Function |
|---|---|---|
| `title` | The document title and the page header. Default: the plural name of the resource (else its short name), humanized. | `PyroManiac.Info.title/1` |
| `description` | Text below the title, or the implementation of the renderer. | `PyroManiac.Info.description/1`, `PyroManiac.Content.resolve/2` |
| `route` | The URL path of the page (required). The renderer declares the route from it; a navigation item or a command with `page` opens it. | `PyroManiac.Info.route/1` |
| `width` | The width of the views of the page: an intent, `:full` (the default: the whole content area), `:record`, `:form`, or `:prose`. A view can set its own ([Views](renderer-views.md#the-frame-of-a-list-view)). | `PyroManiac.Info.width/1`, `view_width/2` |
| `track_presence?` | Who views or edits the page and each record (default `false`: no presence). | `PyroManiac.Info.track_presence?/1`, `PyroManiac.SubscriptionManager.view_presence_topic/1`, `edit_presence_topic/2`, `edit_presence_topics/1` |
| `custom_filters?`, `filter_storage`, `shared_filters?` | The advanced filter view, the presets, and sharing ([Filters And Sorts](renderer-filters-and-sorts.md#the-page-options)). | `PyroManiac.Info.custom_filters?/1`, `filter_storage/1`, `shared_filters?/1` |
| `exclude` | No UI ([The actions of the page](#the-actions-of-the-page)). | |
| `extra_action` | A button in the page toolbar ([Actions](renderer-actions.md)). | `PyroManiac.Info.page_extra_actions/1` |

- **Title.** `PyroManiac.Info.title/1` gives the title, with its default:
  without `title`, `BreweryWeb.RecipeLive` is "Recipes".
- **Description.** `PyroManiac.Info.description/1` gives the
  `description` entities.
  `PyroManiac.Content.resolve(PyroManiac.Info.description(page), renderer)`
  gives `{:impl, implementation}` (render the implementation of the
  renderer), `{:text, text}` (render the text), or `nil` (no description).
  The page has no record, so a description is never an expression
  ([Custom renders](renderer-custom-renders.md)).
- **Width.** `PyroManiac.Info.width/1` gives the width of the page; the
  renderer maps each intent to its own size. The default, `:full`, is the
  whole content area: the renderer MUST NOT cap it at a reading width. The
  title and the description keep a readable line length at any width.
- **Presence.** With `track_presence? true`, the renderer tracks two
  presences. With `false` (the default), it tracks nothing and shows
  nothing.
  - **Viewing is of the page.** The renderer tracks the actor on
    `PyroManiac.SubscriptionManager.view_presence_topic(page)` while the
    page is open, and shows the viewers in the header. Two pages of the
    same resource have two topics: a page shows only its own viewers.
  - **Editing is of the resource and the action.** While the actor edits a
    record (a form, an inline edit, a bulk action), the renderer tracks
    the actor on `edit_presence_topic(resource, action)`, with the IDs of
    the records in the meta. Each view subscribes to
    `edit_presence_topics(resource)` of its resource (and of the resource of
    each related list), and shows the editor on the row or card of each
    record. An edit registers in every view of the resource, on any page.
    The renderer untracks the actor when the edit ends (a save, a cancel,
    a close); the presence removes it when the connection ends (a closed
    tab), so no marker stays.
  - **Moving is editing.** A card of a board that the actor picks up (a
    drag, or the keyboard) is an edit of the move action: the renderer
    tracks the actor on `edit_presence_topic(resource, move_action)` with
    the ID of the card, and untracks it on the drop or the cancel. The meta
    also has the drop target, `%{lane:, target:, position:}` (`position`:
    `before` or `after` the `target` card, or `last` in the `lane` with no
    target), or none while the card is over no target. The renderer
    updates the meta only when the target changes, never for each move of
    the pointer ([Kanban boards](renderer-views.md#kanban-boards)). A
    transport keeps only these keys from the client.
  - **The user.** Each user of a topic has an ID, a name, and initials
    (`%{name:, initials:}` of the app, else the `name` or the `email` of
    the actor). A view does not show the actor as an editor or a mover of
    its own records: only the others.

### The actions of the page

The transformers check that each action that the surface of the resource
exposes is used by a view of the page or is in `exclude` (pages only; a
module without the `page` section is not checked)
([The actions of the page](../tutorials/pages.md#the-actions-of-the-page)).
`exclude` has no UI: the renderer never offers an excluded action, and
never offers an action that the surface does not expose
(`PyroManiac.Resource.Info.exposed/2`, `PyroManiac.Surface`).

## The primary views

A page has a **primary single view** (a `:card` with `primary? true`), and
at most one **primary list view** (a list type with `primary? true`).
With no primary list view, the primary card is also the list view (one card
for each record; refer to [Views](renderer-views.md)).

- `PyroManiac.Info.primary_list_view/1`: the view that the page opens.
- `PyroManiac.Info.primary_single_view/1`: the card of one record.
- `PyroManiac.Info.named_views/3`: the single or list views with a name
  (for `single_view` and `list_view` of a link).
- `PyroManiac.Info.views/1`: all the views. The other list views are tabs
  of the page.

A view shows the records of its read action (its name, or `read_action`)
and runs the actions that it names ([Actions](renderer-actions.md)). A card
shows its record tree in view mode, and the same tree is the form of each
write action that it names ([Record Tree](renderer-record-tree.md)).

The URL MUST have the state, so Back, a reload, and a shared link give the
same UI:

| Param | Meaning |
|---|---|
| `card=<id>` | The record in the primary card. |
| `card=<view>:<id>` | The record in another card of the page (the first action name of the view). |
| `edit` | The card in edit mode. |
| `tab=<name>` | The open tab of the record tree. |

`PyroManiac.Card.param/3` and `PyroManiac.Card.parse_param/2` encode and
decode `card`. `parse_param/2` gives `:error` for an unknown view: show the
list. The state of the list behind a card (its filter, sort, and page) is
in the same URL ([The state of a list](renderer-filters-and-sorts.md#the-state-of-a-list)).

### Card presentation

`presentation` of a card (default `:modal`) says where it opens:

| Value | The renderer |
|---|---|
| `:modal` | A dialog over the page. The list behind it keeps its sort, page, and filters. |
| `:drawer` | A dialog at the side of the page, over the list. |
| `:page` | The full page, without the list, with a link back to the list. The heading is an `<h1>`; there is no **Close**. |

- `width` of the card (an intent: `:full`, `:record`, `:form`, or
  `:prose`) is the width of a modal or a drawer, `:record` by default (not
  the width of the page). With `presentation :page`, the card is the page:
  its `width` is the width of a view, by default the width of the page
  ([Width](#the-page)).
- On a phone, a modal and a drawer MUST be a full-screen sheet.
- A modal and a drawer MUST be a dialog (`role="dialog"`,
  `aria-modal="true"`, labelled by its heading): the requirements of the
  focus, Escape, and **Close** are in [Views](renderer-views.md).
- Close removes `card` (and `edit`) from the URL; the list behind it is
  unchanged.
- A second card of the page (`card=<view>:<id>`) has its own
  `presentation`: it opens from a link with `single_view`, from an extra
  action, or from the URL. Its tree is the form of its action; a node that
  is not an input of the action shows its value.

### Previous and next record (planned)

There is no DSL for it yet (refer to the record navigation in
`ROADMAP.md`). The expectation, for a renderer that implements it now:

- A single view that opens from a list view SHOULD offer **Previous** and
  **Next** in the context of that list: its current filter, sort, and page
  ([The state of a list](renderer-filters-and-sorts.md#the-state-of-a-list)),
  and its position ("3 of 120") when the list has a count.
- At the end of a page, **Next** SHOULD open the first record of the next
  page (offset and keyset pages).
- A single view that opens from a direct link has no list: no previous and
  next.
- The buttons SHOULD have keyboard shortcuts, and they MUST obey the
  unsaved-changes guard of an open form ([Actions](renderer-actions.md)).

## Links

`link_to Page` links to another page
([Links](../tutorials/pages.md#links)). It is on a column, a `field` (a
relationship, read-only), a `combobox`, a `field` of `related`, or
`related`. A node has at most one `link_to`. Its `open` says how a click on
a record opens it ([Layers](#layers)): `:navigate` (the default) goes to the
page; `:stack` and `:replace` open the card of the record in a layer.

- **One record** (a `belongs_to`, a combobox, a read-only relationship
  field): the link opens the single view of the record on the page:
  `single_view`, else its primary single view. The URL is the route of the
  page with `card=<id>` (or `card=<view>:<id>`).
- **Many records** (`related`, a `has_many` column): each record links to
  its single view, and a **list link** ("All 12 batches") opens a list view
  of the page filtered by the relationship: `list_view`, else its primary
  list view ([List links](#list-links)).
- A node without `link_to` has no link: show the label as text.
- Show the link only if the user can open the target page
  (`PyroManiac.Navigation.Authorization.authorized?/2`); else show the
  label as text, with no hint. The record came from an authorized read.

Functions:

- `PyroManiac.Card.links/1`: each link of the views and the actions of a
  page, with its `kind` (`:single`, `:list`, `:delegate`), `record_path`,
  and `destination`. `PyroManiac.Card.view_links/2`: the links of one view.
- `PyroManiac.Link.link/1`: the `link_to` of a node.
- `PyroManiac.Link.resolve/2`: the page and the view of a link, for a kind
  (`:single` or `:list`): `{:ok, %{page:, view:}}` or `{:error, reason}`.
- `PyroManiac.Link.label_paths/2`: the label of the record (the view loads
  it); `PyroManiac.Resource.Info.record_label/3` gives the text.
- `PyroManiac.Link.list_filter/3`: the filter of a list link, for the
  filter param of the list view: the foreign key of the relationship, or
  the reverse `many_to_many`.

### Layers

`open :stack` opens the card of the record in a new layer over the current
page, or over the top layer (a card on a card). `open :replace` opens it in
place of the top layer. `presentation` (`:modal`, `:drawer`) gives the shape
of the layer, else the `presentation` of the target card (`:page` is a modal
in a layer).

- The `href` of the link is always the page of the record (`card=<id>`): a
  modified click (a new tab) and "Copy link" give the page. A plain click
  opens the layer.
- The URL has the stack: one `layer=<route>~<card param>[~<presentation>]`
  for each layer, after the state of the page. Each layer that opens is a
  history entry: Back closes the top layer, Forward opens it again, and a
  reload or a shared link gives the same layers. A layer that does not
  resolve (no page for the route) shows nothing.
- At most 3 layers. At the limit, a new layer replaces the top one. A
  record that is already in the stack does not open again: the stack goes
  back to it.
- A layer is the card of the page of the record: that page's spec, its
  permissions, its actions, and its channel (realtime and presence). Its
  Edit and its tab stay in the layer; they never navigate.
- Only the top layer takes the focus and the input. The page card and the
  layers below are `inert`. Escape, ×, and a click outside close the top
  layer. The focus returns to the link that opened it.
- A deeper layer is offset (`level` of the dialog), so the one below shows
  at its edges. A layer has **Open page**: the page of the record.
- The list link of a `related` ("All 12 batches") always navigates.

### List links

A list link ([List links](../tutorials/pages.md#list-links)) opens the
list view of `list_view` (else the primary list view) of the destination,
with the filter of `PyroManiac.Link.list_filter/3`:

- The filter is the `f` param of the list view, encoded with
  `PyroManiac.ListState.encode/1`
  ([The state of a list](renderer-filters-and-sorts.md#the-state-of-a-list)),
  for example `/batches?v[f][recipe_id][eq]=7c1e9a40-…` under the key of
  the root list of the renderer.
- The filter MUST show as a chip (`PyroManiac.FilterChips`), with the label
  of the record, that the user can remove. It goes through the same
  pipeline as any filter: it cannot widen what the actor can read.
- The list has its full sort, pages, and columns.

## Related records

`related :rel` shows the records of a relationship of the record, in either
direction, at the top level of a tree (not in a nested form)
([Related records](../tutorials/pages.md#related-records)). They are
read-only in the forms: each record has its own page.

| Option | The renderer |
|---|---|
| `type` | `:list` (the default), `:data_table` (the `field` entities are the columns), `:grid`, `:count`, or `:badge`. |
| `presentation` | `:inline` in the record, or `:modal` or `:drawer` over the page. Over the page, the record shows the count as a button that opens them. |
| `delegate_to` | A page of the destination shows them with its own primary list view, scoped to the record. |
| `count` | An aggregate or a calculation: the count in the heading. |
| `limit` | The maximum number of records inline (without `delegate_to`). |
| `label`, `description` | The heading (default: the humanized name), and text below it. |
| `empty_text` | The text with no record (default `"None"`). |
| `link_to` | Each record links to its page, with a list link ([List links](#list-links)). |
| `only`, `visible?`, `render` | The actions of the tree that show it; a condition on the record; a custom render ([Custom renders](renderer-custom-renders.md)). |

- The renderer reads the records with the loads of the view
  (`PyroManiac.Info.build_loads_from_view/2`), for the actor. In a form,
  `related` shows its records as in view mode: it is never an input.
- With `delegate_to`, the renderer shows the primary list view of the other
  page, scoped to the record (the filter of the relationship), with its own
  filter bar, sort, and pages
  ([Filters And Sorts](renderer-filters-and-sorts.md)). Its state is under
  its own key in the URL. `PyroManiac.Card.links/1` gives it with the kind
  `:delegate`.
- Without `delegate_to`, at most `limit` records show inline, and a list
  link with `link_to` gives the rest.
- `:modal` and `:drawer` are dialogs, as a card
  ([Card presentation](#card-presentation)).

## Realtime

A view with realtime options changes on the notifications of its resource
([Realtime](../tutorials/pages.md#realtime)). The resource needs a
`realtime` section (`PyroManiac.Resource.Info.realtime?/1`).

| Option | Values | The renderer |
|---|---|---|
| `on_create` | `:prepend`, `:append`, `:reload`, `:notify`, `:none` | A new record shows at the top or the end, the page reloads, or a banner offers a reload. |
| `on_update` | `:replace`, `:reload`, `:notify`, `:none` | The record changes in place. |
| `on_destroy` | `:remove`, `:reload`, `:notify`, `:none` | The record goes. |
| `on_bulk` | `:reload`, `:notify`, `:none` | One `PyroManiac.Realtime.Bulk` message for a bulk operation (the actions in `bulk`). |

`PyroManiac.SubscriptionManager.subscribe/1` subscribes to the static
topics of the resource. `handle_notification/2` gives what to do with a
message for the realtime options of a view; `extract_bulk/1` reads a bulk
message. `PyroManiac.Realtime.topic/2` and `bulk_topic/1` give the topics,
and `PyroManiac.Resource.Info.realtime_bulk/1` the bulk actions.

```elixir
PyroManiac.SubscriptionManager.subscribe(Brewery.Batch)
PyroManiac.SubscriptionManager.handle_notification(message, view)
```

- **The record is read again.** The record of a notification is the
  record as the actor of the change read it: the policies and the field
  policies of the viewer did not apply to it. The renderer MUST NOT show
  it. It reads the record again with the read action of the view and its
  loads, for the viewer, and applies the result: a record that the viewer
  cannot read any more goes from the view. A client renderer gets from its
  transport (for example a channel) the kind of the change and the ID of
  the record, never the record.
- **In place.** A change in place keeps the page, the sort, and the focus
  of the list. `:prepend` and `:append` put a new record at the top or the
  end of the current page; the next read puts it at its place in the sort.
- **A card** of a view with realtime options reads its record again on a
  change of the record, and on a change of a record that a `related` node
  of its tree shows (a notification of the destination resource). After a
  destroy of its record it says so ("Deleted"), keeps the values that it
  shows, and offers no action.
- **A board** places the card of a change itself, without a read of its
  lanes ([Kanban boards](renderer-views.md#kanban-boards)). The change of
  a card has its position from the notification: the name of the action,
  the lane value and the rank after the change (`notification.data`), and
  for an update the lane value before it (`notification.changeset.data`).
  A transport to a client sends them with the ID.
- A bulk operation sends one message: the renderer applies `on_bulk`
  once, not a change for each record.

## Checklist

- [ ] A route for each page at `PyroManiac.Info.route/1`; no route for a
  module that is not a page (`PyroManiac.Info.page?/1`).
- [ ] The page: `title` (or its default), `description` (its text, or the
  implementation of the renderer), `track_presence?` (off by default), and
  the page extra actions.
- [ ] The width of the page and of each view (`view_width/2`; `:full` is
  the whole content area), and the `width` of a modal or a drawer
  (`:record` by default).
- [ ] The presence of the viewers, of the editors, and of a card that
  another user moves (with its drop target); the actor is not shown on
  its own records; no marker stays after a closed tab.
- [ ] The page opens its primary list view; a row opens the primary card
  with its `presentation`; the other cards open with `card=<view>:<id>`;
  the URL params restore the state.
- [ ] The realtime options of each view, and the bulk messages; each
  changed record read again for the viewer, never shown from the
  notification; a card follows its record and its related records.
- [ ] `related` in each `type` and `presentation`, with `delegate_to`.
- [ ] Single links and list links, with the list filter as a chip; a node
  without `link_to` shows text; no link to a page that the user cannot
  open.
