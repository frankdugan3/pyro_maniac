# Decorations

A **decoration** is the meaning of a value: "this batch is late", "this
test failed". It is a name, not a style. Each renderer maps each
decoration to its own style (a color, an icon, a badge), so the same page
looks right in each renderer, and the DSL has no `class` options. For the
renderer contract, refer to
[Decorations](../renderers/renderer-decorations.md).

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

## Where a decoration goes

| DSL | The value | Form |
|---|---|---|
| `decoration` of a `column` | Each cell of the column. | A decoration, or an expression |
| `decoration` of a `field`, `select`, `combobox`, `input` | The value in view mode (the record tree). | A decoration, or an expression |
| `decoration` of a navigation `item` or `group` | The item or the group ([Navigation](navigation.md#decorations-and-badges)). | A decoration only |
| The `decoration` attribute of a lane record (`PyroManiac.KanBan.Lanes`) | The header of the lane of a kanban board. | A value of the attribute |

A destructive action (a destroy) also shows with the `:danger` decoration
of the renderer; it has no DSL.

## Static or an expression

A static decoration marks every value. An expression on the record gives
a decoration, or `nil` (no decoration). Its refs are checked at compile
time (an unknown field is a compile error) and load with the record, so
they can be calculations or aggregates. A result that is not a configured
decoration gives no decoration.

<!-- tabs-open -->

### UI

<figure>
<svg class="dg-svg" viewBox="0 0 1000 250" role="img" aria-labelledby="dg-dec-t" xmlns="http://www.w3.org/2000/svg">
<title id="dg-dec-t">The batches table with decorated status and pass rate cells, a late brew date with a warning, and the five default decorations with a custom muted one</title>
<rect class="dg-p" x="10" y="10" width="620" height="230" rx="8"/>
<text class="dg-h" x="26" y="40">Batches</text>
<text class="dg-l" x="26" y="70">Batch</text><text class="dg-l" x="150" y="70">Status</text><text class="dg-l" x="290" y="70">Brew date</text><text class="dg-l" x="430" y="70">Pass rate</text>
<line class="dg-g" x1="26" y1="78" x2="614" y2="78"/>
<text class="dg-v" x="26" y="102">B-2026-044</text>
<rect class="dg-info" x="146" y="88" width="84" height="20" rx="10"/><text class="dg-infot" x="158" y="102">Fermenting</text>
<text class="dg-v" x="290" y="102">2026-11-02</text>
<rect class="dg-ok" x="426" y="88" width="56" height="20" rx="10"/><text class="dg-okt" x="438" y="102">100 %</text>
<text class="dg-v" x="26" y="132">B-2026-045</text>
<rect class="dg-info" x="146" y="118" width="84" height="20" rx="10"/><text class="dg-infot" x="160" y="132">Planned</text>
<rect class="dg-warn" x="286" y="118" width="110" height="20" rx="10"/><text class="dg-warnt" x="298" y="132">⚠ 2026-11-14</text>
<text class="dg-v" x="430" y="132">—</text>
<text class="dg-v" x="26" y="162">B-2026-041</text>
<rect class="dg-bad" x="146" y="148" width="84" height="20" rx="10"/><text class="dg-badt" x="158" y="162">Cancelled</text>
<text class="dg-v" x="290" y="162">2026-10-20</text>
<rect class="dg-warn" x="426" y="148" width="66" height="20" rx="10"/><text class="dg-warnt" x="436" y="162">⚠ 67 %</text>
<rect class="dg-tb" x="146" y="180" width="300" height="16" rx="3"/><text class="dg-t" x="151" y="192">decoration expr(if status == :cancelled, ...)</text>
<rect class="dg-tb" x="146" y="204" width="330" height="16" rx="3"/><text class="dg-t" x="151" y="216">decoration expr(if pass_rate &lt; 80, do: :warning)</text>
<rect class="dg-p" x="650" y="10" width="340" height="230" rx="8"/>
<text class="dg-st" x="666" y="38">The decorations of the app</text>
<rect class="dg-b" x="666" y="54" width="90" height="20" rx="10"/><text class="dg-bt" x="680" y="68">:neutral</text>
<rect class="dg-info" x="666" y="82" width="90" height="20" rx="10"/><text class="dg-infot" x="680" y="96">:info</text>
<rect class="dg-ok" x="666" y="110" width="90" height="20" rx="10"/><text class="dg-okt" x="680" y="124">:success</text>
<rect class="dg-warn" x="666" y="138" width="90" height="20" rx="10"/><text class="dg-warnt" x="680" y="152">⚠ :warning</text>
<rect class="dg-bad" x="666" y="166" width="90" height="20" rx="10"/><text class="dg-badt" x="680" y="180">✕ :danger</text>
<rect class="dg-c" x="666" y="194" width="90" height="20" rx="10"/><text class="dg-l" x="680" y="208">:muted</text>
<text class="dg-l" x="770" y="68">the default set</text>
<text class="dg-l" x="770" y="208">a custom one: its class,</text>
<text class="dg-l" x="770" y="222">else the :neutral style</text>
<rect class="dg-tb" x="770" y="140" width="200" height="16" rx="3"/><text class="dg-t" x="775" y="152">config :pyro_maniac, decorations:</text>
</svg>
<figcaption>Decorations of cells. The value stays as text; a state (<code>:warning</code>, <code>:danger</code>) also has an icon. The style of each decoration is the renderer's.</figcaption>
</figure>

### DSL

```elixir
# BreweryWeb.BatchLive, the table
column :status do
  decoration expr(if status == :cancelled, do: :danger, else: :info)
end

column :brew_date do
  decoration expr(if status == :planned and brew_date < today(), do: :warning)
end

column :pass_rate do
  decoration expr(cond do
    is_nil(pass_rate) -> nil
    pass_rate < 80 -> :warning
    true -> :success
  end)
end

# BreweryWeb.BatchLive, the card
field :pass_rate do
  decoration expr(if pass_rate < 80, do: :warning)
end

# the navigation
item :quality_tests do
  page BreweryWeb.QualityTestLive
  decoration :warning
end
```

<!-- tabs-close -->

## The set of decorations

The default set is `[:neutral, :info, :success, :warning, :danger]`
(`PyroManiac.Info.default_decorations/0`). An application sets its own
list at compile time, and the DSL accepts only those names:

```elixir
# config/config.exs
config :pyro_maniac, decorations: [:neutral, :info, :success, :warning, :danger, :muted]
```

`PyroManiac.Info.decorations/0` gives the configured set. A static name
that is not in the set is a compile error with a suggestion
(`decoration :warn`: did you mean `:warning`?). A renderer that does not
know a custom decoration still renders it: with the style that the
application gives (for example a CSS class `decoration-muted`, or a theme
of the renderer), else the `:neutral` style.

The set is read at compile time: after a change to the config, recompile
PyroManiac (`mix deps.compile pyro_maniac --force`).

## Design expectations

- A decoration is a meaning. Use `:warning` for "needs attention" and
  `:danger` for "failed" or "destructive", not to get a color.
- The value stays as text. A decoration never replaces it, and a state
  (`:warning`, `:danger`) is not shown by color only: the renderer adds an
  icon or a text for assistive technology.
- `nil` is no decoration: the value shows plain. Keep most values plain,
  so the decorated ones stand out.

## Common mistakes

- `class`, `cell_class`, or `tone`: removed. Use `decoration` (`tone` is
  renamed `decoration`).
- A function as a `decoration`: use a decoration or an Ash expression.
- An expression on a navigation item or group: they take a decoration
  only (they have no record).
