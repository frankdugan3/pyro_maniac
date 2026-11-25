# The record layout

One **record tree** describes how a record shows: the sections, the values,
the tabs, and the related records. The tree is the nodes of a view. A
`:card` view shows it in **view mode** (the read action of the view). An
`action` of the card without nodes uses the same tree as its form, so
**Edit** switches the card to the update form in the same place, and
nothing moves. For the contract of a renderer, refer to
[Record Tree](../renderers/renderer-record-tree.md).

| Node | What it is | Refer to |
|---|---|---|
| `section :name` | A block with its own grid; with `path`, one block for each related record. | [The record tree](#the-record-tree), [Sections side by side](#sections-side-by-side), [Nested records and conditions](#nested-records-and-conditions) |
| `row` | Layout only: the children on one line. | [Rows and compounds](#rows-and-compounds) |
| `compound :name` | One value made of parts, with one label. | [Rows and compounds](#rows-and-compounds) |
| `field` | A value in view mode, an input in a form. | [Fields](#fields) |
| `select` | An input for a closed set of values. | [Selects](#selects) |
| `combobox` | An input that searches for its value. | [Comboboxes](#comboboxes), [Select many](#select-many) |
| `input :name, type` | An input of an app input type. | [Inputs with an input type](#inputs-with-an-input-type) |
| `related :rel` | The records of a relationship. | [Related records](#related-records) |
| `attachments :name` | The files of an AshStorage attachment. | [Attachments](#attachments) |
| `workflow` | The status of the state machine or the workflow. | [Workflow](#workflow) |
| `tabs` › `tab :name` | Partitions of the record. | [Tabs](#tabs) |
| `step :name` | A part of a long form. | [Steps](views.md#steps) |

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

## The record tree

The **record tree** is the nodes of a view. One tree serves view mode (the
read action of the view) and the form of each write action that uses it
(the actions of a card without nodes). An action with nodes has its own
tree, of the same nodes. The cards, the grids, the list items, and the
actions have the same nodes:

| Node | View mode | A form (edit mode) |
|---|---|---|
| `section :name` | A block with its `label` (default: the humanized name), `description`, and its own grid. With `path`, one block for each related record. | The inputs; with `path`, a nested form. |
| `row` | The children on one line when there is room. | The same. |
| `compound :name` | The parts, joined by `separator`, with one label. | A fieldset with one legend. |
| `field` `select` `combobox` `input` | The value. | The input. |
| `related :rel` | The related records ([Related records](#related-records)). | Read-only. |
| `attachments :name` | The files. | The upload. |
| `workflow` | The state of the record, its transitions, and its history ([Workflow](#workflow)). | Read-only. |
| `tabs` › `tab :name` | One tab at a time. | The same. |
| `step :name` | A section. | One step at a time. |

**Edit** switches the same tree to edit mode in the same place: nothing
moves.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 520" role="img" aria-labelledby="dg-tree-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-tree-t">A batch in view mode and in edit mode, with the same layout</title>
<rect class="dg-p" x="10" y="10" width="470" height="500" rx="8"/>
<rect class="dg-tb" x="20" y="2" width="300" height="16" rx="3"/><text class="dg-t" x="25" y="14">view :read · type :card · action [:create, :update]</text>
<text class="dg-h" x="26" y="42">B-2026-043</text>
<rect class="dg-b" x="418" y="24" width="48" height="26" rx="4"/><text class="dg-bt" x="430" y="41">Edit</text>
<rect class="dg-s" x="22" y="60" width="446" height="168" rx="6"/>
<rect class="dg-tb" x="30" y="52" width="104" height="16" rx="3"/><text class="dg-t" x="35" y="64">section :batch</text>
<text class="dg-st" x="36" y="86">Batch</text>
<text class="dg-l" x="36" y="106">Batch number</text><text class="dg-v" x="36" y="123">B-2026-043</text>
<text class="dg-l" x="252" y="106">Recipe</text><text class="dg-a" x="252" y="123">Midnight Stout</text>
<rect class="dg-tb" x="300" y="95" width="160" height="16" rx="3"/><text class="dg-t" x="305" y="107">combobox · link_to</text>
<text class="dg-l" x="36" y="146">Brewer</text><text class="dg-v" x="36" y="163">Ben Okafor</text>
<text class="dg-l" x="252" y="146">Status</text><text class="dg-v" x="252" y="163">Conditioning</text>
<rect class="dg-tb" x="340" y="135" width="94" height="16" rx="3"/><text class="dg-t" x="345" y="147">select :status</text>
<text class="dg-l" x="36" y="186">Pass rate</text><rect class="dg-warn" x="36" y="191" width="44" height="18" rx="9"/><text class="dg-warnt" x="44" y="204">75 %</text>
<rect class="dg-tb" x="100" y="175" width="150" height="16" rx="3"/><text class="dg-t" x="105" y="187">read-only · decoration</text>
<rect class="dg-s" x="22" y="244" width="446" height="160" rx="6"/>
<rect class="dg-tb" x="30" y="236" width="252" height="16" rx="3"/><text class="dg-t" x="35" y="248">section :production · collapsible? true</text>
<text class="dg-st" x="36" y="270">▾ Production</text>
<rect class="dg-tb" x="140" y="276" width="32" height="16" rx="3"/><text class="dg-t" x="145" y="288">row</text>
<text class="dg-l" x="36" y="290">Brew date</text><text class="dg-v" x="36" y="307">2026-11-05</text>
<text class="dg-l" x="252" y="290">Package date</text><text class="dg-f" x="252" y="307">Not packaged</text>
<rect class="dg-tb" x="340" y="279" width="120" height="16" rx="3"/><text class="dg-t" x="345" y="291">empty_text</text>
<rect class="dg-c" x="30" y="318" width="206" height="40" rx="4"/>
<rect class="dg-tb" x="120" y="312" width="112" height="16" rx="3"/><text class="dg-t" x="125" y="324">compound :gravity</text>
<text class="dg-l" x="36" y="334">Gravity</text><text class="dg-v" x="36" y="351">1.072 / 1.018</text>
<text class="dg-l" x="252" y="334">ABV</text><text class="dg-v" x="252" y="351">7.1 %</text>
<text class="dg-l" x="36" y="378">Volume (L)</text><text class="dg-v" x="36" y="395">1180</text>
<rect class="dg-s" x="22" y="420" width="446" height="34" rx="6"/>
<rect class="dg-tb" x="30" y="412" width="300" height="16" rx="3"/><text class="dg-t" x="35" y="424">section :quality · collapsed? true</text>
<text class="dg-st" x="36" y="444">▸ Quality</text>
<rect class="dg-b" x="22" y="468" width="126" height="26" rx="4"/><text class="dg-bt" x="32" y="485">Show all fields</text>
<rect class="dg-p" x="520" y="10" width="470" height="500" rx="8"/>
<rect class="dg-tb" x="530" y="2" width="200" height="16" rx="3"/><text class="dg-t" x="535" y="14">Edit: the same tree, for :update</text>
<text class="dg-h" x="536" y="42">B-2026-043</text>
<rect class="dg-b" x="842" y="24" width="64" height="26" rx="4"/><text class="dg-bt" x="853" y="41">Cancel</text>
<rect class="dg-pri" x="912" y="24" width="54" height="26" rx="4"/><text class="dg-bw" x="925" y="41">Save</text>
<rect class="dg-s" x="532" y="60" width="446" height="168" rx="6"/>
<text class="dg-st" x="546" y="86">Batch</text>
<text class="dg-l" x="546" y="104">Batch number *</text><rect class="dg-i" x="546" y="109" width="200" height="22" rx="3"/><text class="dg-v" x="552" y="125">B-2026-043</text><rect class="dg-foc" x="545" y="108" width="202" height="24" rx="4"/>
<text class="dg-l" x="762" y="104">Recipe *</text><rect class="dg-i" x="762" y="109" width="200" height="22" rx="3"/><text class="dg-v" x="768" y="125">Midnight Stout</text><text class="dg-v" x="948" y="125">⌕</text>
<text class="dg-l" x="546" y="144">Brewer</text><rect class="dg-i" x="546" y="149" width="200" height="22" rx="3"/><text class="dg-v" x="552" y="165">Ben Okafor</text><text class="dg-v" x="732" y="165">⌕</text>
<text class="dg-l" x="762" y="144">Status *</text><rect class="dg-i" x="762" y="149" width="200" height="22" rx="3"/><text class="dg-v" x="768" y="165">Conditioning</text><text class="dg-v" x="948" y="165">▾</text>
<text class="dg-l" x="546" y="186">Pass rate</text><rect class="dg-warn" x="546" y="191" width="44" height="18" rx="9"/><text class="dg-warnt" x="554" y="204">75 %</text>
<text class="dg-l" x="610" y="204">no input: a calculation</text>
<rect class="dg-tb" x="640" y="88" width="76" height="16" rx="3"/><text class="dg-t" x="645" y="100">autofocus</text>
<rect class="dg-s" x="532" y="244" width="446" height="160" rx="6"/>
<text class="dg-st" x="546" y="270">▾ Production</text>
<text class="dg-l" x="546" y="290">Brew date</text><rect class="dg-i" x="546" y="294" width="200" height="22" rx="3"/><text class="dg-v" x="552" y="310">2026-11-05</text>
<text class="dg-l" x="762" y="290">Package date</text><rect class="dg-i" x="762" y="294" width="200" height="22" rx="3"/>
<rect class="dg-c" x="540" y="322" width="212" height="44" rx="4"/>
<text class="dg-l" x="546" y="336">Gravity</text>
<rect class="dg-i" x="546" y="340" width="98" height="22" rx="3"/><text class="dg-v" x="552" y="356">1.072</text>
<rect class="dg-i" x="648" y="340" width="98" height="22" rx="3"/><text class="dg-v" x="654" y="356">1.018</text>
<text class="dg-l" x="762" y="336">ABV</text><rect class="dg-i" x="762" y="340" width="90" height="22" rx="3"/><text class="dg-v" x="768" y="356">7.1</text>
<text class="dg-l" x="546" y="380">Volume (L)</text><rect class="dg-i" x="546" y="384" width="90" height="18" rx="3"/><text class="dg-v" x="552" y="398">1180</text>
<text class="dg-l" x="650" y="380">Notes</text><rect class="dg-i" x="650" y="384" width="312" height="18" rx="3"/><text class="dg-v" x="656" y="398">Cold crash on Friday.</text>
<rect class="dg-tb" x="830" y="368" width="140" height="16" rx="3"/><text class="dg-t" x="835" y="380">only [:create, :update]</text>
<rect class="dg-s" x="532" y="420" width="446" height="34" rx="6"/>
<text class="dg-st" x="546" y="444">▸ Quality</text>
</svg>
<figcaption>The card of a batch (left) and the same tree after <b>Edit</b> (right). The positions do not change. The recipe combobox shows a link in view mode. The pass rate is a calculation: read-only and decorated in both modes. The notes are an input of the forms only (<code>only [:create, :update]</code>); the test count shows in view mode only (<code>only [:read]</code>).</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive
view :read do
  type :card
  primary? true
  action [:create, :update], :guard

  section :batch do
    field :batch_number, autofocus: true

    combobox :recipe_id do
      link_to BreweryWeb.RecipeLive
    end

    combobox :brewer_id
    select :status

    field :pass_rate do
      decoration expr(if pass_rate < 80, do: :warning)
    end
  end

  section :production do
    collapsible? true

    row do
      field :brew_date
      field :package_date, empty_text: "Not packaged"
    end

    compound :gravity do
      separator " / "
      field :actual_og
      field :actual_fg
    end

    field :actual_abv, label: "ABV"
    field :volume_liters, label: "Volume (L)"
    field :notes, type: :textarea, only: [:create, :update]
  end

  section :quality do
    collapsible? true
    collapsed? true
    field :test_count, label: "Tests", only: [:read]
    field :passed_test_count, label: "Passed"
  end
end
```

<!-- tabs-close -->

The whole page of the batches (`BreweryWeb.BatchLive`), with its list view
and its row actions:

```elixir
page do
  route "/batches"
  exclude [:list, :kanban_read, :move_card, :advance_status]
end

view :read do
  type :data_table
  primary? true
  exclude [:id, :recipe_id, :brewer_id, :recipe, :brewer, :kanban_priority,
           :package_date, :actual_og, :actual_fg, :actual_abv, :volume_liters,
           :notes, :test_count, :passed_test_count, :pass_rate]
  column :batch_number
  column :status
  column :brew_date

  action :create, :guard do
    delegate_to BreweryWeb.BatchLive     # the form of the card
  end

  action :start_brewing, :discard do     # no inputs: `confirm` is required
    confirm false                        # runs at once
  end

  action :destroy, :discard do
    confirm "Delete the batch?"
  end

  action :complete do                    # a row action with its own form
    state :guard
    presentation :drawer

    compound :gravity do
      field :actual_og, label: "OG", autofocus: true
      field :actual_fg, label: "FG"
    end

    field :actual_abv
    field :volume_liters
    field :package_date
  end
end

view :read do
  type :card
  primary? true
  presentation :modal
  action [:create, :update], :recover

  section :batch do
    field :batch_number, autofocus: true
    select :status

    combobox :recipe_id do
      link_to BreweryWeb.RecipeLive
    end

    combobox :brewer_id
    field :pass_rate                     # a calculation: read-only
  end

  section :measurements do
    compound :gravity do
      field :actual_og, label: "OG"
      field :actual_fg, label: "FG"
    end

    field :actual_abv
    field :volume_liters
    field :brew_date
    field :package_date
  end

  tabs do
    tab :quality_tests do
      count :test_count

      related :quality_tests do
        delegate_to BreweryWeb.QualityTestLive
      end
    end

    tab :notes do
      field :notes, type: :textarea
    end
  end
end
```

## The rules

- A `field` that is not an input of the action (a calculation, an
  aggregate, an attribute that the action does not accept, a `belongs_to`)
  is **read-only**: it shows its value in the form too. A name that is not
  a field of the resource is an error.
- A view that names no write action has no inputs: each value is a
  `field`.
- `only [names]` puts a node in some actions: the read action of the view
  (view mode) and the actions that use the tree. `only [:read]` is view
  mode only; `only [:create]` is the create form only. Another name is an
  error.
- The form of each action has each accepted attribute and each public
  argument of the action (or a `set`), and exactly one input with
  `autofocus`. An inline edit of a column is exempt.
- Each action declares its `state`: `:guard` (warn before leaving with
  unsaved changes), `:recover` (restore the inputs after a reload or a
  lost connection), or `:discard`. `confirm` asks before the action runs:
  a text, or an expression on the record that gives a message or `nil`.
  `confirm false` runs it at once. An action without inputs (and a bulk
  action without inputs) must set `confirm`: no confirmation is automatic.
- In a card, a `select`, `combobox`, or `input` on an attribute that the
  action does not accept is read-only, as a `field` (a transition uses the
  tree of the card).
- A record has one `tabs`, the last node of the top level. The nodes before
  it show on every tab. `count` of a tab is an aggregate or a calculation.
  The create form shows all the tabs. The input with `autofocus` is not on
  a later tab.
- `related` and `attachments` are of the record: not in a section with a
  `path`, and not in a bulk action.
- `decoration`, `empty_text`, and `link_to` of a field are for view mode.
- `visible?` hides a node by an expression of the record (in edit mode, of
  the form). Refer to [Nested records and conditions](#nested-records-and-conditions).
- `collapsible?` lets the user close a section; `collapsed?` starts it
  closed.
- **Show all fields** at the end of the card adds the exposed fields that
  the tree does not show.

## The card

A page has a primary single view: a `:card` with `primary? true`. It can
have a primary list view: one list view with `primary? true`. Without one,
the card is also the list view (one card for each record). A link to the
page opens a primary view ([Views](views.md)).

A page has one or more `:card` views, on its resource; one is primary.
Each card has its own record tree; a card without nodes does not compile.

- `action [:create, :update]` without nodes: the tree of the card is their
  form. A card without a write action is in view mode only.
- An `action` with nodes has its own tree: a button of the card opens it.
  `delegate_to Page` uses the tree of the same action in a view of that
  page.
- `presentation`: `:modal` over the page, `:drawer` at its side, or `:page`.
- The URL: `card=<id>` (the primary card), `card=<view>:<id>` (another
  card of the page), `edit`, and `tab=<name>`.

## Cards of a grid

A `:grid` view has its own record tree, or shows the primary card of the
page (`card? true`): the nodes before `tabs`, without `related` and
`attachments`. The nodes of a card, a grid, and a form are the same
entities with the same options.

## Fields

A `field` is the value in view mode and the input in edit mode.

| Option | The UI |
|---|---|
| `label` | The label (default: the humanized name). |
| `description` | An entity: the help text below the input (`description "text"`, `description expr(...)`, `description Renderer, implementation`; [Custom renders](custom-renders.md)). `description :inherit` takes the description of the attribute or argument as text. None by default. |
| `type` | The input: `:default` (from the Ash type), `:textarea`, `:checkbox`, `:toggle`, `:password`, `:email`, `:attachment`, ... |
| `size` | The content role, which gives the width of the track: `:code` (a short code), `:term` (a word), `:name`, `:phrase`, `:prose` (the full width). `:auto` comes from the type. |
| `autofocus` | The input that has the focus when the form opens: exactly one in the tree of each action with inputs, not on a tab after the first. |
| `path` | The input is in the nested form of a relationship, with no section. |
| `decoration` | The meaning of the value in view mode: one of the configured decorations (default `:neutral`, `:info`, `:success`, `:warning`, `:danger`), or an expression that gives one or `nil` ([Decorations](decorations.md)). |
| `empty_text` | The text for `nil` in view mode (default `"—"`). |
| `link_to` | A read-only relationship field links to its page ([Links](#links)). |

The same `field` is a value in a view that names no write action (a list
item, a grid card, a view-only card). There, `path` reads a related record
(`field :name, path: [:recipe]`). A `field` of `related` has `source` (the
path of the value) in place of `path`. Each input (`field`, `select`,
`combobox`, `input`) has `decoration` and `empty_text` (view mode), `only` and
`visible?` ([The rules](#the-rules)), and `render`.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 268" role="img" aria-labelledby="dg-fld-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-fld-t">The fields of a supplier in view mode and in edit mode: the sizes of the tracks, an email input, a toggle, a long text with help, and an empty value</title>
<rect class="dg-p" x="10" y="10" width="470" height="248" rx="8"/>
<text class="dg-h" x="26" y="42">Crisp Malting</text>
<text class="dg-l" x="26" y="70">Name</text><text class="dg-v" x="26" y="87">Crisp Malting</text>
<text class="dg-l" x="250" y="70">Code</text><text class="dg-v" x="250" y="87">CRISP</text>
<text class="dg-l" x="340" y="70">Active</text><text class="dg-v" x="340" y="87">Yes</text>
<text class="dg-l" x="26" y="114">Contact email</text><text class="dg-a" x="26" y="131">orders@crisp.example</text>
<text class="dg-l" x="250" y="114">Phone</text><text class="dg-f" x="250" y="131">No phone</text>
<rect class="dg-tb" x="330" y="120" width="140" height="16" rx="3"/><text class="dg-t" x="335" y="132">empty_text "No phone"</text>
<text class="dg-l" x="26" y="158">Notes</text>
<text class="dg-v" x="26" y="175">Floor-malted Maris Otter. Orders before noon ship</text>
<text class="dg-v" x="26" y="192">the same day; net 30.</text>
<rect class="dg-tb" x="26" y="214" width="250" height="16" rx="3"/><text class="dg-t" x="31" y="226">size :name · :code · :term · :prose</text>
<rect class="dg-p" x="520" y="10" width="470" height="248" rx="8"/>
<text class="dg-l" x="536" y="36">Name *</text><rect class="dg-i" x="536" y="40" width="220" height="24" rx="3"/><text class="dg-v" x="542" y="57">Crisp Malting</text><rect class="dg-foc" x="535" y="39" width="222" height="26" rx="4"/>
<rect class="dg-tb" x="600" y="20" width="76" height="16" rx="3"/><text class="dg-t" x="605" y="32">autofocus</text>
<text class="dg-l" x="770" y="36">Code *</text><rect class="dg-i" x="770" y="40" width="80" height="24" rx="3"/><text class="dg-v" x="776" y="57">CRISP</text>
<text class="dg-l" x="866" y="36">Active</text>
<rect x="866" y="44" width="34" height="18" rx="9" fill="#16a34a"/><circle cx="891" cy="53" r="7" fill="#fff"/>
<rect class="dg-tb" x="904" y="45" width="82" height="16" rx="3"/><text class="dg-t" x="909" y="57">type :toggle</text>
<text class="dg-l" x="536" y="84">Contact email</text><rect class="dg-i" x="536" y="88" width="220" height="24" rx="3"/><text class="dg-v" x="542" y="105">orders@crisp.example</text>
<rect class="dg-tb" x="636" y="70" width="82" height="16" rx="3"/><text class="dg-t" x="641" y="82">type :email</text>
<text class="dg-l" x="770" y="84">Phone</text><rect class="dg-i" x="770" y="88" width="140" height="24" rx="3"/>
<text class="dg-l" x="536" y="132">Notes</text>
<rect class="dg-i" x="536" y="136" width="438" height="52" rx="3"/><text class="dg-v" x="542" y="153">Floor-malted Maris Otter. Orders before noon ship</text><text class="dg-v" x="542" y="170">the same day; net 30.</text>
<rect class="dg-tb" x="780" y="118" width="190" height="16" rx="3"/><text class="dg-t" x="785" y="130">type :textarea · size :prose</text>
<text class="dg-l" x="536" y="204">Internal notes about the supplier.</text>
<rect class="dg-tb" x="740" y="194" width="230" height="16" rx="3"/><text class="dg-t" x="745" y="206">description (from the attribute)</text>
<rect class="dg-b" x="844" y="222" width="64" height="26" rx="4"/><text class="dg-bt" x="855" y="239">Cancel</text>
<rect class="dg-pri" x="914" y="222" width="54" height="26" rx="4"/><text class="dg-bw" x="927" y="239">Save</text>
</svg>
<figcaption>A supplier in view mode (left) and in edit mode (right). The size of a field gives the width of its track: a code is narrow, prose takes the full width. The help text is the description of the attribute.</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.SupplierLive do
  use PyroManiac, resource: Brewery.Supplier

  page do
    route "/suppliers"
    exclude [:suggest_codes, :by_prefix, :create, :rename, :destroy]
  end

  view :read do
    type :card
    primary? true
    action :update, :guard

    field :name, autofocus: true, size: :name
    field :code, size: :code
    field :active, type: :toggle
    field :contact_email, type: :email
    field :phone, size: :term, empty_text: "No phone"
    field :notes do
      type :textarea
      size :prose
      description :inherit
    end
  end
end
```

<!-- tabs-close -->

## Selects

A `select` is an input for a closed set of values. Without `options`, the
options come from the type: an `Ash.Type.Enum` (with its labels), a
`one_of` constraint, or a `one_of` in the items of an array.
`options` gives them: values, or
`{label, value}` tuples. `prompt` is the text of the empty option. In view
mode, a select shows the label of its value.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 220" role="img" aria-labelledby="dg-sel-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-sel-t">The create form of an ingredient: an open select of the ingredient types, and a select of the units with a prompt</title>
<rect class="dg-p" x="10" y="10" width="980" height="200" rx="8"/>
<text class="dg-l" x="26" y="40">Name *</text><rect class="dg-i" x="26" y="44" width="220" height="24" rx="3"/><text class="dg-v" x="32" y="61">Citra</text>
<text class="dg-l" x="266" y="40">Type *</text><rect class="dg-i" x="266" y="44" width="180" height="24" rx="3"/><text class="dg-v" x="272" y="61">Hop</text><text class="dg-v" x="430" y="61">▴</text><rect class="dg-foc" x="265" y="43" width="182" height="26" rx="4"/>
<rect class="dg-m" x="266" y="72" width="180" height="122" rx="4"/>
<text class="dg-v" x="276" y="92">Grain</text>
<rect class="dg-hl" x="267" y="98" width="178" height="22"/><text class="dg-v" x="276" y="114">Hop ✓</text>
<text class="dg-v" x="276" y="136">Yeast</text><text class="dg-v" x="276" y="158">Adjunct</text><text class="dg-v" x="276" y="180">Water treatment</text>
<rect class="dg-tb" x="456" y="48" width="200" height="16" rx="3"/><text class="dg-t" x="461" y="60">select :type (one_of)</text>
<text class="dg-l" x="680" y="40">Unit *</text><rect class="dg-i" x="680" y="44" width="160" height="24" rx="3"/><text class="dg-f" x="686" y="61">Select a unit</text><text class="dg-v" x="824" y="61">▾</text>
<rect class="dg-tb" x="680" y="76" width="210" height="16" rx="3"/><text class="dg-t" x="685" y="88">select :unit · prompt · options</text>
<text class="dg-l" x="680" y="116">Options: Kilograms, Grams, Litres,</text><text class="dg-l" x="680" y="132">Millilitres, Each</text>
<text class="dg-l" x="680" y="176">Below: the lot number, the supplier,</text><text class="dg-l" x="680" y="192">and the description.</text>
</svg>
<figcaption>Two selects. The types come from the <code>one_of</code> constraint of the attribute. The units have explicit options and a prompt.</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.IngredientLive do
  use PyroManiac, resource: Brewery.Ingredient

  page do
    route "/ingredients"
    exclude [:destroy]
  end

  view :read do
    type :card
    primary? true
    action [:create, :update], :guard

    field :name, autofocus: true
    select :type

    select :unit do
      prompt "Select a unit"

      options [
        {"Kilograms", :kg},
        {"Grams", :g},
        {"Litres", :l},
        {"Millilitres", :ml},
        {"Each", :each}
      ]
    end

    field :lot_number
    combobox :supplier_id
    field :description, type: :textarea
  end
end
```

<!-- tabs-close -->

## Comboboxes

A `combobox` is an input that searches for its value. The mode comes from
the field:

- **Select**: the foreign key of a `belongs_to`. The user selects a record
  of the destination. View mode shows the record (its `default_label`), as
  a link with `link_to`.
- **Select many**: an argument that the action passes to
  `manage_relationship` of a relationship to many records (for example a
  `many_to_many`). The user attaches and detaches records of the
  destination ([Select many](#select-many)).
- **Free text**: a `:string` or `:ci_string`. The typed text is the value;
  the options are the values that the records already have.


| Option | The search |
|---|---|
| `read_action` | The read action of the searched resource (default: the primary read). Its filter, preparations, and policies apply. |
| `search` | The fields that the typed text matches (`contains`, joined with `or`). Default `[label_key]`. `false` when `filter` or an `argument` uses the text. |
| `filter` | More filter (an expression). It can use `^search()`, `^input(:name)` (another input of the same form level), and `^actor(...)`. |
| `argument :name, value` | An argument of `read_action`: a literal, or `search()`, `input(:name)`, `actor(:field)`, `arg(:name)` (no `^`). |
| `sort`, `limit` | The order and the count (1 to 100, default 20) of the options. |
| `label_key`, `value_key` | The text and the value of an option. Select mode: the `default_label` and the primary key. |

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 236" role="img" aria-labelledby="dg-cb-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-cb-t">Three comboboxes: a supplier in select mode, a brewer from an autocomplete action, and a supplier code in free-text mode</title>
<rect class="dg-p" x="10" y="10" width="316" height="216" rx="8"/>
<rect class="dg-tb" x="20" y="2" width="200" height="16" rx="3"/><text class="dg-t" x="25" y="14">combobox :supplier_id · select</text>
<text class="dg-l" x="26" y="40">Supplier *</text><rect class="dg-i" x="26" y="44" width="284" height="24" rx="3"/><text class="dg-v" x="32" y="61">cr</text><rect class="dg-foc" x="25" y="43" width="286" height="26" rx="4"/>
<rect class="dg-m" x="26" y="72" width="284" height="72" rx="4"/>
<rect class="dg-hl" x="27" y="76" width="282" height="22"/><text class="dg-v" x="36" y="92">Crisp Malting</text><text class="dg-l" x="230" y="92">CRISP</text>
<text class="dg-v" x="36" y="116">Cross Hop Farms</text><text class="dg-l" x="230" y="116">CRSH</text>
<text class="dg-l" x="36" y="136">only active · sorted by code</text>
<rect class="dg-tb" x="26" y="154" width="190" height="16" rx="3"/><text class="dg-t" x="31" y="166">filter · sort · limit 10</text>
<text class="dg-l" x="26" y="196">The value is the id; the text is the name.</text>
<rect class="dg-p" x="342" y="10" width="316" height="216" rx="8"/>
<rect class="dg-tb" x="352" y="2" width="244" height="16" rx="3"/><text class="dg-t" x="357" y="14">read_action :autocomplete · argument</text>
<text class="dg-l" x="358" y="40">Brewer</text><rect class="dg-i" x="358" y="44" width="284" height="24" rx="3"/><text class="dg-v" x="364" y="61">ana</text><rect class="dg-foc" x="357" y="43" width="286" height="26" rx="4"/>
<rect class="dg-m" x="358" y="72" width="284" height="50" rx="4"/>
<rect class="dg-hl" x="359" y="76" width="282" height="22"/><text class="dg-v" x="368" y="92">Ana Ruiz (ana@brewery.example)</text>
<text class="dg-v" x="368" y="116">Dana Kim (dana@brewery.example)</text>
<rect class="dg-tb" x="358" y="132" width="230" height="16" rx="3"/><text class="dg-t" x="363" y="144">label_key :name_email · search false</text>
<text class="dg-l" x="358" y="174">The typed text is the search argument</text>
<text class="dg-l" x="358" y="190">of the read action.</text>
<rect class="dg-p" x="674" y="10" width="316" height="216" rx="8"/>
<rect class="dg-tb" x="684" y="2" width="176" height="16" rx="3"/><text class="dg-t" x="689" y="14">combobox :code · free text</text>
<text class="dg-l" x="690" y="40">Code *</text><rect class="dg-i" x="690" y="44" width="284" height="24" rx="3"/><text class="dg-v" x="696" y="61">CRI</text><rect class="dg-foc" x="689" y="43" width="286" height="26" rx="4"/>
<rect class="dg-m" x="690" y="72" width="284" height="74" rx="4"/>
<text class="dg-v" x="700" y="92">CRISP</text><text class="dg-v" x="700" y="116">CRISP-UK</text>
<text class="dg-l" x="700" y="138">codes in use; "CRI" is a new value</text>
<rect class="dg-tb" x="690" y="156" width="226" height="16" rx="3"/><text class="dg-t" x="695" y="168">read_action :suggest_codes</text>
<text class="dg-l" x="690" y="196">The typed text is the value.</text>
</svg>
<figcaption>Select mode with a filter and a sort; a read action with an argument for the typed text; free text, whose options are the values in use.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.IngredientLive
combobox :supplier_id do
  filter expr(active == true)
  sort code: :asc
  limit 10
  label_key :name
  value_key :id
end

# BreweryWeb.BatchLive
combobox :brewer_id do
  read_action :autocomplete
  argument :search, search()
  search false
  label_key :name_email
end

# BreweryWeb.SupplierLive
combobox :code do
  read_action :suggest_codes
  argument :search, search()
  search false
end
```

<!-- tabs-close -->

### Select many

A combobox for an argument that the action passes to `manage_relationship`
of a relationship to many records selects many records. The selected
records show as chips in the input, each with a remove button, and the
search after them. The options stay open after a selection. **Save**
attaches the new records and detaches the removed ones; an empty selection
detaches all. View mode shows the records as a list of labels (links with
`link_to`).

```elixir
# a resource with a `many_to_many :tags` (not in the Brewery domain)
update :update do
  argument :tag_ids, {:array, :uuid}
  change manage_relationship(:tag_ids, :tags, type: :append_and_remove)
end

# the page
combobox :tag_ids do
  sort name: :asc
end
```

## Inputs with an input type

`input :name, type` uses an app input type: a module that implements
`PyroManiac.Form.InputType`, or `{module, options}`. PyroManiac validates
the options with `schema/0` at compile time; `default_size/0` gives the
size for `size: :auto`. The behaviour has no rendering: each renderer has
its own render behaviour for the module. `input` has the common options
(`label`, `autofocus`, `path`, `size`, `only`, `visible?`, `decoration`,
`empty_text`), and the `description` and `render` entities. An input is an error in a view that
names no write action.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 196" role="img" aria-labelledby="dg-inp-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-inp-t">The description of a recipe in a markdown input with a toolbar, and the same value in view mode</title>
<rect class="dg-p" x="10" y="10" width="470" height="176" rx="8"/>
<text class="dg-l" x="26" y="38">Description</text>
<text class="dg-st" x="26" y="62">Tasting notes</text>
<text class="dg-v" x="26" y="84">Juicy and soft. <tspan font-weight="600">Citra</tspan> and <tspan font-style="italic">Mosaic</tspan> in the</text>
<text class="dg-v" x="26" y="102">whirlpool; dry hop on day 3.</text>
<text class="dg-v" x="26" y="128">• Serve at 6 °C</text><text class="dg-v" x="26" y="146">• Best within 6 weeks</text>
<text class="dg-l" x="26" y="174">view mode: the formatted value</text>
<rect class="dg-p" x="520" y="10" width="470" height="176" rx="8"/>
<rect class="dg-tb" x="530" y="2" width="330" height="16" rx="3"/><text class="dg-t" x="535" y="14">input :description, {BreweryWeb.Inputs.Markdown, ...}</text>
<text class="dg-l" x="536" y="38">Description</text>
<rect class="dg-i" x="536" y="44" width="438" height="128" rx="3"/>
<line class="dg-g" x1="536" y1="68" x2="974" y2="68"/>
<text class="dg-st" x="546" y="61">B</text><text class="dg-v" x="566" y="61" font-style="italic">I</text><text class="dg-v" x="584" y="61">H</text><text class="dg-v" x="604" y="61">•</text><text class="dg-a" x="620" y="61">link</text>
<text class="dg-u" x="546" y="88">## Tasting notes</text>
<text class="dg-u" x="546" y="106">Juicy and soft. **Citra** and _Mosaic_ in the</text>
<text class="dg-u" x="546" y="124">whirlpool; dry hop on day 3.</text>
<text class="dg-u" x="546" y="142">- Serve at 6 °C</text><text class="dg-u" x="546" y="160">- Best within 6 weeks</text>
</svg>
<figcaption>An app input type. The renderer renders the module; PyroManiac checks its options.</figcaption>
</figure>

### DSL

```elixir
# a node of a tree (BreweryWeb.RecipeLive)
input :description, {BreweryWeb.Inputs.Markdown, toolbar: :basic}

# the input type
defmodule BreweryWeb.Inputs.Markdown do
  @behaviour PyroManiac.Form.InputType

  @impl true
  def schema, do: [toolbar: [type: {:in, [:basic, :full]}, default: :basic]]

  @impl true
  def default_size, do: :prose
end
```

<!-- tabs-close -->

## Rows and compounds

A `row` is layout only: its children stay on one line when there is room,
and wrap as a unit. A `compound` is one value made of two or more fields,
with one label (`label`, default: the humanized name) and help text
(the `description` entity). In view mode the parts are joined by `separator` (default
`" "`). In edit mode it is a fieldset: `show_labels? true` shows the labels
of the parts; otherwise they are only for assistive technology. Both have
`only` and `visible?`; a compound has `render`.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 190" role="img" aria-labelledby="dg-row-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-row-t">A row of the targets of a recipe, and a gravity compound, in view mode and in edit mode</title>
<text class="dg-st" x="20" y="18">View</text><text class="dg-st" x="520" y="18">Edit</text>
<line x1="500" y1="6" x2="500" y2="184" class="dg-g"/>
<rect class="dg-tb" x="20" y="30" width="32" height="16" rx="3"/><text class="dg-t" x="25" y="42">row</text>
<text class="dg-l" x="20" y="64">Target ABV</text><text class="dg-v" x="20" y="81">6.8 %</text>
<text class="dg-l" x="140" y="64">Target OG</text><text class="dg-v" x="140" y="81">1.064</text>
<text class="dg-l" x="260" y="64">Target FG</text><text class="dg-v" x="260" y="81">1.012</text>
<text class="dg-l" x="520" y="64">Target ABV</text><rect class="dg-i" x="520" y="68" width="110" height="22" rx="3"/><text class="dg-v" x="526" y="84">6.8</text>
<text class="dg-l" x="640" y="64">Target OG</text><rect class="dg-i" x="640" y="68" width="110" height="22" rx="3"/><text class="dg-v" x="646" y="84">1.064</text>
<text class="dg-l" x="760" y="64">Target FG</text><rect class="dg-i" x="760" y="68" width="110" height="22" rx="3"/><text class="dg-v" x="766" y="84">1.012</text>
<rect class="dg-tb" x="20" y="104" width="250" height="16" rx="3"/><text class="dg-t" x="25" y="116">compound :gravity · separator " → "</text>
<rect class="dg-c" x="14" y="124" width="200" height="50" rx="4"/>
<text class="dg-l" x="20" y="140">Gravity</text><text class="dg-v" x="20" y="158">1.064 → 1.012</text>
<text class="dg-l" x="20" y="170">OG to FG</text>
<rect class="dg-tb" x="520" y="104" width="130" height="16" rx="3"/><text class="dg-t" x="525" y="116">show_labels? true</text>
<rect class="dg-c" x="514" y="124" width="250" height="60" rx="4"/>
<text class="dg-l" x="520" y="140">Gravity</text>
<text class="dg-l" x="520" y="154">OG</text><rect class="dg-i" x="540" y="142" width="90" height="20" rx="3"/><text class="dg-v" x="546" y="157">1.064</text>
<text class="dg-l" x="640" y="154">FG</text><rect class="dg-i" x="660" y="142" width="90" height="20" rx="3"/><text class="dg-v" x="666" y="157">1.012</text>
<text class="dg-l" x="520" y="178">OG to FG</text>
</svg>
<figcaption>A <code>row</code> keeps labelled values on one line. A <code>compound</code> is one value with one label: joined in view mode, a fieldset in edit mode.</figcaption>
</figure>

### DSL

```elixir
section :targets do
  row do
    field :target_abv
    field :target_og
    field :target_fg
  end

  compound :gravity do
    description "OG to FG"
    separator " → "
    show_labels? true
    field :target_og, label: "OG"
    field :target_fg, label: "FG"
  end
end
```

<!-- tabs-close -->

## Sections side by side

A `row` of sections puts the sections side by side on a wide screen. The
renderer wraps them on a narrow screen. `density :dense` uses narrower
tracks, and `max_columns` caps the columns of a section (`max_columns` of
an action caps its whole form).

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 476" role="img" aria-labelledby="dg-side-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-side-t">A row of three sections of a batch on a wide screen, a tablet, and a phone</title>
<rect class="dg-p" x="10" y="22" width="980" height="210" rx="8"/>
<rect class="dg-tb" x="20" y="14" width="32" height="16" rx="3"/><text class="dg-t" x="25" y="26">row</text>
<text class="dg-h" x="26" y="50">B-2026-043 · Midnight Stout</text><text class="dg-l" x="820" y="50">wide: side by side</text>
<rect class="dg-s" x="22" y="64" width="312" height="150" rx="6"/>
<rect class="dg-tb" x="30" y="56" width="104" height="16" rx="3"/><text class="dg-t" x="35" y="68">section :batch</text>
<text class="dg-st" x="36" y="88">Batch</text>
<text class="dg-l" x="36" y="108">Batch number</text><text class="dg-v" x="36" y="125">B-2026-043</text>
<text class="dg-l" x="36" y="148">Recipe</text><text class="dg-a" x="36" y="165">Midnight Stout</text>
<text class="dg-l" x="36" y="188">Brewer</text><text class="dg-v" x="36" y="205">Ben Okafor</text>
<rect class="dg-s" x="346" y="64" width="312" height="150" rx="6"/>
<rect class="dg-tb" x="354" y="56" width="140" height="16" rx="3"/><text class="dg-t" x="359" y="68">section :production</text>
<text class="dg-st" x="360" y="88">Production</text>
<text class="dg-l" x="360" y="108">Status</text><rect class="dg-info" x="360" y="113" width="90" height="18" rx="9"/><text class="dg-infot" x="371" y="126">Conditioning</text>
<text class="dg-l" x="360" y="148">Brew date</text><text class="dg-v" x="360" y="165">2026-11-05</text>
<text class="dg-l" x="360" y="188">Volume (L)</text><text class="dg-v" x="360" y="205">1180</text>
<rect class="dg-s" x="670" y="64" width="308" height="150" rx="6"/>
<rect class="dg-tb" x="678" y="56" width="120" height="16" rx="3"/><text class="dg-t" x="683" y="68">section :quality</text>
<text class="dg-st" x="684" y="88">Quality</text>
<text class="dg-l" x="684" y="108">Tests</text><text class="dg-v" x="684" y="125">5</text>
<text class="dg-l" x="684" y="148">Passed</text><text class="dg-v" x="684" y="165">4</text>
<text class="dg-l" x="684" y="188">Pass rate</text><rect class="dg-ok" x="684" y="193" width="44" height="18" rx="9"/><text class="dg-okt" x="692" y="206">80 %</text>
<rect class="dg-p" x="10" y="252" width="300" height="214" rx="8"/>
<text class="dg-h" x="26" y="280">B-2026-043</text><text class="dg-l" x="180" y="280">phone: one per line</text>
<rect class="dg-s" x="22" y="292" width="276" height="66" rx="6"/>
<text class="dg-st" x="36" y="312">Batch</text>
<text class="dg-l" x="36" y="332">Batch number</text><text class="dg-v" x="36" y="349">B-2026-043</text>
<rect class="dg-s" x="22" y="366" width="276" height="66" rx="6"/>
<text class="dg-st" x="36" y="386">Production</text>
<text class="dg-l" x="36" y="406">Status</text><rect class="dg-info" x="36" y="411" width="90" height="18" rx="9"/><text class="dg-infot" x="47" y="424">Conditioning</text>
<rect class="dg-s" x="22" y="440" width="276" height="22" rx="6"/>
<text class="dg-st" x="36" y="456">Quality</text>
<rect class="dg-p" x="330" y="252" width="660" height="214" rx="8"/>
<text class="dg-h" x="346" y="280">B-2026-043</text><text class="dg-l" x="740" y="280">tablet: the third section wraps</text>
<rect class="dg-s" x="342" y="292" width="312" height="112" rx="6"/>
<text class="dg-st" x="356" y="314">Batch</text>
<text class="dg-l" x="356" y="334">Batch number</text><text class="dg-v" x="356" y="351">B-2026-043</text>
<text class="dg-l" x="356" y="374">Recipe</text><text class="dg-a" x="356" y="391">Midnight Stout</text>
<rect class="dg-s" x="666" y="292" width="312" height="112" rx="6"/>
<text class="dg-st" x="680" y="314">Production</text>
<text class="dg-l" x="680" y="334">Status</text><rect class="dg-info" x="680" y="339" width="90" height="18" rx="9"/><text class="dg-infot" x="691" y="352">Conditioning</text>
<text class="dg-l" x="680" y="374">Brew date</text><text class="dg-v" x="680" y="391">2026-11-05</text>
<rect class="dg-s" x="342" y="416" width="636" height="40" rx="6"/>
<text class="dg-st" x="356" y="442">Quality</text>
</svg>
<figcaption>Three sections in a <code>row</code>: side by side on a wide screen, two and one on a tablet, one on each line on a phone.</figcaption>
</figure>

### DSL

```elixir
view :read do
  type :card
  primary? true

  row do
    section :batch do
      field :batch_number
      field :recipe
      field :brewer
    end

    section :production do
      field :status
      field :brew_date
      field :volume_liters, label: "Volume (L)"
    end

    section :quality do
      field :test_count, label: "Tests"
      field :passed_test_count, label: "Passed"
      field :pass_rate
    end
  end
end
```

<!-- tabs-close -->

This card names no write action: it is view mode only, with no **Edit**.

## Nested records and conditions

A `section` with `path` repeats for each record of a relationship: in view
mode a block for each, in edit mode a nested form with **Add** and
**Remove**. An input with `path` is in the nested form, with no section.
`visible?` shows a node only when its expression is true. In a nested form,
`parent(name)` reads the form above.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 320" role="img" aria-labelledby="dg-nest-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-nest-t">A new shipment with two lines by truck, and the same form for a pickup, where the lines are hidden</title>
<rect class="dg-p" x="10" y="10" width="560" height="300" rx="8"/>
<text class="dg-h" x="26" y="40">New shipment</text>
<text class="dg-l" x="26" y="64">Reference *</text><rect class="dg-i" x="26" y="68" width="200" height="22" rx="3"/><text class="dg-v" x="32" y="84">SH-0193</text>
<text class="dg-l" x="240" y="64">Carrier</text><rect class="dg-i" x="240" y="68" width="140" height="22" rx="3"/><text class="dg-v" x="246" y="84">Truck</text><text class="dg-v" x="366" y="84">▾</text>
<rect class="dg-s" x="22" y="104" width="536" height="184" rx="6"/>
<rect class="dg-tb" x="30" y="96" width="330" height="16" rx="3"/><text class="dg-t" x="35" y="108">section :lines · path [:lines] · visible?</text>
<text class="dg-st" x="36" y="130">Lines</text>
<rect class="dg-b" x="478" y="114" width="70" height="22" rx="4"/><text class="dg-bt" x="486" y="129">+ Add line</text>
<rect class="dg-c" x="32" y="140" width="516" height="62" rx="4"/>
<text class="dg-l" x="42" y="156">Description *</text><rect class="dg-i" x="42" y="160" width="220" height="22" rx="3"/><text class="dg-v" x="48" y="176">Hazy Daze IPA, 50 L kegs</text>
<text class="dg-l" x="274" y="156">Quantity</text><rect class="dg-i" x="274" y="160" width="70" height="22" rx="3"/><text class="dg-v" x="280" y="176">24</text>
<text class="dg-l" x="356" y="156">Pallet count</text><rect class="dg-i" x="356" y="160" width="70" height="22" rx="3"/><text class="dg-v" x="362" y="176">2</text>
<text class="dg-v" x="530" y="156">×</text>
<rect class="dg-c" x="32" y="210" width="516" height="62" rx="4"/>
<text class="dg-l" x="42" y="226">Description *</text><rect class="dg-i" x="42" y="230" width="220" height="22" rx="3"/><text class="dg-v" x="48" y="246">Midnight Stout, cases</text>
<text class="dg-l" x="274" y="226">Quantity</text><rect class="dg-i" x="274" y="230" width="70" height="22" rx="3"/>
<text class="dg-l" x="356" y="246">no quantity: no pallets</text>
<text class="dg-v" x="530" y="226">×</text>
<rect class="dg-tb" x="356" y="186" width="186" height="16" rx="3"/><text class="dg-t" x="361" y="198">visible? parent(carrier) …</text>
<rect class="dg-p" x="590" y="10" width="400" height="300" rx="8"/>
<text class="dg-h" x="606" y="40">New shipment</text>
<text class="dg-l" x="606" y="64">Reference *</text><rect class="dg-i" x="606" y="68" width="180" height="22" rx="3"/><text class="dg-v" x="612" y="84">SH-0194</text>
<text class="dg-l" x="800" y="64">Carrier</text><rect class="dg-i" x="800" y="68" width="140" height="22" rx="3"/><text class="dg-v" x="806" y="84">Pickup</text><text class="dg-v" x="926" y="84">▾</text><rect class="dg-foc" x="799" y="67" width="142" height="24" rx="4"/>
<text class="dg-l" x="606" y="126">The lines are hidden: the carrier is a pickup.</text>
<text class="dg-l" x="606" y="144">The renderer evaluates visible? again when an</text>
<text class="dg-l" x="606" y="160">input of __depends_on__ changes.</text>
<rect class="dg-pri" x="924" y="270" width="54" height="26" rx="4"/><text class="dg-bw" x="937" y="287">Save</text>
</svg>
<figcaption>A nested form. The lines section repeats for each line and shows only when the carrier is not a pickup. The pallet count of a line shows only for a truck and a quantity.</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.ShipmentLive do
  use PyroManiac, resource: Brewery.Shipment

  page do
    route "/shipments"
    exclude [:destroy]
  end

  view :read do
    type :card
    primary? true
    action :create, :recover

    field :reference, autofocus: true
    select :carrier

    section :lines do
      path [:lines]
      visible? expr(carrier != :pickup)
      field :description
      field :quantity
      field :pallet_count, visible?: expr(parent(carrier) == :truck and quantity > 0)
    end
  end
end
```

`visible?` refers to attributes (and `^arg(:name)`, `parent(name)`): it is
evaluated in memory, with no query. A calculation or an aggregate in it is
a compile error.

<!-- tabs-close -->

In the card of a recipe (`BreweryWeb.RecipeLive`), a section with a `path`
repeats for each ingredient line. The update action has no input for the
lines, so the section is in view mode only:

```elixir
section :ingredients do
  path [:recipe_ingredients]
  only [:read]
  field :quantity
  field :notes
end
```

## Tabs

A record has at most one `tabs` (two or more `tab`), the last node of the
top level. The nodes before it show on every tab. A `tab` has `label`,
`count` (a public aggregate or calculation, in the label), `only` (the tab
of some actions), and `render`; `tabs` has `orientation` (`:horizontal`,
the default: the tab list above the panel; `:vertical`: at its side) and
`render`. The open tab is in the URL (`tab=<name>`). In create mode all
the tabs show; a tab with an invalid input shows it.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 365" role="img" aria-labelledby="dg-tabs-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-tabs-t">A recipe with tabs, in view mode on the Ingredients tab and in edit mode on the Details tab</title>
<rect class="dg-p" x="10" y="10" width="470" height="345" rx="8"/>
<text class="dg-h" x="26" y="42">Hazy Daze IPA</text>
<rect class="dg-b" x="418" y="24" width="48" height="26" rx="4"/><text class="dg-bt" x="430" y="41">Edit</text>
<rect class="dg-s" x="22" y="56" width="446" height="64" rx="6"/>
<rect class="dg-tb" x="30" y="48" width="112" height="16" rx="3"/><text class="dg-t" x="35" y="60">section :recipe</text>
<text class="dg-l" x="36" y="80">Style</text><text class="dg-v" x="36" y="98">IPA</text>
<text class="dg-l" x="150" y="80">Gravity spread</text><text class="dg-v" x="150" y="98">0.052</text>
<text class="dg-l" x="290" y="80">Batches</text><text class="dg-v" x="290" y="98">12</text>
<rect class="dg-tb" x="340" y="86" width="82" height="16" rx="3"/><text class="dg-t" x="345" y="98">only [:read]</text>
<rect class="dg-tb" x="22" y="124" width="39" height="16" rx="3"/><text class="dg-t" x="27" y="136">tabs</text>
<rect class="dg-tb" x="204" y="124" width="236" height="16" rx="3"/><text class="dg-t" x="209" y="136">tab :ingredients · count :ingredient_count</text>
<text class="dg-tab" x="36" y="156">Details</text><text class="dg-tab" x="100" y="156">Batches (12)</text><text class="dg-st" x="204" y="156">Ingredients (4)</text><text class="dg-tab" x="320" y="156">Photos</text>
<line class="dg-g" x1="22" y1="164" x2="468" y2="164"/>
<line class="dg-on" x1="204" y1="164" x2="306" y2="164"/>
<rect class="dg-s" x="22" y="180" width="446" height="160" rx="6"/>
<rect class="dg-tb" x="30" y="172" width="296" height="16" rx="3"/><text class="dg-t" x="35" y="184">related :recipe_ingredients · type :data_table</text>
<text class="dg-l" x="36" y="204">Ingredient</text><text class="dg-l" x="220" y="204">Quantity</text><text class="dg-l" x="330" y="204">Notes</text>
<line class="dg-g" x1="36" y1="210" x2="456" y2="210"/>
<text class="dg-a" x="36" y="230">Maris Otter</text><text class="dg-v" x="220" y="230">5.5 kg</text><text class="dg-v" x="330" y="230">Mash</text>
<text class="dg-a" x="36" y="254">Citra</text><text class="dg-v" x="220" y="254">200 g</text><text class="dg-v" x="330" y="254">Whirlpool</text>
<text class="dg-a" x="36" y="278">Mosaic</text><text class="dg-v" x="220" y="278">150 g</text><text class="dg-v" x="330" y="278">Dry hop, day 3</text>
<text class="dg-a" x="36" y="302">US-05</text><text class="dg-v" x="220" y="302">2 each</text><text class="dg-v" x="330" y="302">Pitch at 18 °C</text>
<rect class="dg-p" x="520" y="10" width="470" height="345" rx="8"/>
<text class="dg-h" x="536" y="42">Hazy Daze IPA</text>
<rect class="dg-b" x="842" y="24" width="64" height="26" rx="4"/><text class="dg-bt" x="853" y="41">Cancel</text>
<rect class="dg-pri" x="912" y="24" width="54" height="26" rx="4"/><text class="dg-bw" x="925" y="41">Save</text>
<rect class="dg-s" x="532" y="56" width="446" height="64" rx="6"/>
<text class="dg-l" x="546" y="76">Name *</text><rect class="dg-i" x="546" y="81" width="150" height="22" rx="3"/><text class="dg-v" x="552" y="97">Hazy Daze IPA</text>
<text class="dg-l" x="706" y="76">Style *</text><rect class="dg-i" x="706" y="81" width="100" height="22" rx="3"/><text class="dg-v" x="712" y="97">IPA</text><text class="dg-v" x="792" y="97">▾</text>
<text class="dg-l" x="820" y="76">Gravity spread</text><text class="dg-v" x="820" y="98">0.052</text>
<text class="dg-st" x="546" y="156">Details</text>
<circle class="dg-err" cx="604" cy="151" r="7"/><text class="dg-bw" x="600.5" y="155">1</text>
<text class="dg-tab" x="624" y="156">Ingredients (4)</text><text class="dg-tab" x="740" y="156">Photos</text>
<line class="dg-g" x1="532" y1="164" x2="978" y2="164"/>
<line class="dg-on" x1="546" y1="164" x2="596" y2="164"/>
<text class="dg-l" x="800" y="136">no Batches tab in edit mode</text>
<rect class="dg-s" x="532" y="180" width="446" height="160" rx="6"/>
<rect class="dg-tb" x="540" y="172" width="120" height="16" rx="3"/><text class="dg-t" x="545" y="184">section :targets</text>
<text class="dg-st" x="546" y="204">Targets</text>
<text class="dg-l" x="546" y="224">Target ABV</text><rect class="dg-i" x="546" y="228" width="120" height="22" rx="3"/><text class="dg-v" x="552" y="244">6.8</text>
<text class="dg-l" x="680" y="224">Target OG</text><rect class="dg-i" x="680" y="228" width="120" height="22" rx="3"/><text class="dg-v" x="686" y="244">1.012</text>
<rect x="680" y="228" width="120" height="22" rx="3" fill="none" stroke="#dc2626"/>
<text class="dg-errt" x="680" y="264">must be above the FG</text>
<text class="dg-l" x="814" y="224">Target FG</text><rect class="dg-i" x="814" y="228" width="120" height="22" rx="3"/><text class="dg-v" x="820" y="244">1.064</text>
<text class="dg-l" x="546" y="286">Status *</text><rect class="dg-i" x="546" y="290" width="120" height="22" rx="3"/><text class="dg-v" x="552" y="306">Active</text><text class="dg-v" x="652" y="306">▾</text>
</svg>
<figcaption>A recipe with tabs. In view mode (left) the Ingredients tab is open, with its count. In edit mode (right) the Batches tab is not there (<code>only [:read]</code>), and the Details tab shows one error. The section above the tabs shows on every tab.</figcaption>
</figure>

### DSL

```elixir
view :read do
  type :card
  primary? true
  action :update, :guard

  section :recipe do
    field :name, autofocus: true
    select :style
    field :gravity_spread
    field :batch_count, label: "Batches", only: [:read]
  end

  tabs do
    tab :details do
      section :targets do
        row do
          field :target_abv
          field :target_og
          field :target_fg
        end

        select :status
        field :description, type: :textarea
      end
    end

    tab :batches do
      count :batch_count
      only [:read]

      related :batches do
        delegate_to BreweryWeb.BatchLive
        count :batch_count
      end
    end

    tab :ingredients do
      count :ingredient_count

      related :recipe_ingredients do
        type :data_table

        field :ingredient do
          link_to BreweryWeb.IngredientLive
        end

        field :quantity
        field :notes
      end
    end

    tab :photos do
      attachments :photos
    end
  end
end
```

<!-- tabs-close -->

## Related records

`related :rel` shows the records of a relationship:

- `type`: `:list`, `:data_table` (the `field` entities are the columns),
  `:grid`, `:count`, or `:badge`. With `delegate_to`, a page of the
  destination shows them, scoped to the record.
- `presentation`: `:inline` in the record, or `:modal` or `:drawer` over
  the page.

For the UI and the DSL, refer to [Related records](pages.md#related-records).

## Attachments

`attachments :name` shows the files of an `AshStorage` attachment
(`has_one_attached` or `has_many_attached`): in view mode the list of the
files, in edit mode the upload with the `attach_*` and `detach_*` actions
of AshStorage. It has `label`, `description`, `only`, and `visible?`. A
field with `type :attachment` is a file input for an `Ash.Type.File`
argument; a column with `type :attachment` shows the files of each row.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 232" role="img" aria-labelledby="dg-att-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-att-t">The lab reports of a quality test: the list of the files in view mode, and the upload in edit mode</title>
<rect class="dg-p" x="10" y="10" width="470" height="212" rx="8"/>
<text class="dg-h" x="26" y="40">pH · B-2026-043</text>
<rect class="dg-tb" x="26" y="52" width="160" height="16" rx="3"/><text class="dg-t" x="31" y="64">attachments :lab_reports</text>
<text class="dg-st" x="26" y="90">Lab reports</text><text class="dg-l" x="26" y="106">PDF or images from the lab.</text>
<rect class="dg-b" x="26" y="118" width="20" height="24" rx="2"/><text class="dg-a" x="56" y="135">ph-2026-11-14.pdf</text><text class="dg-l" x="230" y="135">184 KB</text>
<rect class="dg-b" x="26" y="152" width="20" height="24" rx="2"/><text class="dg-a" x="56" y="169">meter-photo.jpg</text><text class="dg-l" x="230" y="169">1.2 MB</text>
<rect class="dg-p" x="520" y="10" width="470" height="212" rx="8"/>
<text class="dg-h" x="536" y="40">pH · B-2026-043</text>
<text class="dg-st" x="536" y="70">Lab reports</text><text class="dg-l" x="536" y="86">PDF or images from the lab.</text>
<rect class="dg-c" x="536" y="96" width="438" height="50" rx="6"/>
<text class="dg-v" x="650" y="126">Drop files here, or</text><text class="dg-a" x="776" y="126">browse</text>
<text class="dg-v" x="536" y="172">ph-2026-11-14.pdf</text><text class="dg-l" x="700" y="172">184 KB</text><text class="dg-v" x="960" y="172">×</text>
<text class="dg-v" x="536" y="196">meter-photo.jpg</text><text class="dg-l" x="700" y="196">1.2 MB</text><text class="dg-v" x="960" y="196">×</text>
<text class="dg-l" x="780" y="214">× runs detach_lab_reports</text>
</svg>
<figcaption>The files of a quality test. View mode lists them; edit mode adds the upload and a remove button for each file.</figcaption>
</figure>

### DSL

```elixir
defmodule BreweryWeb.QualityTestLive do
  use PyroManiac, resource: Brewery.QualityTest

  page do
    route "/quality-tests"
    exclude [:destroy]
  end

  view :read do
    type :data_table
    primary? true
    default_sort "-tested_at"
    exclude [:id, :batch_id, :tester_id, :batch, :tester, :passed_text, :lab_reports_urls]
    column :test_type
    column :tested_at
    column :result
    column :passed
    column :notes

    column :lab_reports do
      type :attachment
    end

    action :archive, :discard do
      field :lab_reports, type: :attachment, autofocus: true
    end
  end

  view :read do
    type :card
    primary? true
    action [:create, :update], :guard

    section :test do
      label "Lab test"
      description "One measurement of one batch."
      select :test_type, autofocus: true
      combobox :batch_id
      combobox :tester_id
      field :tested_at
      field :result
      field :passed
      field :notes, type: :textarea
    end

    attachments :lab_reports do
      label "Lab reports"
      description "PDF or images from the lab."
    end
  end
end
```

`:archive` takes the files in an `Ash.Type.File` argument: its form needs
a `field` with `type :attachment` for it (a compile error otherwise).

<!-- tabs-close -->

## Workflow

With [AshStateMachine](https://hexdocs.pm/ash_state_machine) or
[AshWorkflow](https://hex.pm/packages/ash_workflow) on the resource, a
`workflow` node shows the status of the record.

| Option | The UI |
|---|---|
| `type :steps` (default) | Each state (or step) in order, the current one marked, the states before it as done. |
| `type :badge` | The current state only, as a badge (its label: the humanized state). |
| `orientation` (default `:horizontal`) | The states of `type :steps` in a row, or in a column (`:vertical`). With `type :badge`, `:vertical` is a compile error. |
| `transitions?` (default `true`) | A button for each transition that the record can take now and that is an action of the view. |
| `history :rel` | The transition log of the record (a relationship), as a timeline. |
| `label` (default "Status"), `description`, `only`, `visible?`, `render` | As the other nodes. |

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 210" role="img" aria-labelledby="dg-wf-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-wf-t">The workflow of a purchase order: the steps with the current one, two transition buttons, and the history</title>
<rect class="dg-p" x="10" y="10" width="980" height="190" rx="8"/>
<rect class="dg-tb" x="22" y="18" width="200" height="16" rx="3"/><text class="dg-t" x="27" y="30">workflow · type :steps</text>
<text class="dg-st" x="26" y="58">Status</text>
<circle class="dg-ok" cx="40" cy="84" r="10"/><text class="dg-okt" x="36" y="88">✓</text><text class="dg-v" x="56" y="88">Draft</text>
<line class="dg-g" x1="100" y1="84" x2="130" y2="84"/>
<circle class="dg-pri" cx="144" cy="84" r="10"/><text class="dg-bw" x="140" y="88">2</text><text class="dg-st" x="160" y="88">Submitted</text>
<line class="dg-g" x1="236" y1="84" x2="266" y2="84"/>
<circle class="dg-b" cx="280" cy="84" r="10"/><text class="dg-bt" x="276" y="88">3</text><text class="dg-tab" x="296" y="88">Approved</text>
<line class="dg-g" x1="364" y1="84" x2="394" y2="84"/>
<circle class="dg-b" cx="408" cy="84" r="10"/><text class="dg-bt" x="404" y="88">4</text><text class="dg-tab" x="424" y="88">Closed</text>
<rect class="dg-pri" x="26" y="112" width="76" height="26" rx="4"/><text class="dg-bw" x="38" y="129">Approve</text>
<rect class="dg-b" x="110" y="112" width="70" height="26" rx="4"/><text class="dg-bt" x="124" y="129">Reject</text>
<rect class="dg-tb" x="190" y="117" width="196" height="16" rx="3"/><text class="dg-t" x="195" y="129">transitions? · actions of the view</text>
<line class="dg-g" x1="520" y1="44" x2="520" y2="190"/>
<rect class="dg-tb" x="540" y="18" width="150" height="16" rx="3"/><text class="dg-t" x="545" y="30">history :transitions</text>
<text class="dg-st" x="540" y="58">History</text>
<circle cx="550" cy="80" r="5" class="dg-info"/><text class="dg-v" x="564" y="84">Draft → Submitted</text><text class="dg-l" x="720" y="84">Ana Ruiz · Nov 12, 09:14</text>
<circle cx="550" cy="106" r="5" class="dg-b"/><text class="dg-v" x="564" y="110">Created as Draft</text><text class="dg-l" x="720" y="110">Ana Ruiz · Nov 11, 16:40</text>
</svg>
<figcaption>A workflow node in view mode: the steps with the current one, the transitions that are actions of the view, and the history.</figcaption>
</figure>

### DSL

```elixir
# a resource with AshStateMachine (not in the Brewery domain)
view :read do
  type :card
  primary? true
  # No input in the tree (`field :number` is a value): `confirm` is required.
  action :approve, :discard do
    confirm "Approve the order?"
  end

  action :reject, :guard do
    confirm "Reject the order?"
  end

  field :number

  workflow do
    type :steps
    history :transitions
  end
end
```

<!-- tabs-close -->

The buttons of the node are the transitions that the record can take and
that are actions of the view (`transitions? false` hides them). A button
runs its action as any other action of the view: its form, its `confirm`,
its `state`. The history is a timeline, newest first
([Timelines](views.md#timelines)). In a form, the node is read-only. A
resource without a state machine or a workflow does not compile with a
`workflow` node.

## Links

`link_to Page` navigates to another page. It is an entity on a `column`, a
view `field`, a `combobox`, a read-only `field` of a relationship, and
`related`. A node without `link_to` has no link.

```elixir
column :recipe do
  link_to BreweryWeb.RecipeLive               # the primary card of the recipe
end

related :batches do
  type :data_table
  limit 5

  link_to BreweryWeb.BatchLive do             # each batch, and "All batches"
    single_view :read
    list_view :read
  end
end
```

Refer to [Links](pages.md#links).

## The surface

The card loads the values of its tree, the labels of its links, its
counts, and its files. Each must be exposed in `loads` of its read action
(refer to [The surface](surface.md)).
