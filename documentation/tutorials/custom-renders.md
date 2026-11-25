# Custom renders

The DSL describes most of the UI. Where it does not, a node takes custom
**content**: a text, an Ash expression on the record, or an
implementation for one renderer (a component). The same page still runs
in each renderer. For the renderer contract, refer to
[Custom renders](../renderers/renderer-custom-renders.md).

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

## Content

The content of a node is its `render`, its `description`, and (on a
column) its `label`. Each is an entity with the same three forms
(`PyroManiac.Content`):

| Form | For | Example |
|---|---|---|
| `"text"` | Every renderer: the literal text. | `description "Measured alcohol by volume."` |
| `expr(...)` | Every renderer: an Ash expression on the record. | `render expr(if status == :cancelled, do: "Cancelled", else: "In production")` |
| `Renderer, implementation` | One renderer. It overrides the text or the expression for that renderer. | `render PyroManiac.LiveView, BreweryWeb.Cells.Status` |

- A node has at most one text or expression, and one implementation for
  each renderer, for each of `render`, `description`, and `label`. More is
  a compile error.
- A node with a text or an expression satisfies every renderer. A node
  with implementations only needs one for each renderer of the page.
- A view and the page have no record: their own `render` and
  `description` are a text or implementations, no expression.
- The inputs (`field`, `select`, `combobox`, `input`, in a view or in a
  form) take `render Renderer, implementation` only. Their `description`
  takes the three forms.
- `description :inherit` (a view, a column, an input, an action, a bulk
  action) takes the description of the attribute, the argument, or the
  action, as a text.
- The refs of an expression are checked like a `decoration` (an unknown
  field is a compile error) and load with the record.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 220" role="img" aria-labelledby="dg-cnt-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-cnt-t">The status column of the batches table in two renderers: the LiveView renderer shows its implementation, a stage progress; the Solid renderer shows the text of the expression</title>
<rect class="dg-p" x="10" y="10" width="480" height="200" rx="8"/>
<text class="dg-st" x="26" y="38">PyroManiac.LiveView</text>
<text class="dg-l" x="26" y="70">Batch</text><text class="dg-l" x="160" y="70">Stage</text>
<circle cx="200" cy="66" r="6" class="dg-info"/><text class="dg-infot" x="198" y="70">i</text>
<rect class="dg-tb" x="230" y="58" width="96" height="16" rx="3"/><text class="dg-t" x="235" y="70">label "Stage"</text>
<line class="dg-g" x1="26" y1="78" x2="474" y2="78"/>
<text class="dg-v" x="26" y="100">B-2026-044</text>
<rect class="dg-ok" x="160" y="90" width="24" height="10" rx="2"/><rect class="dg-ok" x="188" y="90" width="24" height="10" rx="2"/><rect class="dg-info" x="216" y="90" width="24" height="10" rx="2"/><rect class="dg-b" x="244" y="90" width="24" height="10" rx="2"/><rect class="dg-b" x="272" y="90" width="24" height="10" rx="2"/>
<text class="dg-v" x="306" y="100">Fermenting · day 10</text>
<text class="dg-v" x="26" y="126">B-2026-041</text>
<rect class="dg-bad" x="160" y="116" width="24" height="10" rx="2"/><rect class="dg-bad" x="188" y="116" width="24" height="10" rx="2"/><rect class="dg-b" x="216" y="116" width="24" height="10" rx="2"/><rect class="dg-b" x="244" y="116" width="24" height="10" rx="2"/><rect class="dg-b" x="272" y="116" width="24" height="10" rx="2"/>
<text class="dg-v" x="306" y="126">Cancelled</text>
<rect class="dg-tb" x="26" y="140" width="384" height="16" rx="3"/><text class="dg-t" x="31" y="152">render PyroManiac.LiveView, BreweryWeb.Cells.Status</text>
<rect class="dg-m" x="26" y="166" width="250" height="30" rx="4"/><text class="dg-l" x="36" y="185">The production stage of the batch.</text>
<rect class="dg-tb" x="286" y="173" width="86" height="16" rx="3"/><text class="dg-t" x="291" y="185">description</text>
<rect class="dg-p" x="510" y="10" width="480" height="200" rx="8"/>
<text class="dg-st" x="526" y="38">PyroManiac.Solid (no implementation)</text>
<text class="dg-l" x="526" y="70">Batch</text><text class="dg-l" x="660" y="70">Stage</text>
<circle cx="700" cy="66" r="6" class="dg-info"/><text class="dg-infot" x="698" y="70">i</text>
<line class="dg-g" x1="526" y1="78" x2="974" y2="78"/>
<text class="dg-v" x="526" y="100">B-2026-044</text><text class="dg-v" x="660" y="100">In production</text>
<text class="dg-v" x="526" y="126">B-2026-041</text><text class="dg-v" x="660" y="126">Cancelled</text>
<rect class="dg-tb" x="526" y="140" width="290" height="16" rx="3"/><text class="dg-t" x="531" y="152">render expr(if status == :cancelled, ...)</text>
<text class="dg-l" x="526" y="185">The value of the expression, for each renderer without an implementation.</text>
</svg>
<figcaption>One column in two renderers. The label and the description are texts, for both. The render is an expression for every renderer, and an implementation for LiveView only: LiveView renders its component, Solid the value of the expression.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive, the table
column :status do
  label "Stage"
  description "The production stage of the batch."
  render expr(if status == :cancelled, do: "Cancelled", else: "In production")
  render PyroManiac.LiveView, BreweryWeb.Cells.Status
end

# BreweryWeb.BatchLive, the card
section :measurements do
  description expr(if is_nil(package_date), do: "Not packaged yet.", else: "Packaged.")
  field :actual_og
  field :actual_fg
end

field :notes do
  description :inherit
end
```

<!-- tabs-close -->

### Where content goes

| Entity | On |
|---|---|
| `render` | A view (a `:render` view needs one), a column, a node of a tree (`field`, `select`, `combobox`, `input`, `section`, `compound`, `related`, `workflow`, `tabs`, `tab`, `step`), an extra action, and a `command` of the palette ([Navigation](navigation.md#command-palette)). A `row`, `attachments`, `action`, and `bulk_action` have none. |
| `description` | A view, a column, an input (`field`, `select`, `combobox`, `input`), a `section`, `compound`, `step`, `related`, `attachments`, `workflow`, an `action`, a `bulk_action`, and the `page` section. Not a keyword option: `field :notes do description "..." end`. |
| `label` | A column (default: the capitalized name). The other nodes have `label` as an option (a string). |

## Implementations

`render Renderer, implementation` replaces the UI of a node for one
renderer: a cell, a value, a whole section, a related list, a step, an
extra action (its button and its content).

- The implementation renders the whole node.
- The implementation is any term: the renderer defines it (a component
  module, an import path, `{Module, props: [...]}`). Not a bare keyword
  list: the DSL reads it as the options of the entity. Wrap it in a tuple.
- Give one for each renderer of the page, or a text or an expression for
  the others. A node with implementations only and none for a renderer of
  the page is a compile error of that renderer.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 200" role="img" aria-labelledby="dg-rnd-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-rnd-t">A default status cell and a custom status cell with a progress of the stages, and a custom section of a recipe card</title>
<rect class="dg-p" x="10" y="10" width="470" height="180" rx="8"/>
<text class="dg-st" x="26" y="38">Default</text>
<text class="dg-l" x="26" y="62">Batch</text><text class="dg-l" x="140" y="62">Status</text>
<line class="dg-g" x1="26" y1="68" x2="466" y2="68"/>
<text class="dg-v" x="26" y="88">B-2026-044</text><text class="dg-v" x="140" y="88">Fermenting</text>
<text class="dg-st" x="26" y="122">render PyroManiac.LiveView, ...Cells.Status</text>
<text class="dg-v" x="26" y="150">B-2026-044</text>
<rect class="dg-ok" x="140" y="140" width="24" height="10" rx="2"/><rect class="dg-ok" x="168" y="140" width="24" height="10" rx="2"/><rect class="dg-info" x="196" y="140" width="24" height="10" rx="2"/><rect class="dg-b" x="224" y="140" width="24" height="10" rx="2"/><rect class="dg-b" x="252" y="140" width="24" height="10" rx="2"/><rect class="dg-b" x="280" y="140" width="24" height="10" rx="2"/>
<text class="dg-v" x="314" y="150">Fermenting · day 10</text>
<text class="dg-l" x="26" y="176">The same column; the cell is the component of the renderer.</text>
<rect class="dg-p" x="520" y="10" width="470" height="180" rx="8"/>
<text class="dg-h" x="536" y="40">Hazy Daze IPA</text>
<rect class="dg-c" x="532" y="54" width="446" height="122" rx="6"/>
<rect class="dg-tb" x="540" y="46" width="290" height="16" rx="3"/><text class="dg-t" x="545" y="58">section :targets · render ...TargetsChart</text>
<text class="dg-st" x="546" y="82">Targets</text>
<line class="dg-g" x1="546" y1="150" x2="960" y2="150"/>
<polyline points="556,100 640,112 724,130 808,142 892,146 950,147" fill="none" stroke="#2563eb" stroke-width="2"/>
<text class="dg-l" x="556" y="168">OG 1.064</text><text class="dg-l" x="890" y="168">FG 1.012</text>
<text class="dg-l" x="700" y="100">ABV 6.8 %</text>
</svg>
<figcaption>Custom renders. A cell of a column, and a whole section of a card. The renderer renders the implementation in place of the default UI.</figcaption>
</figure>

### DSL

```elixir
column :status do
  render PyroManiac.LiveView, BreweryWeb.Cells.Status
  render PyroManiac.Solid, "~/cells/Status"
end

section :targets do
  render PyroManiac.LiveView, {BreweryWeb.RecipeLive.TargetsChart, height: 120}
  field :target_og
  field :target_fg
  field :target_abv
end

field :pass_rate do
  render PyroManiac.LiveView, BreweryWeb.Fields.Percent
end

related :batches do
  render PyroManiac.LiveView, BreweryWeb.RecipeLive.BatchTimeline
end

step :review do
  review? true
  render PyroManiac.LiveView, BreweryWeb.BatchLive.ReviewStep
end
```

<!-- tabs-close -->

## The render view

A view of `type :render` is the escape hatch for a whole list view that
the DSL does not describe (a chart, a map, a floor plan of the tanks). It
needs a `render` implementation for each renderer (no text or
expression: the view has no record), and its `loads` give the records
that the component gets. It is not a primary view. For its UI and DSL,
refer to [The render view](views.md#the-render-view).

## Design expectations

- Prefer the DSL. A custom render is for what the DSL cannot say; a
  `decoration`, a `size`, or a text often is enough.
- Prefer a text or an expression to an implementation: it works in every
  renderer, with no code.
- An implementation renders the whole node, in the place of the default
  UI: it keeps the label and the accessible name of the node, works with
  the keyboard, and gives a text alternative of a chart.
- Keep an implementation small and about one node. A page with many
  custom renders is a sign of a missing feature of the DSL.

## Common mistakes

- Two texts or expressions, or two implementations for the same renderer,
  on one node.
- An expression in the own `render` or `description` of a view or of the
  page (no record).
- A text or an expression in the `render` of an input (`field`, `select`,
  `combobox`, `input`): it takes `render Renderer, implementation` only.
- A bare keyword list as the implementation
  (`render PyroManiac.LiveView, module: Foo`): wrap it in a tuple.
- `render Renderer` without an implementation: give the implementation, a
  string, or an expression.
- `description` as a keyword option (`field :notes, description: "..."`):
  it is an entity.
- A function for `render`, or `component`/`props`, `class`, or
  `render_cell_data` options: they are removed.
