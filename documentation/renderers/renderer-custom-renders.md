# Custom renders

The content of a node (`render`, `description`, the `label` of a column)
is a text or an expression for every renderer, and at most one
implementation for each renderer. A renderer validates its
implementations at compile time and, at run time, renders its
implementation, else the text, else the value of the expression, else
its default UI. For the DSL and the design expectations, refer to the
tutorial [Custom renders](../tutorials/custom-renders.md).

## The data

Each `render`, `description`, and `label` entity is a map
(the type `t:PyroManiac.Content.t/0`):

| Field | Value |
|---|---|
| `kind` | `:text`, `:expr`, or `:impl`. (`:inherit` is resolved at compile time: the description of the source as `:text`, else no entry.) |
| `renderer` | The renderer module for `:impl`, else `nil`. Not a compile-time dependency. |
| `implementation` | The string (`:text`), the Ash expression (`:expr`), or the term of the renderer (`:impl`). |
| `__refs__` | The fields that an expression refers to (set by the transformer). |

A node holds a list of them under its key (`column.render`,
`view.description`, `column.label`, ...), or `nil`.

## The functions

| Function | Gives |
|---|---|
| `PyroManiac.Content.resolve(entries, renderer)` | `{:impl, implementation}` (the implementation of the renderer), else `{:text, string}` or `{:expr, expression}`, else `nil` (render the default). |
| `PyroManiac.Render.resolve/2` | The same, for `render`. |
| `PyroManiac.Content.value(entries, renderer, record, actor \\ nil)` | `{:impl, implementation}`, or `{:value, value}` (the text, or the expression evaluated on the record), or `nil`. The value of an expression is `nil` without a record or on an error. |
| `PyroManiac.Content.portable/1` | The text or the expression, or `nil`. |
| `PyroManiac.Content.text/1` | The text, or `nil` (an expression, or implementations only). |
| `PyroManiac.Content.refs/1` | The fields that the expressions of the `render`, `description`, and `label` of an entity refer to. |
| `PyroManiac.Render.implementation/2` | Only the implementation of the renderer, or `nil`. |
| `PyroManiac.Render.nodes/1` | The nodes of a page with `render` entities, or with implementations in `description` or `label`: `%{entity:, origin:, label:, renders:}`. |
| `PyroManiac.Render.verify/3` | The check of a renderer ([Verifier](#verifier)). |

To evaluate `{:expr, expression}` itself, a renderer uses `Ash.Expr.eval/2`
on the loaded record with the actor, as `PyroManiac.View.decoration/3`
does for a decoration. The refs of the expressions are in the loads of
the view (`PyroManiac.Info.build_loads_from_view/2`,
`PyroManiac.Card.paths/2`); a renderer that builds its own query MUST load
them (`PyroManiac.Content.refs/1`).

## What PyroManiac checks

`ValidateRenders` (a transformer of the page) checks the content of the
views, their columns, tree nodes, and extra actions, the actions and
their trees, the extra actions of the page, and the description of the
page:

- at most one text or expression for each key;
- at most one implementation for each renderer, for each key;
- no expression in the own `render` and `description` of a view, or in
  the description of the page (no record);
- no text or expression in the `render` of an input (`field`, `select`,
  `combobox`, `input`).

The refs of each expression are validated against the resource (an
unknown field is a compile error). `render Renderer` without an
implementation is a compile error of the entity.

PyroManiac does not check that the page has an implementation for a
given renderer: that is the verifier of each renderer.

## Verifier

A renderer is an extension of the page with a verifier that calls
`PyroManiac.Render.verify(dsl, renderer, validate)`. For each node of
`PyroManiac.Render.nodes/1`:

- a node with an implementation for `renderer`: `validate.(implementation)`
  gives `:ok`, or `{:error, reason}` (a compile error at the node, with the
  reason);
- a node without one: a text or an expression satisfies the renderer;
  else a compile error ("has a `render` for [...], but not for ...").

`verify/3` gives `:ok`, or `{:error, Spark.Error.DslError}` for the first
node that fails. The renderer MUST call it, and SHOULD validate as much as
it can at compile time (the module exists and exports its function, the
props are known), so a page with a wrong implementation does not compile.

The commands of the palette are in the navigation module, not in a page:
the renderer validates them itself ([Navigation](renderer-navigation.md#run)).

```elixir
defmodule PyroManiac.LiveView.Verifiers.VerifyRenders do
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl) do
    PyroManiac.Render.verify(dsl, PyroManiac.LiveView, fn
      module when is_atom(module) -> :ok
      {module, opts} when is_atom(module) and is_list(opts) -> :ok
      other -> {:error, "#{inspect(other)} is not a component module"}
    end)
  end
end
```

## Rendering

For each node with content, the renderer:

- MUST resolve the content with `PyroManiac.Content.resolve/2` (or
  `value/4`) and its own module: its implementation first, else the text,
  else the value of the expression on the record, else its default UI.
- MUST render an implementation in place of the whole node: a cell, a
  value of the tree (view mode; an input in its form), a section, a
  `related`, a step, a tab, an extra action (its button and its content).
  The implementation gets what the default UI would get: the record (or
  the records), the entity, the actor, and the page.
- MUST render a text or the value of an expression as text (escaped), not
  as markup. `nil` renders as the empty value of the node.
- MUST NOT raise on an expression that fails: the value is `nil`.
- MUST use the `label` and the `description` of the node for its header,
  its accessible name, and its help text, also when the `render` is an
  implementation.

```elixir
# in a component of the renderer
case PyroManiac.Render.resolve(column.render, PyroManiac.LiveView) do
  nil -> default_cell(assigns)
  {:text, text} -> text
  {:expr, expression} -> eval_expression(expression, assigns.row, assigns.actor)
  {:impl, {module, opts}} -> module.render(Map.put(assigns, :opts, opts))
  {:impl, module} -> module.render(assigns)
end
```

### The render view

A `:render` view has only implementations (no record). The renderer calls
its implementation (`PyroManiac.Render.implementation/2`) with the records
of the read action, the state of the list, the actor, and the page. Refer
to [The render view](renderer-views.md#the-render-view).

### Accessibility

The frame of the node (its label, its description, its place in the
focus order, the empty and the loading states) is the renderer's. The
inside of an implementation (its keyboard, its accessible names, a text
alternative of a chart) is the implementation's.

## Checklist

- [ ] A verifier that calls `PyroManiac.Render.verify/3` and validates the
  form of the implementations.
- [ ] The content of each node (`render`, `description`, the `label` of a
  column) with `PyroManiac.Content.resolve/2`: the implementation of the
  renderer, else the text, else the value of the expression on the record.
- [ ] The refs of the expressions loaded with the record.
- [ ] Implementations for every node of `PyroManiac.Render.nodes/1`, the
  `:render` view, and the `render` commands of the palette.

Back to the [Overview](renderer-overview.md).
