# Decorations

A decoration is the meaning of a value, not a style: a cell, a value of
the record tree, an item or a group of the navigation, the header of a
kanban lane, and a destructive action button. The renderer maps each
decoration to its own style. For the DSL and the design expectations,
refer to the tutorial [Decorations](../tutorials/decorations.md).

## The sources

| DSL | The value | Function |
|---|---|---|
| `decoration` of a `column` | A decoration atom, or an Ash expression on the row. | `PyroManiac.View.decoration/3` |
| `decoration` of a `field`, `select`, `combobox`, `input` | A decoration atom, or an Ash expression on the record (view mode). | `PyroManiac.View.decoration/3` |
| `decoration` of a navigation `item` or `group` | A decoration atom, or `nil`. | The `decoration` field of `PyroManiac.Navigation.Item` and `PyroManiac.Navigation.Group` |
| A lane record (`PyroManiac.KanBan.Lanes`) | Its `decoration` attribute (one of the configured set, or `nil`). | `PyroManiac.KanBan.Info.lanes/2` (`record`) |
| A destroy action | The `:danger` decoration of the action button and of its confirmation. | |

## The set

| Function | Gives |
|---|---|
| `PyroManiac.Info.decorations/0` | The configured set: `config :pyro_maniac, decorations: [...]` (compile time), else the default set. |
| `PyroManiac.Info.default_decorations/0` | `[:neutral, :info, :success, :warning, :danger]`. |

The transformers accept only the configured names; an unknown static name
is a compile error. So the DSL never gives a renderer a name outside the
set, but the set can hold names that the renderer does not know.

## Evaluation

`PyroManiac.View.decoration(entity, record, actor)` gives the decoration
of a column or a field for a record:

- a static decoration: the decoration;
- an expression: its value, evaluated in memory (`Ash.Expr.eval/2` with
  the record and the actor; `^actor(...)` is filled);
- `nil`, an expression that gives a value outside the set, or an error of
  the evaluation: `nil` (no decoration). It never raises.

The refs of a `decoration` expression are validated at compile time and
recorded in `__decoration_refs__` of the entity. They are in the loads of
the view (`PyroManiac.Info.build_loads_from_view/2`, `PyroManiac.Card.paths/2`)
and in the surface of the page, so the record has them when the renderer
evaluates the expression. A renderer that builds its own query MUST load
them.

## The contract

A renderer MUST:

- map each configured decoration to a style. A decoration that the
  renderer does not know (a custom one, such as `:muted`) MUST still
  render: with a style that the application gives (for example a CSS
  class `decoration-muted`, or a theme map of the renderer), else the
  `:neutral` style. It MUST NOT raise.
- evaluate an expression with `PyroManiac.View.decoration/3` (the entity,
  the record, the actor): a decoration atom, or `nil` (no decoration).
- render `nil` as no decoration: the plain value.
- not carry the meaning by color only: the value stays as text, and a
  decoration that signals a state (`:warning`, `:danger`) SHOULD have an
  icon or a text for assistive technology (for example a visually hidden
  "Warning:").

A renderer SHOULD give the application a way to style each decoration
(a class name derived from the decoration, or a theme map), so a custom
decoration needs no change to the renderer.

## Checklist

- [ ] A style for each configured decoration (`PyroManiac.Info.decorations/0`).
- [ ] A fallback for an unknown one: the style of the application, else
  `:neutral`; no raise.
- [ ] Expressions with `PyroManiac.View.decoration/3`, with their refs
  loaded.
- [ ] Decorations of the columns, of the record tree (view mode), of the
  navigation items and groups, of the kanban lanes, and `:danger` on a
  destructive action.
- [ ] No meaning by color only.

Back to the [Overview](renderer-overview.md).
