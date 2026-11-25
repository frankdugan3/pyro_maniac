# Overview

A renderer turns the DSL of a page into a UI. PyroManiac stores and checks
the DSL; it renders nothing. The renderer guides are the contract: for
each feature of the DSL, the rules that a renderer obeys and the functions
that give it what it needs. The tutorials show the UI that each feature
gives and the DSL that declares it; each renderer guide links to its
tutorial for the design expectations.

A renderer is a library with:

- an extension of the page (for example `PyroManiac.LiveView.Page`), with a
  verifier that checks the implementations of the page
  ([Custom renders](renderer-custom-renders.md#verifier));
- the components of the page, the views, the record tree, the actions
  (their buttons, forms, and confirmations), and the links;
- the routes of the pages (`PyroManiac.Info.route/1`; a module without the
  `page` section is not a page and is never routed,
  [Pages](renderer-pages.md#the-page)), and the navigation
  ([Navigation](renderer-navigation.md)).

A page can use more than one renderer (for example
`PyroManiac.LiveView.Page` and `PyroManiac.Solid.Page`). The content of a
node (`render`, `description`, the `label` of a column) is a text or an
expression for every renderer, and at most one implementation for each
renderer, so the same page runs in each.

## The guides

| Renderer guide | Covers | Tutorial |
|---|---|---|
| [Pages](renderer-pages.md) | The `page` section, the primary views, the card URL, searches, realtime, related records, and links. | [Pages](../tutorials/pages.md) |
| [Filters and sorts](renderer-filters-and-sorts.md) | The state of a list, the chips, the advanced view, sorts, and presets. | [Pages](../tutorials/pages.md) |
| [Views](renderer-views.md) | The list view types, their frame, cards and their presentation, and the `:render` view. | [Views](../tutorials/views.md) |
| [Actions](renderer-actions.md) | The actions of the views, forms, confirmations, unsaved changes, steps, inline edits, bulk actions, clone, new rows, reorder, and extra actions. | [Views](../tutorials/views.md) |
| [Record tree](renderer-record-tree.md) | The record tree in view mode and in forms: fields, inputs, sections, tabs, attachments, and workflow. | [Record layout](../tutorials/record-layout.md) |
| [Navigation](renderer-navigation.md) | The navigation tree, its authorization, and the command palette. | [Navigation](../tutorials/navigation.md) |
| [Decorations](renderer-decorations.md) | The configured decorations, their styles, and their expressions. | [Decorations](../tutorials/decorations.md) |
| [Custom renders](renderer-custom-renders.md) | The content of a node, the implementations, and the verifier. | [Custom renders](../tutorials/custom-renders.md) |

## The pipeline

The DSL compiles in the Spark pipeline of each page module:

1. **Sections.** `page` (optional; with it, the module is a page and has
   a required `route`), `views` (`view` entities), and `searches`
   (`search` entities). The actions of the views are lifted into the
   internal `[:forms]` path.
2. **Transformers.** They resolve the resources of the views, expand the
   arguments and the actions, set the defaults, and validate the views,
   the page, the cards, the content (`ValidateRenders`), the surface, and
   the primary views. An invalid page does not compile.
3. **Verifiers.** The checks that need other modules (the resources, the
   link targets), and the verifier of each renderer.
4. **Persisters.** The indexes that the Info functions read (the views by
   `{action, type}`).

At run time, the renderer reads the compiled page through the Info
functions. It SHOULD NOT read the DSL state (`Spark.Dsl.Extension`)
itself: the functions apply the defaults and resolve the inherited
values.

| Module | Gives |
|---|---|
| `PyroManiac.Info` | The page: `page?/1`, `title/1`, `description/1`, `route/1`, `width/1` (and `view_width/2`), the views (`views/1`, `primary_list_view/1`, `primary_single_view/1`, `view_for/3`), the actions (`actions/2`, `bulk_actions/1`, `page_extra_actions/1`), the loads (`build_loads_from_view/2`), the fields (`field_info/2`, `field_label/1`), `searches/1`, the filter options, and `decorations/0`. |
| `PyroManiac.Card` | A card view: its tree, its tabs, its actions, its links, its paths, and the `card` URL param. |
| `PyroManiac.Form.Tree` | The nodes of a record tree: `all/1`, `inputs/1`, `values/1`, `for_action/2`, `read_only?/1`. |
| `PyroManiac.ListState`, `PyroManiac.FilterChips` | The state of a list (filter, sort, page) and its URL form; the chips. |
| `PyroManiac.DataLoader` | Reads a list or a record, and runs an action, with the loads of the view. |
| `PyroManiac.Content`, `PyroManiac.Render` | The content of a node and the implementations of a renderer. |
| `PyroManiac.View` | `decoration/3`. |
| `PyroManiac.Resource.Info`, `PyroManiac.Surface` | The label of a record, the exposed actions and fields, and the restriction of a user input to the surface. |
| `PyroManiac.Realtime`, `PyroManiac.SubscriptionManager` | The topics and the notifications of the realtime views; the presence. |
| `PyroManiac.KanBan.Info`, `PyroManiac.Ordering.Info` | The lanes of a board; the user-defined order. |
| `PyroManiac.Navigation.Info`, `PyroManiac.Navigation.Authorization` | The navigation tree, the routes, the command palette, and the filter for the user. |

## Conventions

- **MUST** is a rule of the contract: a renderer that breaks it is wrong.
  **MUST NOT** is its negation. **SHOULD** is a strong default: break it
  only for a reason that the renderer documents. **MAY** is a choice of
  the renderer.
- A name, not a style: the DSL gives meanings (`decoration`, `size`,
  `width`, `orientation`, `presentation`), and the renderer maps each to
  its own style. There are
  no `class` options.
- The renderer never raises on content: a failed expression, an unknown
  decoration, or an unknown icon renders a fallback.
- Authorization is Ash's, with the scope of the user, for every action
  interface. No exceptions ([Authorization](#authorization)).
- The state that a user can share (the view, the card, the filter, the
  sort, the page) is in the URL.
- The examples use the Brewery domain of the tests: the resources
  `Brewery.Recipe`, `Brewery.RecipeIngredient`, `Brewery.Ingredient`,
  `Brewery.Supplier`, `Brewery.Batch`, `Brewery.QualityTest`,
  `Brewery.Staff`, and `Brewery.Shipment`, and the pages
  `BreweryWeb.RecipeLive`, `BreweryWeb.BatchLive`, and the others.
- In the tutorials, each example has two tabs: the **UI** that the
  renderer produces and the **DSL** that declares it. A yellow tag in a
  figure names the DSL of the part. Click a figure (or focus it and press
  Enter) to see it large.

## Authorization

Every action interface is authorized with the scope of the user. No
exceptions: a read, an action, a bulk action, an inline edit, a count, a
combobox option, a chip label, a lane, a related list, and a preset all run
through Ash with the scope.

- The renderer MUST pass the scope (the actor, the tenant, and the context)
  to each read and action: `PyroManiac.DataLoader`, the forms, the bulk
  actions, `PyroManiac.KanBan.Info.lanes/2`, `PyroManiac.FilterChips`, and
  its own calls to Ash.
- The renderer MUST NOT pass `authorize?: false`, and MUST NOT read with
  another actor than the user's.
- A server renderer MUST decide what it shows with `Ash.can?/3` and these
  options by default:

  ```elixir
  Ash.can?({record_or_resource, action}, scope, maybe_is: true, run_queries?: false)
  ```

  - **Reads are by the page.** A navigation item, a palette command, and a
    link to a page show when the user can open the page:
    `PyroManiac.Navigation.Authorization.authorized?(page, scope)`, the
    check above on the read action of the primary list view of the page.
  - **Writes are by the resource and the action.** An action button, a bulk
    action, an inline edit, a transition, and a lane control show when the
    check above passes for their action, with the record when there is one.

  The answer is the strict check of the policies alone: no query of the
  database, and no runtime check. An answer that the strict check cannot
  give (`:maybe`) is `true`: the renderer shows the control, and Ash
  authorizes the action when it runs. Pass the record when there is one, so
  that the expression checks run on its loaded fields. Other options are a
  setting of the app that the renderer documents, never a silent choice of
  the renderer.
- A client renderer (for example `PyroManiac.Solid`) MUST run each read and
  action through the tooling of AshTypescript (its RPC actions and typed
  queries), which authorize with the actor of the connection. It MUST NOT
  copy the policies into the client: the answers of what it shows come from
  the server, with the defaults above.
- A hidden control is a convenience, not security. Ash refuses an action
  that the policies forbid, and the renderer shows the error of Ash.

The precision of `Ash.can?` with these options is a property of the
policies of the app. Policies that decide with simple checks of the actor
give exact answers; filter checks and runtime checks give `true`. Refer to
[Policies](../tutorials/policies.md).

## The resource

The `pyro_maniac` section of a resource (`PyroManiac.Resource`) gives the
renderer three things. For the surface, refer to
[The surface](../tutorials/surface.md).

| DSL | For the renderer | Function |
|---|---|---|
| `default_label` | The name of a record: the title of a card, the text of a link, a combobox option, a chip, a badge. | `PyroManiac.Resource.Info.record_label/3`, `PyroManiac.Info.display_name/3` |
| `expose :action` (`loads`, `filter`, `sort`) | The surface: the actions and the fields that a page can use. Each page (a module with the `page` section) uses each exposed action, or excludes it ([Pages](renderer-pages.md)). The transformers check the page; the renderer restricts what the user selects. | `PyroManiac.Resource.Info.exposed/2`, `public_fields/2`, `PyroManiac.Surface` |
| `realtime` (`mode`, `module`, `prefix`, `record_topics?`, `except`, `bulk`) | The notifications for the realtime options of the views. | `PyroManiac.Resource.Info.realtime?/1`, `realtime_bulk/1`, `PyroManiac.Realtime.topic/2`, `bulk_topic/1` |

<!-- tabs-open -->

### DSL

```elixir
defmodule Brewery.Batch do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource, PyroManiac.KanBan]

  pyro_maniac do
    default_label :batch_number

    realtime do
      mode :auto
      module BreweryWeb.Endpoint
      prefix "batch"
      record_topics? true
      except [:move_card]
      bulk [:advance_status]
    end

    expose [:read, :list, :kanban_read] do
      loads [:*, :recipe, :brewer]
      filter [:*, :recipe, :brewer]
      sort [:*, :recipe, :brewer]
    end

    expose [:destroy, :create, :update, :start_brewing, :advance_status, :complete, :move_card]
  end
end
```

### Renderer

```elixir
# the label of a record
PyroManiac.Resource.Info.record_label(Brewery.Batch, batch, scope)
#=> "B-2026-043"

# the sort that a user selected, restricted to the surface
PyroManiac.Surface.restrict_sort_input(Brewery.Batch, :read, "-recipe.name,secret")
#=> "-recipe.name"

# the realtime of a page
PyroManiac.SubscriptionManager.subscribe(Brewery.Batch)
PyroManiac.SubscriptionManager.handle_notification(message, view)
```

<!-- tabs-close -->

## Accessibility

Each guide has the rules of its components. These hold everywhere:

- **Keyboard.** Every control is reachable and usable with the keyboard,
  in reading order. A drag has a keyboard alternative. A dialog keeps the
  focus inside, Escape closes it, and the focus returns where it was.
- **Names.** Each control and each record has an accessible name (a
  record: its label, `PyroManiac.Resource.Info.record_label/3`). An icon
  button has a text name.
- **Not by color only.** A meaning of a decoration or of a position (a
  lane, a day, a bar) is also text.
- **Changes.** A polite live region announces a result that the user
  caused (a count, a save, an error), not each key press. A loading view
  has `aria-busy="true"`.
- **Errors.** An error is next to its input, linked to it
  (`aria-describedby`), and in text. An unexpected error shows a generic
  message, never its internals ([Actions](renderer-actions.md#the-forms-of-the-actions)).
- **Motion.** An animation follows a change that happened (a move, a
  drop); it never plays for a change that did not move anything. With
  `prefers-reduced-motion`, nothing slides or moves; a cue that does not
  move (a flash, a color) stays.
- **Stability.** The activity of other users (realtime, presence) MUST NOT
  move what a user looks at or points at, until a change lands: a marker
  of presence does not change the size of what it marks.

## Checklist

- [ ] Each read and action with the scope of the user, never
  `authorize?: false`; what the renderer shows by `Ash.can?/3` with
  `maybe_is: true, run_queries?: false` (server), or through AshTypescript
  (client). [Authorization](#authorization)
- [ ] A route for each page at `PyroManiac.Info.route/1`, and none for a
  module that is not a page. [Pages](renderer-pages.md)
- [ ] The page: `title` (or its default), `description` (its text, or the
  implementation of the renderer), `track_presence?` (off by default), and
  the page extra actions. [Pages](renderer-pages.md)
- [ ] The page opens its primary list view; a row opens the primary card
  with its `presentation`; the other cards open with `card=<view>:<id>`;
  the URL params restore the state. [Pages](renderer-pages.md)
- [ ] Each list type (`:data_table`, `:grid`, `:calendar`, `:gantt`,
  `:kanban`, `:list`, `:timeline`, `:card`, `:render`) and the views as
  tabs. [Views](renderer-views.md)
- [ ] The columns: sort, filter, hide (`default_display`), `decoration`,
  `type`; the inline edits (`action` of a column, `edit_columns`); the
  selection and the bulk actions; the pages, the page sizes, and the
  count. [Views](renderer-views.md), [Actions](renderer-actions.md)
- [ ] The filters and the sorts, the same for each list type: the chips,
  the searches as quick chips, the advanced view with `custom_filters?`,
  the presets of `filter_storage` (`:client` or a `PyroManiac.FilterPresets`
  resource), sharing with `shared_filters?`, the operators of each type,
  the validation by Ash with inline errors, the sort input string, the
  state in the URL, the reset to the first page, and the live region of
  the result count. [Filters and sorts](renderer-filters-and-sorts.md),
  [Pages](renderer-pages.md) (searches)
- [ ] The realtime options of each view, and the bulk messages; each
  changed record read again for the viewer. The presence of the viewers,
  the editors, and the moves of the cards of a board.
  [Pages](renderer-pages.md)
- [ ] The width of each page and view (`:full` by default) and of each
  dialog (`:record` by default), and the orientation of the boards, the
  timelines, the tabs, the steppers, and the navigation.
  [Pages](renderer-pages.md), [Views](renderer-views.md)
- [ ] The record tree in view mode and in the form of each action, in the
  same place: sections, rows, compounds, `path`, tabs, steps,
  attachments, `workflow`, `only` (`Tree.for_action/2`), `visible?`,
  read-only fields, `decoration`, `empty_text`, `size`, `autofocus`, and
  **Show all fields**. [Record tree](renderer-record-tree.md)
- [ ] Each input: `field` types, `select` options, `combobox` (select,
  select many, and free text, its search), `input` with an input type.
  [Record tree](renderer-record-tree.md)
- [ ] The actions of each view (`PyroManiac.Info.actions/2`): the forms
  of a card, the toolbar and row buttons of a list view, the
  confirmations (only `confirm`; never a default one), `presentation`, cross-resource
  actions with `set` (and `overridable?`), the steps and the review, and
  the bulk actions. [Actions](renderer-actions.md)
- [ ] The `state` of each action, bulk action, and inline edit: the guard
  (`:guard`) and the recovery (`:recover`) are mandatory.
  [Actions](renderer-actions.md)
- [ ] `clone?`, `new_row?`, and `reorder?` (with the keyboard
  alternative). [Actions](renderer-actions.md)
- [ ] The kanban lanes of `PyroManiac.KanBan.Info.lanes/2`: static and
  dynamic, the "No lane" lane, the lane decorations, and for each lane
  action (`lane_action/2`) the add, edit, delete (confirmed, with the
  errors of Ash), and move of the lanes (with the keyboard alternative).
  A card move at once (never back and forth), a change of a card placed
  by its rank without a read of the lanes, the moves of others, and the
  motion. [Views](renderer-views.md)
- [ ] `related` in each `type` and `presentation`, with `delegate_to`.
  [Pages](renderer-pages.md)
- [ ] Single links and list links, with the list filter as a chip; a node
  without `link_to` shows text; no link to a page that the user cannot
  open. [Pages](renderer-pages.md)
- [ ] The navigation, filtered for the user, and the command palette.
  [Navigation](renderer-navigation.md)
- [ ] A style for each configured decoration, and a fallback for an
  unknown one. [Decorations](renderer-decorations.md)
- [ ] A verifier that calls `PyroManiac.Render.verify/3`.
  [Custom renders](renderer-custom-renders.md#verifier)
- [ ] The content of each node (`render`, `description`, the `label` of a
  column) with `PyroManiac.Content.resolve/2`: the implementation of the
  renderer, else the text, else the value of the expression on the record.
  [Custom renders](renderer-custom-renders.md#rendering)
- [ ] The loads of each view (`PyroManiac.Info.build_loads_from_view/2`) and
  the surface of the resource. [Views](renderer-views.md),
  [The resource](#the-resource)
