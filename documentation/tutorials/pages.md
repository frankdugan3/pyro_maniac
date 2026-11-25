# Pages

A page module (`use PyroManiac, resource: ...`) declares the UI of one
resource: the `page` section (the frame), its views, its searches, and the
links to the other pages. This guide shows what the user sees and the DSL
that declares it. For the contract that a renderer implements, refer to
[Pages](../renderers/renderer-pages.md) and
[Filters And Sorts](../renderers/renderer-filters-and-sorts.md).

Each example has two tabs: the **UI** and the **DSL** that declares it. A
yellow tag in a figure names the DSL of the part. Click a figure (or focus
it and press Enter) to see it large. The examples use the Brewery domain of
the tests.

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

## The page

A module with the `page` section is a page: it has a route, and
`PyroManiac.Info.page?/1` is true. A module without it is not a page: it
declares views and searches that the pages of the application reuse. It
has no route, a renderer does not route it, and a navigation item cannot
open it. The check that each exposed action is used
([The actions of the page](#the-actions-of-the-page)), and `exclude`, apply
to pages only.

The `page` section gives the frame of the page:

| DSL | The UI | Default |
|---|---|---|
| `title` | The document title and the page header. | The plural name of the resource (else its short name), humanized. |
| `description` | Text below the title: `description "text"`, and `description Renderer, implementation` for a renderer (no expression: the page has no record). | None. |
| `route` | The URL path of the page (`"/recipes"`). The renderer declares the routes from it; a navigation item or a command with `page` opens it. | Required. |
| `width` | The width of the views: an intent, `:full` (the whole content area), `:record` (one record), `:form` (a form of inputs), or `:prose` (a readable line length). A view can set its own `width`. The title and the description keep a readable line length at any width. | `:full`. |
| `track_presence?` | Who views the page (avatars in the header: the viewers of this page only), who edits each record ("Ana is editing": an edit of the record with any action of its resource, from any page), and who moves a card of a board (the card marked "Moving", and where it would drop). | `false`: no presence. |
| `custom_filters?` | The advanced filter view: the user builds filters ([Filters and sorts](#filters-and-sorts)). | `false`: the simple chips and the searches only. |
| `filter_storage` | Where the filters that the user saves go: `:client` (the browser) or a resource with `PyroManiac.FilterPresets`. Requires `custom_filters? true`. | `nil`: no saving. |
| `shared_filters?` | The user can share a saved filter. Requires a resource in `filter_storage`. | `false`. |
| `exclude` | The exposed actions of the resource that the page does not use ([The actions of the page](#the-actions-of-the-page)). No UI. | `[]`. |
| `extra_action` | A button in the page toolbar ([Extra actions](views.md)). | None. |

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 250" role="img" aria-labelledby="dg-page-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-page-t">The header of the recipes page: the route, the title, the description, the people on the page, and the toolbar</title>
<rect class="dg-p" x="10" y="10" width="980" height="230" rx="8"/>
<rect class="dg-i" x="22" y="22" width="956" height="22" rx="3"/><text class="dg-u" x="30" y="37">/recipes</text>
<rect class="dg-tb" x="100" y="25" width="116" height="16" rx="3"/><text class="dg-t" x="105" y="37">route "/recipes"</text>
<text class="dg-h" x="26" y="80">Recipes</text>
<rect class="dg-tb" x="96" y="67" width="42" height="16" rx="3"/><text class="dg-t" x="101" y="79">title</text>
<text class="dg-l" x="26" y="102">Recipes in production, in draft, and retired.</text>
<rect class="dg-tb" x="270" y="90" width="82" height="16" rx="3"/><text class="dg-t" x="275" y="102">description</text>
<circle cx="606" cy="80" r="13" class="dg-info"/><text class="dg-infot" x="598" y="84">AR</text>
<circle cx="628" cy="80" r="13" class="dg-ok"/><text class="dg-okt" x="620" y="84">CP</text>
<text class="dg-l" x="648" y="84">2 viewing</text>
<rect class="dg-tb" x="590" y="100" width="148" height="16" rx="3"/><text class="dg-t" x="595" y="112">track_presence? true</text>
<rect class="dg-b" x="790" y="66" width="70" height="28" rx="4"/><text class="dg-bt" x="805" y="84">Export</text>
<rect class="dg-tb" x="760" y="100" width="136" height="16" rx="3"/><text class="dg-t" x="765" y="112">extra_action :export</text>
<rect class="dg-pri" x="870" y="66" width="104" height="28" rx="4"/><text class="dg-bw" x="886" y="84">+ New recipe</text>
<g opacity=".35">
<text class="dg-l" x="26" y="146">Name</text><text class="dg-l" x="400" y="146">Style</text><text class="dg-l" x="640" y="146">Status</text>
<line class="dg-g" x1="26" y1="152" x2="974" y2="152"/>
<text class="dg-v" x="26" y="172">Copper Pale Ale</text><text class="dg-v" x="400" y="172">Pale Ale</text><text class="dg-v" x="640" y="172">Draft</text>
<text class="dg-v" x="26" y="196">Hazy Daze IPA</text><text class="dg-v" x="400" y="196">IPA</text><text class="dg-v" x="640" y="196">Active</text>
<text class="dg-v" x="26" y="220">Midnight Stout</text><text class="dg-v" x="400" y="220">Stout</text><text class="dg-v" x="640" y="220">Active</text>
</g>
<circle cx="940" cy="192" r="9" class="dg-info"/><text class="dg-infot" x="934" y="196">AR</text>
<text class="dg-l" x="830" y="196">Ana is editing</text>
</svg>
<figcaption>The header of the recipes page. The avatars show who is on the page; a row shows who edits its record. <b>Export</b> is an extra action of the page.</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.RecipeLive do
  use PyroManiac, resource: Brewery.Recipe

  page do
    title "Recipes"
    description "Recipes in production, in draft, and retired."
    route "/recipes"
    track_presence? true
    exclude [:list, :activate, :retire, :destroy]

    extra_action :export do
      label "Export"
    end
  end

  # the views: refer to The primary views
end
```

<!-- tabs-close -->

Without `title`, the title of this page is "Recipes" (the plural name of
`Brewery.Recipe`, else its short name).

`description` is an entity of the `page` section
([Custom renders](custom-renders.md)). An implementation replaces the text
for its renderer; the other renderers show the text:

```elixir
page do
  title "Recipes"
  route "/recipes"
  description "Recipes in production, in draft, and retired."
  description PyroManiac.LiveView, BreweryWeb.RecipeLive.Intro
end
```

### The actions of the page

The page uses the actions that the surface of the resource exposes
(`expose` in the `pyro_maniac` section of the resource, refer to
[The surface](surface.md)). Each exposed action is used by a view, or is in
`page do exclude [...] end`. The check runs last, so the other errors of
the page show first.

| An action is used by | Example |
|---|---|
| the name of a view, or its `read_action` (a read action) | `view :read do ... end` |
| `action` of a view (create, update, destroy, generic) | `action [:create, :update], :guard` |
| `action` of a column, `edit_columns` | `column :status do action :update, :discard do ... end end` |
| `bulk_action` of a view | `bulk_action :start_brewing, :discard` |
| a `:kanban` view (the `move_action` of the `kan_ban` section) | `view :kanban_read do type :kanban end` |
| a view with `reorder? true` (the `move_action` of the `ordering` section) | `view :read do reorder? true end` |

- `exclude` names exposed actions only. An excluded action that a view
  uses is an error.
- The `attach_*`, `detach_*`, and `purge_*` actions of AshStorage need no
  entry: `attachments` uses them.
- An action of another resource (`resource` of an action) is not an
  action of the page.
- A read action that only a `combobox` uses (`read_action`) is excluded:
  the page has no view on it.

`BreweryWeb.RecipeLive` uses `:read` (its views), `:create`, and
`:update` (its card). It excludes the other exposed actions of
`Brewery.Recipe`: `:list`, `:activate`, `:retire`, and `:destroy`.

## The primary views

A page has a **primary single view**: a `:card` with `primary? true`. It
can also have one **primary list view**: a list type with `primary? true`.
With no primary list view, the primary card is also the list view (one card
for each record). A link to the page opens a primary view; the other list
views are tabs of the page.

`view` is a top-level entity of the page (no `views do` block). A view
shows the records of its read action (its name, or `read_action`) and runs
the actions that it names ([Views](views.md)).

A card shows one record: its own record tree (`field`, `section`, `row`,
...), in view mode ([The record layout](record-layout.md)). The tree is
also the form of each write action that the card names
(`action [:create, :update], :guard`): **Edit** switches the card to the
update form. A card that names no write action is view mode only (no
**Edit**). A card without a tree is a compile error; a card has no
columns. A page can have more than one card; one has `primary? true`. The
options of a card, and the page whose primary card is its list, are in
[Views](views.md).

The URL has the state, so Back, a reload, and a shared link give the same
UI:

| Param | Meaning |
|---|---|
| `card=<id>` | The record in the primary card. |
| `card=<view>:<id>` | The record in another card of the page (the first action name of the view). |
| `edit` | The card in edit mode. |
| `tab=<name>` | The open tab of the record tree. |

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 400" role="img" aria-labelledby="dg-prim-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-prim-t">The primary views of the recipes page: the table, and the card of a recipe as a modal on a desktop and as a full-screen sheet on a phone</title>
<rect class="dg-p" x="10" y="10" width="650" height="380" rx="8"/>
<rect class="dg-i" x="22" y="22" width="626" height="22" rx="3"/><text class="dg-u" x="30" y="37">/recipes?card=7c1e9a40-…</text>
<g opacity=".3">
<text class="dg-h" x="26" y="76">Recipes</text>
<text class="dg-l" x="26" y="100">Name</text><text class="dg-l" x="330" y="100">Style</text><text class="dg-l" x="520" y="100">Status</text>
<text class="dg-v" x="26" y="124">Cherry Sour</text><text class="dg-v" x="330" y="124">Sour</text><text class="dg-v" x="520" y="124">Retired</text>
<text class="dg-v" x="26" y="148">Copper Pale Ale</text><text class="dg-v" x="330" y="148">Pale Ale</text><text class="dg-v" x="520" y="148">Draft</text>
<text class="dg-v" x="26" y="172">Harbor Lager</text><text class="dg-v" x="330" y="172">Lager</text><text class="dg-v" x="520" y="172">Active</text>
<text class="dg-v" x="26" y="196">Hazy Daze IPA</text><text class="dg-v" x="330" y="196">IPA</text><text class="dg-v" x="520" y="196">Active</text>
<text class="dg-v" x="26" y="220">Midnight Stout</text><text class="dg-v" x="330" y="220">Stout</text><text class="dg-v" x="520" y="220">Active</text>
<text class="dg-v" x="26" y="244">Old Mill Porter</text><text class="dg-v" x="330" y="244">Porter</text><text class="dg-v" x="520" y="244">Active</text>
</g>
<rect class="dg-m" x="110" y="80" width="460" height="284" rx="8"/>
<rect class="dg-tb" x="120" y="72" width="150" height="16" rx="3"/><text class="dg-t" x="125" y="84">?card=&lt;id&gt;</text>
<rect class="dg-tb" x="478" y="72" width="50" height="16" rx="3"/><text class="dg-t" x="483" y="84">&amp;edit</text>
<text class="dg-h" x="126" y="110">Hazy Daze IPA</text>
<rect class="dg-b" x="480" y="94" width="48" height="24" rx="4"/><text class="dg-bt" x="492" y="110">Edit</text>
<text class="dg-h" x="544" y="110">×</text>
<text class="dg-l" x="126" y="138">Style</text><text class="dg-v" x="126" y="155">IPA</text>
<text class="dg-l" x="250" y="138">Status</text><rect class="dg-ok" x="250" y="143" width="52" height="18" rx="9"/><text class="dg-okt" x="261" y="156">Active</text>
<text class="dg-l" x="390" y="138">Target ABV</text><text class="dg-v" x="390" y="155">6.8 %</text>
<text class="dg-st" x="126" y="188">Batches (12)</text>
<text class="dg-l" x="126" y="206">Batch</text><text class="dg-l" x="300" y="206">Status</text><text class="dg-l" x="420" y="206">Brew date</text>
<line class="dg-g" x1="126" y1="212" x2="554" y2="212"/>
<text class="dg-a" x="126" y="230">B-2026-044</text><text class="dg-v" x="300" y="230">Fermenting</text><text class="dg-v" x="420" y="230">2026-11-12</text>
<text class="dg-a" x="126" y="252">B-2026-039</text><text class="dg-v" x="300" y="252">Complete</text><text class="dg-v" x="420" y="252">2026-10-21</text>
<text class="dg-l" x="126" y="274">A link here navigates to the batches page. Back returns.</text>
<text class="dg-st" x="126" y="304">▸ Details</text>
<rect class="dg-b" x="126" y="318" width="126" height="24" rx="4"/><text class="dg-bt" x="136" y="334">Show all fields</text>
<text class="dg-l" x="26" y="382">desktop: a modal over the list. The list keeps its sort, page, and filters.</text>
<rect class="dg-p" x="680" y="10" width="310" height="380" rx="8"/>
<rect class="dg-i" x="692" y="22" width="286" height="22" rx="3"/><text class="dg-u" x="700" y="37">/recipes?card=7c1e…</text>
<text class="dg-h" x="696" y="78">Hazy Daze IPA</text>
<rect class="dg-b" x="896" y="62" width="48" height="24" rx="4"/><text class="dg-bt" x="908" y="78">Edit</text>
<text class="dg-h" x="958" y="78">×</text>
<text class="dg-l" x="696" y="106">Style</text><text class="dg-v" x="696" y="123">IPA</text>
<text class="dg-l" x="696" y="146">Status</text><rect class="dg-ok" x="696" y="151" width="52" height="18" rx="9"/><text class="dg-okt" x="707" y="164">Active</text>
<text class="dg-l" x="696" y="186">Target ABV</text><text class="dg-v" x="696" y="203">6.8 %</text>
<text class="dg-st" x="696" y="234">Batches (12)</text>
<text class="dg-a" x="696" y="256">B-2026-044</text><text class="dg-v" x="860" y="256">Fermenting</text>
<text class="dg-a" x="696" y="278">B-2026-039</text><text class="dg-v" x="860" y="278">Complete</text>
<text class="dg-st" x="696" y="312">▸ Details</text>
<rect class="dg-b" x="696" y="326" width="126" height="24" rx="4"/><text class="dg-bt" x="706" y="342">Show all fields</text>
<text class="dg-l" x="696" y="382">phone: a full-screen sheet</text>
</svg>
<figcaption>The recipes page. The data table is the primary list view. A row opens the primary card as a modal (<code>card=&lt;id&gt;</code>); on a phone it is a full-screen sheet. The card names <code>:update</code>, so it has <b>Edit</b>, which adds <code>edit</code>. The batches are in view mode only (<code>only [:read]</code>).</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.RecipeLive do
  use PyroManiac, resource: Brewery.Recipe

  page do
    route "/recipes"
    exclude [:list, :activate, :retire, :destroy]
  end

  view :read do
    type :data_table
    primary? true
    default_sort "name"

    exclude [
      :id,
      :description,
      :target_abv,
      :target_og,
      :target_fg,
      :gravity_spread,
      :ingredient_count,
      :batch_count,
      :recipe_ingredients,
      :batches,
      :photos,
      :photos_urls
    ]

    column :name
    column :style
    column :status
  end

  view :read do
    type :card
    primary? true
    presentation :modal
    action [:create, :update], :guard

    field :name, autofocus: true, only: [:create, :update]

    row do
      select :style
      select :status
      field :target_abv
    end

    related :batches do
      only [:read]
      type :data_table
      count :batch_count
      field :batch_number
      field :status
      field :brew_date
      link_to BreweryWeb.BatchLive
    end

    section :details do
      collapsible? true
      collapsed? true
      field :target_og
      field :target_fg
      field :description, type: :textarea
    end
  end
end
```

<!-- tabs-close -->

### Card presentation

`presentation` says where a card opens: `:modal` (the default) over the
page, `:drawer` at the side, or `:page` (the full page, without the list,
with a link back). On a phone a modal and a drawer are a full-screen sheet.
A modal and a drawer keep the list behind them: its sort, page, and
filters. Escape or **Close** closes them. The `width` of the card sets the
width of a modal or a drawer (`:record`, the default, `:form`, `:prose`,
or `:full`); with `presentation :page`, it is the width of the page, as
for any view.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 250" role="img" aria-labelledby="dg-pres-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-pres-t">Three presentations of a card: a modal over the recipes, a drawer at the side of the batches, and a full page</title>
<rect class="dg-p" x="10" y="10" width="316" height="230" rx="8"/>
<rect class="dg-tb" x="20" y="2" width="128" height="16" rx="3"/><text class="dg-t" x="25" y="14">presentation :modal</text>
<g opacity=".3"><text class="dg-st" x="24" y="40">Recipes</text>
<line class="dg-g" x1="24" y1="56" x2="312" y2="56"/><line class="dg-g" x1="24" y1="80" x2="312" y2="80"/><line class="dg-g" x1="24" y1="104" x2="312" y2="104"/><line class="dg-g" x1="24" y1="128" x2="312" y2="128"/><line class="dg-g" x1="24" y1="152" x2="312" y2="152"/><line class="dg-g" x1="24" y1="176" x2="312" y2="176"/><line class="dg-g" x1="24" y1="200" x2="312" y2="200"/>
</g>
<rect class="dg-m" x="56" y="56" width="224" height="150" rx="6"/>
<text class="dg-st" x="70" y="80">Hazy Daze IPA</text><text class="dg-st" x="262" y="80">×</text>
<text class="dg-l" x="70" y="104">Style</text><text class="dg-v" x="70" y="120">IPA</text>
<text class="dg-l" x="170" y="104">Target ABV</text><text class="dg-v" x="170" y="120">6.8 %</text>
<text class="dg-l" x="24" y="230">/recipes?card=7c1e…</text>
<rect class="dg-p" x="342" y="10" width="316" height="230" rx="8"/>
<rect class="dg-tb" x="352" y="2" width="134" height="16" rx="3"/><text class="dg-t" x="357" y="14">presentation :drawer</text>
<g opacity=".3"><text class="dg-st" x="356" y="40">Batches</text>
<text class="dg-v" x="356" y="72">B-2026-044</text><text class="dg-v" x="356" y="96">B-2026-043</text><text class="dg-v" x="356" y="120">B-2026-042</text><text class="dg-v" x="356" y="144">B-2026-041</text>
</g>
<rect class="dg-m" x="478" y="22" width="170" height="196" rx="6"/>
<text class="dg-st" x="490" y="44">Complete B-2026-042</text>
<text class="dg-l" x="490" y="62">OG</text><rect class="dg-i" x="490" y="66" width="70" height="20" rx="3"/><text class="dg-v" x="496" y="81">1.048</text><rect class="dg-foc" x="489" y="65" width="72" height="22" rx="4"/>
<text class="dg-l" x="566" y="62">FG</text><rect class="dg-i" x="566" y="66" width="70" height="20" rx="3"/><text class="dg-v" x="572" y="81">1.012</text>
<text class="dg-l" x="490" y="100">ABV</text><rect class="dg-i" x="490" y="104" width="70" height="20" rx="3"/><text class="dg-v" x="496" y="119">4.9</text>
<text class="dg-l" x="566" y="100">Volume (L)</text><rect class="dg-i" x="566" y="104" width="70" height="20" rx="3"/><text class="dg-v" x="572" y="119">1180</text>
<text class="dg-l" x="490" y="138">Package date</text><rect class="dg-i" x="490" y="142" width="146" height="20" rx="3"/><text class="dg-v" x="496" y="157">2026-11-30</text>
<rect class="dg-tb" x="490" y="166" width="88" height="14" rx="3"/><text class="dg-t" x="494" y="177">action :complete</text>
<rect class="dg-pri" x="582" y="184" width="54" height="24" rx="4"/><text class="dg-bw" x="592" y="200">Save</text>
<text class="dg-l" x="356" y="230">/batches?card=list:5b02…&amp;edit</text>
<rect class="dg-p" x="674" y="10" width="316" height="230" rx="8"/>
<rect class="dg-tb" x="684" y="2" width="122" height="16" rx="3"/><text class="dg-t" x="689" y="14">presentation :page</text>
<text class="dg-a" x="688" y="40">← Recipes</text>
<text class="dg-h" x="688" y="68">Hazy Daze IPA</text>
<text class="dg-l" x="688" y="94">Style</text><text class="dg-v" x="688" y="110">IPA</text>
<text class="dg-l" x="790" y="94">Target ABV</text><text class="dg-v" x="790" y="110">6.8 %</text>
<text class="dg-l" x="688" y="134">Target OG</text><text class="dg-v" x="688" y="150">1.064</text>
<text class="dg-l" x="790" y="134">Target FG</text><text class="dg-v" x="790" y="150">1.012</text>
<text class="dg-st" x="688" y="182">Batches (12)</text>
<text class="dg-l" x="688" y="230">the full page, no list</text>
</svg>
<figcaption>A modal over the list, a drawer at the side (here a second card of the batches page, <code>card=list:&lt;id&gt;</code>, in the form of its <code>:complete</code> action), and a full page with a link back to the list.</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.BatchLive do
  use PyroManiac, resource: Brewery.Batch

  page do
    route "/batches"
  end

  view :read do
    type :data_table
    primary? true
    # ...
  end

  view :read do
    type :card
    primary? true
    action [:create, :update], :guard
    # the record tree: refer to The record tree
  end

  view :list do
    type :card
    label "Complete"
    presentation :drawer
    action :complete, :recover

    field :batch_number
    field :actual_og, label: "OG", autofocus: true
    field :actual_fg, label: "FG"
    field :actual_abv, label: "ABV"
    field :volume_liters, label: "Volume (L)"
    field :package_date
  end
end
```

<!-- tabs-close -->

The second card opens from a link with `single_view :list`, from an extra
action, or from the URL. Its param names the view: `card=list:<id>`. Its
tree is the form of `:complete`; `:batch_number` is not an input of the
action, so it shows its value.

### Previous and next record (planned)

There is no DSL for it yet (refer to the record navigation in
`ROADMAP.md`). The design: a card that opens from a list view offers
**Previous** and **Next** in the context of that list (its filter, sort,
and page), with its position ("3 of 120") when the list has a count. At
the end of a page, **Next** opens the first record of the next page. A card
that opens from a direct link has no list, so no previous and next. The
buttons have keyboard shortcuts and respect the unsaved-changes guard of an
open form. The renderer rules are in
[Previous and next record](../renderers/renderer-pages.md#previous-and-next-record-planned).

## Searches

A `search` is a predefined filter of the page, at the top level of the
page (no `searches do` block): a **quick chip** of the filter bar of each
list view ([Filters and sorts](#filters-and-sorts)). It is a small form:
each `field` gives one predicate. Selecting the chip opens its form (a
popover, or a tab of the filter panel as in the figure); applying it adds
its predicates to the filter of the list as one chip.

| DSL | The UI |
|---|---|
| `search :name` | A quick chip (`label`, default: the humanized name). |
| `operator` (search) | How the predicates of the fields combine: `:and` or `:or`. |
| `interactive? false` | The inputs are disabled: a fixed, read-only filter. |
| `field :name` | An input (`label`). `value` fills it. |
| `source` | The fields that the value matches (joined with `or`). |
| `operator` (field), `negated?` | The predicate (`:contains`, `:eq`, ...) and `not`. |

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 210" role="img" aria-labelledby="dg-srch-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-srch-t">The search tabs of the recipes table: a text search on the name and the notes, and a read-only search for the recipes that are not retired</title>
<rect class="dg-p" x="10" y="10" width="600" height="190" rx="8"/>
<text class="dg-tab" x="26" y="42">Filters</text><text class="dg-st" x="96" y="42">Name or notes</text><text class="dg-tab" x="214" y="42">Not retired</text>
<line class="dg-g" x1="22" y1="50" x2="598" y2="50"/><line class="dg-on" x1="96" y1="50" x2="196" y2="50"/>
<rect class="dg-tb" x="300" y="30" width="96" height="16" rx="3"/><text class="dg-t" x="305" y="42">search :text</text>
<text class="dg-l" x="26" y="74">Contains</text><rect class="dg-i" x="26" y="80" width="260" height="24" rx="3"/><text class="dg-v" x="34" y="97">hazy</text>
<rect class="dg-tb" x="296" y="84" width="234" height="16" rx="3"/><text class="dg-t" x="301" y="96">field :text · source [:name, ...]</text>
<text class="dg-l" x="26" y="132">Name</text><text class="dg-l" x="250" y="132">Style</text><text class="dg-l" x="400" y="132">Status</text>
<line class="dg-g" x1="26" y1="138" x2="598" y2="138"/>
<text class="dg-v" x="26" y="158">Hazy Daze IPA</text><text class="dg-v" x="250" y="158">IPA</text><text class="dg-v" x="400" y="158">Active</text>
<text class="dg-v" x="26" y="182">Copper Pale Ale</text><text class="dg-v" x="250" y="182">Pale Ale</text><text class="dg-v" x="400" y="182">Draft</text>
<text class="dg-l" x="160" y="182">"hazy" in the notes</text>
<rect class="dg-p" x="630" y="10" width="360" height="190" rx="8"/>
<text class="dg-tab" x="646" y="42">Filters</text><text class="dg-tab" x="716" y="42">Name or notes</text><text class="dg-st" x="834" y="42">Not retired</text>
<line class="dg-g" x1="642" y1="50" x2="978" y2="50"/><line class="dg-on" x1="834" y1="50" x2="912" y2="50"/>
<rect class="dg-tb" x="646" y="60" width="260" height="16" rx="3"/><text class="dg-t" x="651" y="72">search :not_retired · interactive? false</text>
<g opacity=".55">
<text class="dg-l" x="646" y="98">Status</text>
<rect class="dg-i" x="646" y="104" width="90" height="24" rx="3"/><text class="dg-v" x="654" y="121">is not</text>
<rect class="dg-i" x="742" y="104" width="120" height="24" rx="3"/><text class="dg-v" x="750" y="121">Retired</text>
</g>
<rect class="dg-tb" x="646" y="138" width="240" height="16" rx="3"/><text class="dg-t" x="651" y="150">operator :eq · negated? true · value</text>
<text class="dg-l" x="646" y="182">Disabled inputs: the filter is fixed.</text>
</svg>
<figcaption>Two search tabs. <b>Name or notes</b> matches the typed text in two fields. <b>Not retired</b> is a fixed filter with disabled inputs.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.RecipeLive
search :text do
  label "Name or notes"

  field :text do
    label "Contains"
    source [:name, :description]
  end
end

search :not_retired do
  interactive? false
  operator :and

  field :status do
    operator :eq
    negated? true
    value :retired
  end
end
```

<!-- tabs-close -->

## Filters and sorts

Each list view has the same filter and sort experience: a `:data_table`,
a `:grid`, a `:list`, a `:kanban`, a `:calendar`, a `:gantt`, a
`:timeline`, and a `:card` that is the list view. The same filter bar, the
same chips, the same presets, the same URL, so a user who filters one list
can filter each one. Only the place of the sort control differs (the
headers of a table; a sort menu for the others). A `related` with
`delegate_to` shows the list view of the other page with its filter bar,
scoped to the record.

| DSL of the page | The UI |
|---|---|
| (always) | The **simple mode**: the chips of the active filter, the quick chips of the searches, the filter of each filterable field, and the sort. |
| `custom_filters? true` | The **advanced view** in addition: a filter builder, with groups. Without it, no builder. |
| `filter_storage :client` | **Save** in the advanced view: the presets of the user, in the browser only. |
| `filter_storage MyApp.FilterPreset` | **Save**: the presets are records of a resource with `PyroManiac.FilterPresets` ([Presets](#presets)). |
| `shared_filters? true` | **Share** on a saved preset; the presets that other users share ([Sharing](#sharing)). |

`filter_storage` requires `custom_filters? true`, and `shared_filters?`
requires a resource in `filter_storage` (compile errors otherwise).

The filter, the sort, the search, and the page of a list are in the URL,
so a link, a reload, Back, and Forward give the same list, in each
renderer. A change of the filter, the sort, or the search goes back to the
first page. The read action of the view runs with the filter of the user
added to its own filter and policies, never in place of them: a filter
cannot widen what the user can read.

**What the user can filter and sort.** The `filter` and `sort` of the
`expose` of the read action decide it ([The surface](surface.md)):
`filter [:*, :recipe]` offers the public fields of the resource (without
`filterable? false`) and the fields of the recipe ("Recipe › Style"), one
level deep, and a filter on the recipe itself (a combobox of the recipes).
In a `:data_table`, a column with `filterable? false` is not offered. A
calculation with a required argument, a private field, a map, a struct,
and a file are never offered. A field that is not offered cannot be
filtered from a URL either.

**The operators** depend on the type of the field, with labels in plain
language:

| The type | The operators | The input |
|---|---|---|
| a string | contains, is, is not, is one of, is empty | A text input; "is one of" takes several values. |
| a number | is, is not, less than, greater than, less than or equal, greater than or equal, is empty; a range | A number input, with the constraints of the attribute. |
| a date or a date-time | is, is before, is after, on or before, on or after, is empty; between | A date picker; relative values ("the last 7 days") resolve to dates. |
| a boolean | is, is empty | Yes, no, any. |
| an enum or `one_of` | is, is not, is one of, is empty | A select of the values (their labels). |
| a relationship to one record | is, is one of, is empty | A combobox of the destination (its `default_label`). |
| an array | has, is empty | The input of the item type. |

An invalid value shows its error at its input, chip, or row; the list
keeps its last valid result, and the inputs of the user stay.

### Simple mode: chips

Simple mode is the default for every list view, with or without
`custom_filters?`. Above the list:

- **One chip for each active filter**, and one for each active search. A
  chip reads "Field operator value" ("Status is Fermenting", "Brew date
  after 2026-11-01"); a chip of a relationship shows the label of the
  record, as a link with the `link_to` of its column. An `or` or a `not`
  is one group chip ("2 conditions"), which opens the advanced view.
- **Edit a chip**: a click opens its value and its operator.
- **Remove a chip**: its × button, or Backspace or Delete on a focused
  chip.
- **+ Filter**: the filterable fields (with a search), then the operator
  and the value.
- **Clear all**: removes every chip and every search; the `default_sort`
  stays.
- **Quick chips**: each `search` of the page ([Searches](#searches)). A
  search with inputs opens its small form; applied, it becomes an active
  chip with its values. A search with `interactive? false` applies at once.
- **Presets**: the saved and the shared presets, in a menu of the filter
  bar ([Presets](#presets)).

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 120" role="img" aria-labelledby="dg-chip-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-chip-t">Three filter chips above the batches table</title>
<rect class="dg-p" x="10" y="10" width="980" height="100" rx="8"/>
<rect class="dg-b" x="26" y="24" width="220" height="26" rx="13"/><text class="dg-v" x="38" y="42">Recipe:</text><text class="dg-a" x="92" y="42">Hazy Daze IPA</text><text class="dg-v" x="228" y="42">×</text>
<rect class="dg-b" x="258" y="24" width="180" height="26" rx="13"/><text class="dg-v" x="270" y="42">Status: Fermenting</text><text class="dg-v" x="420" y="42">×</text>
<rect class="dg-b" x="450" y="24" width="240" height="26" rx="13"/><text class="dg-v" x="462" y="42">Brew date after: 2026-11-01</text><text class="dg-v" x="672" y="42">×</text>
<text class="dg-a" x="710" y="42">Clear all</text>
<text class="dg-l" x="26" y="76">Batch</text><text class="dg-l" x="180" y="76">Recipe</text><text class="dg-l" x="340" y="76">Status</text><text class="dg-l" x="520" y="76">Brew date</text>
<line class="dg-g" x1="26" y1="82" x2="976" y2="82"/>
<text class="dg-v" x="26" y="100">B-2026-044</text><text class="dg-a" x="180" y="100">Hazy Daze IPA</text><text class="dg-v" x="340" y="100">Fermenting</text><text class="dg-v" x="520" y="100">2026-11-12</text>
</svg>
<figcaption>Three filters on the batches table. The recipe chip shows the recipe as a link. × removes one filter.</figcaption>
</figure>

### DSL

```elixir
column :recipe do
  link_to BreweryWeb.RecipeLive
end
```

<!-- tabs-close -->

### The advanced view

With `custom_filters? true`, the filter bar has **Advanced** (and a group
chip opens it). The advanced view is a filter builder of the same filter:

- A **row** is one predicate: the field (a searchable select, with the
  paths of the relationships), the operator, and the value.
- A **group** joins its rows and groups with **All of** (`and`) or **Any
  of** (`or`), or negates them (**None of**). **+ Condition** adds a row,
  **+ Group** a nested group. Groups nest at least three levels deep.
- **Apply** writes the filter of the list; **Cancel** keeps it as it was.
  A filter that the chips can show goes back to chips.
- **Save**, **Update**, **Delete**, and **Share** of the presets are here
  when the page has a `filter_storage`.

Without `custom_filters?`, there is no builder: the user has the chips of
single predicates, the searches, and the filter of a list link.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 300" role="img" aria-labelledby="dg-fb-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-fb-t">The filter bar of the batches table with chips, a quick chip, and the presets, and the advanced view with a nested group</title>
<rect class="dg-p" x="10" y="10" width="980" height="280" rx="8"/>
<rect class="dg-b" x="26" y="24" width="168" height="26" rx="13"/><text class="dg-v" x="38" y="42">Status is Fermenting</text><text class="dg-v" x="176" y="42">×</text>
<rect class="dg-b" x="202" y="24" width="138" height="26" rx="13"/><text class="dg-v" x="214" y="42">2 conditions</text><text class="dg-v" x="322" y="42">×</text>
<rect class="dg-i" x="350" y="24" width="96" height="26" rx="13"/><text class="dg-v" x="362" y="42">+ Filter</text>
<rect class="dg-s" x="456" y="24" width="108" height="26" rx="13"/><text class="dg-v" x="468" y="42">Not retired</text>
<rect class="dg-tb" x="456" y="54" width="108" height="16" rx="3"/><text class="dg-t" x="461" y="66">search (quick)</text>
<text class="dg-a" x="580" y="42">Clear all</text>
<rect class="dg-b" x="676" y="24" width="96" height="26" rx="4"/><text class="dg-bt" x="688" y="41">Advanced</text>
<rect class="dg-b" x="780" y="24" width="120" height="26" rx="4"/><text class="dg-bt" x="792" y="41">Presets ▾</text>
<rect class="dg-tb" x="676" y="54" width="200" height="16" rx="3"/><text class="dg-t" x="681" y="66">custom_filters? · filter_storage</text>
<rect class="dg-m" x="26" y="80" width="948" height="176" rx="6"/>
<text class="dg-st" x="40" y="104">All of</text><text class="dg-v" x="86" y="104">▾</text>
<rect class="dg-i" x="40" y="114" width="200" height="24" rx="3"/><text class="dg-v" x="48" y="131">Status</text>
<rect class="dg-i" x="248" y="114" width="120" height="24" rx="3"/><text class="dg-v" x="256" y="131">is</text>
<rect class="dg-i" x="376" y="114" width="200" height="24" rx="3"/><text class="dg-v" x="384" y="131">Fermenting</text><text class="dg-v" x="600" y="131">×</text>
<rect class="dg-c" x="40" y="146" width="900" height="72" rx="4"/>
<text class="dg-st" x="52" y="166">Any of</text><text class="dg-v" x="100" y="166">▾</text>
<rect class="dg-i" x="60" y="174" width="180" height="20" rx="3"/><text class="dg-v" x="66" y="189">Brew date</text>
<rect class="dg-i" x="248" y="174" width="120" height="20" rx="3"/><text class="dg-v" x="254" y="189">is after</text>
<rect class="dg-i" x="376" y="174" width="200" height="20" rx="3"/><text class="dg-v" x="382" y="189">2026-11-01</text>
<rect class="dg-i" x="60" y="198" width="180" height="16" rx="3"/><text class="dg-v" x="66" y="211">Recipe › Style</text>
<rect class="dg-i" x="248" y="198" width="120" height="16" rx="3"/><text class="dg-v" x="254" y="211">is</text>
<rect x="376" y="198" width="200" height="16" rx="3" fill="none" stroke="#dc2626"/><text class="dg-v" x="382" y="211">Hazy</text>
<text class="dg-errt" x="586" y="211">is not a valid style</text>
<text class="dg-a" x="40" y="242">+ Condition</text><text class="dg-a" x="130" y="242">+ Group</text>
<rect class="dg-b" x="760" y="226" width="64" height="24" rx="4"/><text class="dg-bt" x="771" y="242">Cancel</text>
<rect class="dg-b" x="830" y="226" width="54" height="24" rx="4"/><text class="dg-bt" x="842" y="242">Save</text>
<rect class="dg-pri" x="890" y="226" width="70" height="24" rx="4"/><text class="dg-bw" x="904" y="242">Apply</text>
<text class="dg-l" x="26" y="278">1–25 of 41 batches. Live region: "41 batches".</text>
</svg>
<figcaption>The filter bar: a chip, a group chip, a quick chip of a search, and the presets. The advanced view builds the same filter, with a nested <b>Any of</b> group; an invalid value shows its error at its row.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive
page do
  route "/batches"
  custom_filters? true
  filter_storage Brewery.FilterPreset
  shared_filters? true
end

search :not_retired do
  interactive? false

  field :status do
    operator :eq
    negated? true
    value :retired
  end
end
```

<!-- tabs-close -->

### Sorts

The sort of a list view starts with the `default_sort` of the view (a sort
input string such as `"-brew_date,batch_number"`, or a sort list), else
the sort of the read action, else none. A kanban sorts by its priority.

- **A table**: a click on a sortable header sorts by it, and cycles
  ascending, descending, off. Shift+click adds the column to the sort (a
  multi-sort, with the position 1, 2, ... in the headers). Ctrl+click (Cmd
  on macOS) chooses where the empty values go. A column on a field of the
  exposed `sort` is sortable unless `sortable? false` (offset pages and no
  pages) or `keyset_sortable? false` (keyset pages); both default to
  `true`, and turn off for a field that cannot sort.
- **The other list types**: a sort menu with the sortable fields, a
  direction for each, and **+ Then by**. A `:calendar`, a `:gantt`, and a
  `:timeline` sort by their dates.
- **Manual order**: with `reorder? true`, the sort by the rank turns the
  drag handles on ([Views](views.md)).

```elixir
view :read do
  type :data_table
  primary? true
  default_sort "-brew_date,batch_number"

  column :batch_number
  column :brew_date

  column :notes do
    sortable? false
  end
end
```

### Presets

A **preset** is a saved filter and sort of a list view, with a name. The
searches of the page are presets fixed in the DSL; the presets of the
users exist with `custom_filters? true` and a `filter_storage`.

- **Apply**: selecting a preset replaces the filter and the sort of the
  list, and marks the preset as active ("Fermenting IPAs", or "Fermenting
  IPAs (changed)" after an edit). An **interactive** preset of a search
  shows the fields of the search first, filled with its values.
- **Save** asks for a name (and **Interactive**, and **Share** with
  `shared_filters?`). **Update** saves the current state into the active
  preset; **Rename** and **Delete** change it. The delete asks with
  `delete_preset_confirm` of the page (a message), or not (`false`). A page
  with `filter_storage` does not compile without it.
- A preset applies only its filter and sort, through the same checks as a
  URL: a field that the page no longer offers is dropped, and a preset
  cannot widen what the user can read.

With `filter_storage :client`, the presets are in the browser only: not
on the server, not shared, and not on another device. With a resource,
they are records of a resource with the `PyroManiac.FilterPresets`
extension. The extension adds the attributes, the timestamps, the actions
(`for_page`, `create`, `update`, `destroy`), and with `owner` a
`belongs_to :owner`, set to the actor on create. Its policies decide who
reads and changes a preset:

```elixir
defmodule Brewery.FilterPreset do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.FilterPresets],
    authorizers: [Ash.Policy.Authorizer]

  filter_presets do
    owner Brewery.Staff
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(owner_id == ^actor(:id))
      authorize_if expr(shared? == true)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(owner_id == ^actor(:id))
    end
  end
end
```

```elixir
defmodule BreweryWeb.BatchLive do
  use PyroManiac, resource: Brewery.Batch

  page do
    route "/batches"
    custom_filters? true
    filter_storage Brewery.FilterPreset
    shared_filters? true
  end
end
```

### Sharing

With `shared_filters? true`, a saved preset has **Share**, and the menu of
the presets shows the presets that other users share, in their own group
("Shared", with the name of the owner). Who can share a preset and who sees
a shared one is decided only by the policies of the preset resource: in the
example above, each user reads their own presets and the shared ones, and
changes only their own.

## Links

`link_to Page` links to another page. It is on a column, a `field` (a
relationship, read-only), a `combobox`, a `field` of `related`, or
`related`. A node has at most one `link_to`.

`open` says how a click on a record opens it: `:navigate` (the default)
goes to the page of the record; `:stack` opens its card in a layer over the
current page or card (a dialog on a dialog), and `:replace` in place of the
top layer. `presentation` (`:modal` or `:drawer`) gives the shape of the
layer, else the card decides. Close, Escape, and Back close the top layer;
the page below keeps its state. Refer to
[Layers](../renderers/renderer-pages.md#layers).

```elixir
column :supplier do
  link_to BreweryWeb.SuppliersPage do
    open :stack
  end
end
```

- **One record** (a `belongs_to`, a combobox, a read-only relationship
  field): the link opens the single view of the record on the page:
  `single_view`, else its primary single view.
- **Many records** (`related`, a `has_many` column): each record links to
  its single view, and a **list link** ("All 12 batches") opens a list view
  of the page filtered by the relationship: `list_view`, else its primary
  list view.
- A node without `link_to` has no link: the label is text.
- The link shows only if the user can open the target page; else the label
  is text, with no hint.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 210" role="img" aria-labelledby="dg-link-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-link-t">The batches table for a user who can open the recipes page, and for a user who cannot</title>
<rect class="dg-p" x="10" y="10" width="470" height="190" rx="8"/>
<rect class="dg-tb" x="20" y="2" width="194" height="16" rx="3"/><text class="dg-t" x="25" y="14">view :read · type :data_table</text>
<text class="dg-l" x="26" y="34">Head brewer</text>
<rect class="dg-tb" x="140" y="22" width="180" height="16" rx="3"/><text class="dg-t" x="145" y="34">column :recipe · link_to</text>
<rect class="dg-tb" x="370" y="22" width="80" height="16" rx="3"/><text class="dg-t" x="375" y="34">no link_to</text>
<text class="dg-l" x="26" y="54">Batch</text><text class="dg-l" x="140" y="54">Recipe</text><text class="dg-l" x="270" y="54">Status</text><text class="dg-l" x="370" y="54">Brewer</text>
<line class="dg-g" x1="26" y1="60" x2="466" y2="60"/>
<text class="dg-v" x="26" y="80">B-2026-044</text><text class="dg-a" x="140" y="80">Hazy Daze IPA</text><text class="dg-v" x="270" y="80">Fermenting</text><text class="dg-v" x="370" y="80">Ana Ruiz</text>
<text class="dg-v" x="26" y="104">B-2026-043</text><text class="dg-a" x="140" y="104">Midnight Stout</text><text class="dg-v" x="270" y="104">Conditioning</text><text class="dg-v" x="370" y="104">Ben Okafor</text>
<text class="dg-v" x="26" y="128">B-2026-042</text><text class="dg-a" x="140" y="128">Harbor Lager</text><text class="dg-v" x="270" y="128">Packaging</text><text class="dg-v" x="370" y="128">Dev Patel</text>
<text class="dg-v" x="26" y="152">B-2026-041</text><text class="dg-a" x="140" y="152">Cherry Sour</text><text class="dg-v" x="270" y="152">Cancelled</text><text class="dg-v" x="370" y="152">—</text>
<text class="dg-l" x="26" y="184">The recipe is a link: the user can open the recipes page.</text>
<rect class="dg-p" x="520" y="10" width="470" height="190" rx="8"/>
<text class="dg-l" x="536" y="34">Packaging staff: cannot open the recipes page</text>
<text class="dg-l" x="536" y="54">Batch</text><text class="dg-l" x="650" y="54">Recipe</text><text class="dg-l" x="780" y="54">Status</text><text class="dg-l" x="880" y="54">Brewer</text>
<line class="dg-g" x1="536" y1="60" x2="976" y2="60"/>
<text class="dg-v" x="536" y="80">B-2026-044</text><text class="dg-v" x="650" y="80">Hazy Daze IPA</text><text class="dg-v" x="780" y="80">Fermenting</text><text class="dg-v" x="880" y="80">Ana Ruiz</text>
<text class="dg-v" x="536" y="104">B-2026-043</text><text class="dg-v" x="650" y="104">Midnight Stout</text><text class="dg-v" x="780" y="104">Conditioning</text><text class="dg-v" x="880" y="104">Ben Okafor</text>
<text class="dg-v" x="536" y="128">B-2026-042</text><text class="dg-v" x="650" y="128">Harbor Lager</text><text class="dg-v" x="780" y="128">Packaging</text><text class="dg-v" x="880" y="128">Dev Patel</text>
<text class="dg-v" x="536" y="152">B-2026-041</text><text class="dg-v" x="650" y="152">Cherry Sour</text><text class="dg-v" x="780" y="152">Cancelled</text><text class="dg-v" x="880" y="152">—</text>
<text class="dg-l" x="536" y="184">The recipe is text, with no hint.</text>
</svg>
<figcaption>Column links on the batches table, for two users. The recipe column has <code>link_to</code>: a link if the user can open the recipes page, else text. The brewer column has no <code>link_to</code>.</figcaption>
</figure>

### DSL

```elixir
view :read do
  type :data_table
  primary? true
  column :batch_number

  column :recipe do
    link_to BreweryWeb.RecipeLive
  end

  column :status
  column :brewer
end

# a link to another card of the page
field :recipe do
  link_to BreweryWeb.RecipeLive do
    single_view :read
  end
end
```

<!-- tabs-close -->

### List links

A list link opens the list view of the other page, filtered by the
relationship, with the filter as a chip that the user can remove. The list
has its full sort, pages, and columns.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 300" role="img" aria-labelledby="dg-ll-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-ll-t">A list link: the batches of a recipe on its card, and the full batches table filtered to the recipe</title>
<rect class="dg-p" x="10" y="10" width="440" height="280" rx="8"/>
<text class="dg-h" x="26" y="42">Hazy Daze IPA</text>
<rect class="dg-s" x="22" y="64" width="416" height="210" rx="6"/>
<rect class="dg-tb" x="30" y="56" width="110" height="16" rx="3"/><text class="dg-t" x="35" y="68">related :batches</text>
<text class="dg-st" x="36" y="90">Batches (12)</text>
<text class="dg-a" x="320" y="90">All 12 batches →</text>
<rect class="dg-tb" x="226" y="96" width="208" height="16" rx="3"/><text class="dg-t" x="231" y="108">link_to BatchLive · list_view</text>
<text class="dg-l" x="36" y="126">Batch</text><text class="dg-l" x="170" y="126">Status</text><text class="dg-l" x="300" y="126">Brew date</text>
<line class="dg-g" x1="36" y1="132" x2="424" y2="132"/>
<text class="dg-a" x="36" y="152">B-2026-047</text><text class="dg-v" x="170" y="152">Planned</text><text class="dg-v" x="300" y="152">—</text>
<text class="dg-a" x="36" y="176">B-2026-044</text><text class="dg-v" x="170" y="176">Fermenting</text><text class="dg-v" x="300" y="176">2026-11-12</text>
<text class="dg-a" x="36" y="200">B-2026-039</text><text class="dg-v" x="170" y="200">Complete</text><text class="dg-v" x="300" y="200">2026-10-21</text>
<text class="dg-a" x="36" y="224">B-2026-031</text><text class="dg-v" x="170" y="224">Complete</text><text class="dg-v" x="300" y="224">2026-09-02</text>
<text class="dg-a" x="36" y="248">B-2026-027</text><text class="dg-v" x="170" y="248">Complete</text><text class="dg-v" x="300" y="248">2026-08-11</text>
<text class="dg-l" x="36" y="268">5 of 12 (limit 5). Each batch links to its single view.</text>
<line x1="456" y1="150" x2="500" y2="150" stroke="currentColor" stroke-opacity=".5"/>
<polyline points="492,145 500,150 492,155" fill="none" stroke="currentColor" stroke-opacity=".5"/>
<rect class="dg-p" x="510" y="10" width="480" height="280" rx="8"/>
<rect class="dg-i" x="522" y="22" width="456" height="22" rx="3"/><text class="dg-u" x="530" y="37">/batches?v[f][recipe_id][eq]=7c1e9a40-…</text>
<text class="dg-h" x="526" y="72">Batches</text>
<rect class="dg-b" x="526" y="84" width="220" height="26" rx="13"/><text class="dg-v" x="538" y="102">Recipe:</text><text class="dg-a" x="592" y="102">Hazy Daze IPA</text><text class="dg-v" x="728" y="102">×</text>
<text class="dg-l" x="526" y="134">Batch</text><text class="dg-l" x="650" y="134">Recipe</text><text class="dg-l" x="800" y="134">Status</text>
<line class="dg-g" x1="526" y1="140" x2="976" y2="140"/>
<text class="dg-v" x="526" y="160">B-2026-047</text><text class="dg-a" x="650" y="160">Hazy Daze IPA</text><text class="dg-v" x="800" y="160">Planned</text>
<text class="dg-v" x="526" y="184">B-2026-044</text><text class="dg-a" x="650" y="184">Hazy Daze IPA</text><text class="dg-v" x="800" y="184">Fermenting</text>
<text class="dg-v" x="526" y="208">B-2026-039</text><text class="dg-a" x="650" y="208">Hazy Daze IPA</text><text class="dg-v" x="800" y="208">Complete</text>
<text class="dg-l" x="526" y="232">…</text>
<text class="dg-l" x="526" y="268">The full table: sort, pages, columns. × removes the filter.</text>
</svg>
<figcaption>A list link. The card of a recipe shows 5 of its batches; each batch links to its single view. <b>All 12 batches</b> opens the batches table, filtered by the relationship (<code>recipe_id</code> is the recipe), with the filter as a chip.</figcaption>
</figure>

### DSL

```elixir
related :batches do
  type :data_table
  limit 5
  field :batch_number
  field :status
  field :brew_date

  link_to BreweryWeb.BatchLive do
    list_view :read
  end
end
```

<!-- tabs-close -->

## Related records

`related :rel` shows the records of a relationship of the record, in either
direction, at the top level of a tree (not in a nested form). They are
read-only in the forms: each record has its own page.

| Option | The UI |
|---|---|
| `type` | How they look: `:list` (the default), `:data_table` (the `field` entities are the columns), `:grid`, `:count`, or `:badge`. |
| `presentation` | Where they show: `:inline` in the record, or `:modal` or `:drawer` over the page. Over the page, the record shows the count as a button that opens them. |
| `delegate_to` | A page of the destination shows them with its own primary list view, scoped to the record (its sort, filters, and pages). |
| `count` | An aggregate or a calculation: the count in the heading. |
| `limit` | The maximum number of records inline (without `delegate_to`). |
| `label`, `description` | The heading (default: the humanized name), and text below it. |
| `empty_text` | The text with no record (default `"None"`). |
| `link_to` | Each record links to its page, with a list link ([List links](#list-links)). |
| `only`, `visible?`, `render` | The actions of the tree that show it; a condition on the record; a custom render ([Custom renders](custom-renders.md)). |

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 312" role="img" aria-labelledby="dg-rel-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-rel-t">The related records of a recipe: a count that opens a modal with the batches page, badges, and an inline table; and the modal</title>
<rect class="dg-p" x="10" y="10" width="470" height="292" rx="8"/>
<text class="dg-h" x="26" y="42">Hazy Daze IPA</text>
<rect class="dg-tb" x="26" y="56" width="300" height="16" rx="3"/><text class="dg-t" x="31" y="68">related :batches · type :count · :modal</text>
<text class="dg-l" x="26" y="92">Batches</text><text class="dg-a" x="26" y="110">12 batches ↗</text>
<rect class="dg-tb" x="26" y="124" width="270" height="16" rx="3"/><text class="dg-t" x="31" y="136">related :batches · type :badge · limit 4</text>
<text class="dg-l" x="26" y="158">Recent batches</text>
<rect class="dg-b" x="26" y="166" width="82" height="20" rx="10"/><text class="dg-bt" x="34" y="180">B-2026-047</text>
<rect class="dg-b" x="114" y="166" width="82" height="20" rx="10"/><text class="dg-bt" x="122" y="180">B-2026-044</text>
<rect class="dg-b" x="202" y="166" width="82" height="20" rx="10"/><text class="dg-bt" x="210" y="180">B-2026-039</text>
<rect class="dg-b" x="290" y="166" width="82" height="20" rx="10"/><text class="dg-bt" x="298" y="180">B-2026-031</text>
<text class="dg-l" x="380" y="180">+8</text>
<rect class="dg-tb" x="26" y="196" width="340" height="16" rx="3"/><text class="dg-t" x="31" y="208">related :recipe_ingredients · type :data_table · limit 3</text>
<text class="dg-l" x="26" y="230">Ingredient</text><text class="dg-l" x="250" y="230">Quantity</text>
<line class="dg-g" x1="26" y1="236" x2="464" y2="236"/>
<text class="dg-v" x="26" y="254">Maris Otter</text><text class="dg-v" x="250" y="254">5.5 kg</text>
<text class="dg-v" x="26" y="274">Citra</text><text class="dg-v" x="250" y="274">200 g</text>
<text class="dg-v" x="26" y="294">Mosaic</text><text class="dg-v" x="250" y="294">150 g</text>
<line x1="486" y1="106" x2="530" y2="106" stroke="currentColor" stroke-opacity=".5"/>
<polyline points="522,101 530,106 522,111" fill="none" stroke="currentColor" stroke-opacity=".5"/>
<rect class="dg-p" x="540" y="10" width="450" height="292" rx="8"/>
<g opacity=".3"><text class="dg-h" x="556" y="42">Hazy Daze IPA</text></g>
<rect class="dg-m" x="560" y="56" width="410" height="232" rx="8"/>
<rect class="dg-tb" x="570" y="48" width="300" height="16" rx="3"/><text class="dg-t" x="575" y="60">delegate_to BreweryWeb.BatchLive</text>
<text class="dg-h" x="576" y="92">Batches (12)</text><text class="dg-h" x="948" y="92">×</text>
<text class="dg-l" x="576" y="118">Batch ↓</text><text class="dg-l" x="700" y="118">Status</text><text class="dg-l" x="820" y="118">Brew date</text>
<line class="dg-g" x1="576" y1="124" x2="954" y2="124"/>
<text class="dg-v" x="576" y="144">B-2026-047</text><text class="dg-v" x="700" y="144">Planned</text><text class="dg-v" x="820" y="144">—</text>
<text class="dg-v" x="576" y="168">B-2026-044</text><text class="dg-v" x="700" y="168">Fermenting</text><text class="dg-v" x="820" y="168">2026-11-12</text>
<text class="dg-v" x="576" y="192">B-2026-039</text><text class="dg-v" x="700" y="192">Complete</text><text class="dg-v" x="820" y="192">2026-10-21</text>
<text class="dg-l" x="576" y="216">1–3 of 12  ‹ 1 2 3 4 ›</text>
<text class="dg-l" x="576" y="244">The primary list view of BatchLive, scoped to the recipe:</text>
<text class="dg-l" x="576" y="260">its own sort, filters, and pages. × closes it.</text>
</svg>
<figcaption>Related records: a count that opens a modal with a page of the destination, badges with a limit, and an inline table.</figcaption>
</figure>

### DSL

```elixir
related :batches do
  type :count
  presentation :modal
  delegate_to BreweryWeb.BatchLive
  count :batch_count
end

related :batches do
  type :badge
  label "Recent batches"
  description "The last batches of the recipe."
  limit 4
  only [:read]
  visible? expr(status != :draft)
end

related :recipe_ingredients do
  type :data_table
  limit 3
  empty_text "No ingredients yet"
  field :ingredient
  field :quantity
end
```

<!-- tabs-close -->

## Realtime

A view with realtime options changes on the notifications of its resource.
The resource needs a `realtime` section ([Realtime](surface.md#realtime)).

| Option | Values | The UI |
|---|---|---|
| `on_create` | `:prepend`, `:append`, `:reload`, `:notify`, `:none` | A new record shows at the top or the end, the page reloads, or a banner offers a reload. |
| `on_update` | `:replace`, `:reload`, `:notify`, `:none` | The record changes in place. |
| `on_destroy` | `:remove`, `:reload`, `:notify`, `:none` | The record goes. |
| `on_bulk` | `:reload`, `:notify`, `:none` | One message for a bulk operation (the actions in `bulk` of the `realtime` section). |

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 214" role="img" aria-labelledby="dg-rt-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-rt-t">Realtime: a new batch at the top of the table, a changed row, and a removed row; on the right, a banner that offers a reload</title>
<rect class="dg-p" x="10" y="10" width="560" height="194" rx="8"/>
<text class="dg-st" x="26" y="38">Batches</text>
<rect class="dg-hl" x="22" y="56" width="536" height="26"/><text class="dg-v" x="30" y="74">B-2026-048</text><text class="dg-a" x="140" y="74">Sunday Wheat</text><text class="dg-v" x="290" y="74">Planned</text>
<rect class="dg-tb" x="420" y="61" width="128" height="16" rx="3"/><text class="dg-t" x="425" y="73">on_create :prepend</text>
<text class="dg-v" x="30" y="104">B-2026-047</text><text class="dg-a" x="140" y="104">Hazy Daze IPA</text><text class="dg-v" x="290" y="104">Brewing</text>
<rect class="dg-foc" x="286" y="90" width="60" height="20" rx="3"/>
<rect class="dg-tb" x="420" y="91" width="128" height="16" rx="3"/><text class="dg-t" x="425" y="103">on_update :replace</text>
<g opacity=".3"><text class="dg-v" x="30" y="134">B-2026-041</text><text class="dg-v" x="140" y="134">Cherry Sour</text><text class="dg-v" x="290" y="134">Cancelled</text>
<line x1="26" y1="130" x2="400" y2="130" stroke="currentColor"/>
</g>
<rect class="dg-tb" x="420" y="121" width="128" height="16" rx="3"/><text class="dg-t" x="425" y="133">on_destroy :remove</text>
<text class="dg-v" x="30" y="164">B-2026-040</text><text class="dg-a" x="140" y="164">Old Mill Porter</text><text class="dg-v" x="290" y="164">Complete</text>
<text class="dg-l" x="26" y="194">The same page, the same sort: the rows change in place.</text>
<rect class="dg-p" x="590" y="10" width="400" height="194" rx="8"/>
<text class="dg-st" x="606" y="38">Batches (board)</text>
<rect class="dg-info" x="602" y="52" width="376" height="34" rx="6"/>
<text class="dg-infot" x="614" y="73">24 batches changed (Advance status).</text>
<rect class="dg-pri" x="900" y="58" width="68" height="22" rx="4"/><text class="dg-bw" x="912" y="73">Reload</text>
<rect class="dg-tb" x="606" y="96" width="114" height="16" rx="3"/><text class="dg-t" x="611" y="108">on_bulk :notify</text>
<g opacity=".3"><rect class="dg-s" x="606" y="122" width="110" height="70" rx="5"/><rect class="dg-s" x="730" y="122" width="110" height="70" rx="5"/><rect class="dg-s" x="854" y="122" width="110" height="70" rx="5"/></g>
</svg>
<figcaption>Left: the table applies each notification. Right: a bulk operation sends one message; the board offers one reload.</figcaption>
</figure>

### DSL

```elixir
view :read do
  type :data_table
  primary? true
  on_create :prepend
  on_update :replace
  on_destroy :remove
  on_bulk :reload
  # ...
end

view :kanban_read do
  type :kanban
  on_create :notify
  on_update :notify
  on_destroy :notify
  on_bulk :notify
end
```

<!-- tabs-close -->

A changed record is read again for each user, with the read of the view:
a user sees only what the policies let them read. A card follows its
record and the records of its `related` nodes, and says "Deleted" when its
record goes. A board moves the card of a change to its lane and place
without reading its lanes again ([Kanban boards](views.md#kanban-boards)).

With `track_presence? true` in the `page` section, the page also shows who
views it, who edits each record, and who moves a card of a board
([The page](#the-page)).
