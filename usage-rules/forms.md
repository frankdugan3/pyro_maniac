# Actions and forms

The actions of a page are in its views. There is no `forms` section. A
view runs the actions that it names, with `action` and `bulk_action`, and
the nodes of a tree are the form of an action.

```elixir
view :read do
  type :data_table
  primary? true
  exclude [:id, :code, :contact_email, :phone, :notes, :ingredient_count]
  column :name
  column :active

  action :create, :guard do
    delegate_to BreweryWeb.SupplierLive   # the form of the card of this page
  end

  action :rename do                        # a row action with its own form
    state :guard
    presentation :drawer
    field :name, autofocus: true
    field :reason
  end

  action :destroy, :discard do             # no inputs: a confirmation
    confirm "Delete the supplier?"
  end

  bulk_action :update, :discard do         # the selected rows
    field :active, autofocus: true
  end
end

view :read do
  type :card
  primary? true
  action [:create, :update], :recover     # the tree of the card is their form

  section :supplier do
    field :name, autofocus: true
    field :code, size: :code
    field :contact_email, type: :email
    field :phone
    field :active
    field :notes, type: :textarea
  end
end
```

## `action`

`action name_or_names` names a create, update, destroy, or generic action
of the resource of the view. A read action is not an `action`: it is the
name of a view (or `read_action`). `action [:create, :update]` names more
than one action with the same tree.

| In | The form |
|---|---|
| a card, without nodes | The tree of the card. **Edit** switches the card to the update form in the same place |
| a card or a list view, with nodes | Its own tree: a button of the view opens it (`presentation`) |
| a card or a list view, with `delegate_to Page` | The tree that a view of that page uses for the action of the same name. This page: the tree of its card |
| a list view, without nodes | An action without inputs (a destroy, a status change) is a confirmation, with no form. An action with inputs needs nodes or `delegate_to` |
| a column | An inline edit of the cell: inputs only (`field`, `select`, `combobox`, `input`, `compound`), no `delegate_to`, no `resource` (refer to [views](views.md)) |

In a list view, `create` is a toolbar button, and the other actions are
row actions.

| Key            | Notes                                                                                     |
| -------------- | ----------------------------------------------------------------------------------------- |
| `name`         | Required. Action name(s): an atom or a list                                               |
| `state`        | Required, no default: `:guard`, `:recover`, or `:discard` (see below). The optional second argument or an option in the block |
| `confirm`      | A confirmation before the action runs: a text, or an Ash expression (see below)          |
| `label`        | Display label (defaults to the humanized name)                                            |
| `presentation` | How its own tree opens: `:modal` (default), `:drawer`, or `:page`                          |
| `max_columns`  | The maximum number of columns of the form                                                 |
| `resource`     | Another resource (a cross-resource action, with `set`)                                    |
| `delegate_to`  | The tree of the same action in a view of another page. Not with nodes                     |

Nested entities: `description`, `field`, `select`, `combobox`, `input`,
`section`, `row`, `compound`, `related`, `attachments`, `workflow`, `tabs`,
`step`, and `set`.

`description` is the text below the title of the form: a text, an Ash
expression, or `description Renderer, implementation` (refer to
[views](views.md)). `description :inherit` takes the description of the
action. Without it, the form has no description.

```elixir
action :complete do
  state :guard
  label "Complete batch"
  description :inherit
  # the inputs
end
```

### `state`

Each `action` and `bulk_action` declares what happens to the unsaved
inputs of its form. It is required and has no default. A renderer must
implement `:guard` and `:recover`.

| `state`    | Meaning                                                                         |
| ---------- | ------------------------------------------------------------------------------- |
| `:guard`   | Warn before the user leaves the form with unsaved changes                       |
| `:recover` | Keep the inputs, and restore them after a reload or a lost connection           |
| `:discard` | Neither: for an action without inputs, an inline edit, or a short form          |

```elixir
action :update, :recover                  # the second argument

action :rename do                         # or an option in the block
  state :guard
  field :name, autofocus: true
end

edit_columns :update, [:target_og, :target_fg], :discard do   # the third argument
  field :target_og, autofocus: true
  field :target_fg
end
```

### `confirm`

`confirm` asks the user to confirm before the action runs. It is a text, or
an Ash expression on the record (and `^arg(:name)` for the inputs) that
gives the message, or `nil` for no confirmation. The refs of the
expression are validated at compile time and loaded with the record
(`__confirm_refs__`).

```elixir
action :destroy, :discard do
  confirm "Delete the recipe?"
end

action :retire, :discard do
  confirm expr(if batch_count > 0, do: "The recipe has batches. Retire it?")
end
```

### Completeness

The transformer checks the form of each action (after `only`):

- Each accepted attribute and each public argument of the action is an
  input, or has a `set`.
- Exactly one input has `autofocus` when the form has inputs. It is not on
  a later tab and not in a closed section.
- The names are fields of the resource or arguments of the action.

An inline edit (the `action` of a column, `edit_columns`) has inputs only
and is not checked for completeness or `autofocus`.

A `field` that is not an input of the action (a calculation, an aggregate,
an attribute that the action does not accept) is read-only: it shows its
value. A read-only field on a relationship can have a `link_to` (refer to
[views](views.md)).

### `only`

One tree serves the read action of its view (view mode) and each action
that uses it. `only [names]` puts a node in some of them. The names are the
read action of the view and the actions of the tree; another name is an
error. An action with its own tree has its own names.

```elixir
view :read do
  type :card
  primary? true
  action [:create, :update], :guard

  section :recipe do
    field :name, autofocus: true
    select :style
    select :status
    field :batch_count, only: [:read]           # view mode only
  end

  section :targets do
    field :target_abv
    field :target_og
    field :target_fg
    field :description, type: :textarea, only: [:create, :update]
  end
end
```

`only :view` and `only :edit` are removed: view mode is the read action of
the view.

### The actions of the page

Each exposed action of the resource (read, create, update, destroy,
generic) is used by a view (the name of a view for a read action, `action`
or `bulk_action` for the others), or is in `exclude` of the `page`
section. This check runs last, after the other checks of the page. It
applies to pages only: a module without the `page` section is not checked.

```elixir
page do
  route "/recipes"
  exclude [:list, :activate, :retire]
end
```

- `exclude` names exposed actions only. An action in `exclude` that a view
  uses is an error.
- The AshStorage actions of an attachment (`attach_photos`, ...) are not
  checked.

## `bulk_action`

`bulk_action name do ... end` in a list view runs an update or destroy
action on the selected rows. Its block is the form (inputs only).

```elixir
bulk_action :update, :discard do
  select :status, autofocus: true
end
```

| Key               | Default   | Notes                                                                                                  |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------ |
| `name`            | required  | Action name(s)                                                                                         |
| `state`           | required  | `:guard`, `:recover`, or `:discard`, as on `action`                                                    |
| `confirm`         | nil       | A text, or an Ash expression, as on `action`                                                            |
| `label`           | humanized | Button label                                                                                           |
| `max_columns`     | nil       | The maximum number of columns of the form                                                              |
| `set_all_fields?` | `false`   | When `true`, all fields submit (even nil); when `false`, empty fields are stripped for partial updates |
| `delegate_to`     | nil       | The bulk action of the same name in another page                                                       |

Nested entities: `description` (as on `action`; `:inherit` takes the
description of the action), `field`, `select`, `combobox`, `input`,
`section`, `row`, `compound`, and `step` (no `set`, `related`,
`attachments`, or `tabs`). A bulk action uses its action (refer to "The
actions of the page").

## The boundary: meaning, not styles

The DSL declares **meaning**. It has no `class` or `input_class` option,
and no functions. A renderer maps the meaning to its own styles:

- The kind of input: `field`, `select`, `combobox`, or `input`.
- The content role of an input: `size`.
- The spacing of a section or a step: `density`.
- The structure: `section`, `tabs`, `step`, `row`, `compound`, and `visible?`.
- The actions of a node: `only`.
- The number of columns at most: `max_columns`.

`PyroManiac.Info.form_layout/1` gives the resolved form of an action as
plain maps (no functions), so it encodes as JSON for other renderers.

## The input entities

Each input is one of four entities. The transformer does **not** infer the
kind of input from the Ash type. A wrong entity is a compile error with a fix:

- `field` on the foreign key of a `belongs_to` → "use `combobox`".
- `field` on a closed set of values → "use `select`" (or `type: :checkbox`
  for a group of checkboxes).

All four have these options:

| Key           | Default   | Notes                                                                                     |
| ------------- | --------- | ----------------------------------------------------------------------------------------- |
| `name`        | required  | Attribute or argument of the action                                                       |
| `label`       | humanized | Input label                                                                               |
| `autofocus`   | `false`   | Focus this input when the form opens                                                      |
| `path`        | `[]`      | A relative path of relationships: the input is in the nested form of that path, no group |
| `size`        | `:auto`   | The content role: `:code`, `:term`, `:name`, `:phrase`, or `:prose` (see below)           |
| `visible?`    | nil       | Conditional visibility: an Ash expression (see below)                                     |
| `only`        | nil       | The actions that show it: the read action of the view (view mode) and the actions of the tree |
| `decoration`  | nil       | The meaning of the value in view mode: a decoration, or an Ash expression (refer to [views](views.md)) |
| `empty_text`  | `"—"`     | The text in view mode when the value is `nil`                                             |

And these entities:

- `description`: the help text. A text, an Ash expression, or
  `description Renderer, implementation`; `description :inherit` takes the
  description of the attribute or argument. None by default. It is not a
  keyword option, and the options of an entity with a block go in the
  block:

  ```elixir
  field :notes do
    type :textarea
    description :inherit
  end

  select :status do
    description "The stage of the batch."
  end
  ```

- `render Renderer, implementation`: a custom input for one renderer. An
  input takes no text or expression in `render`.

### `field`

A value that the user types or picks with a native control.

```elixir
field :name
field :description, type: :textarea
field :lot_number, size: :code
```

`type` (default `:default`, inferred from the Ash type) is one of
`attachment boolean checkbox date datetime email interval naive_datetime
nested_form number password search tel text textarea time toggle url`.
Any other atom is a compile error. For a custom control, use `input`.

### `select`

A closed set of values. The options come from the type: a `one_of`
constraint, an `Ash.Type.Enum` (with its labels and descriptions), a
`Ash.Type.NewType` of them, or an array of them (a multiple select).

```elixir
select :status
select :style, prompt: "Pick a style"
select :unit, options: [{"Kilograms", :kg}, {"Grams", :g}]
```

| Key       | Notes                                                   |
| --------- | ------------------------------------------------------- |
| `prompt`  | The text of the empty option                            |
| `options` | Explicit options: values, or `{label, value}` tuples    |

A `select` with no options (no closed set and no `options`) is a compile
error.

### `combobox`

A searchable list. It has three modes, from the field:

- **Select mode**: the foreign key of a `belongs_to`. It selects a record of
  the destination. The value is its primary key, and the label is its
  `default_label`.
- **Select many** (attach and detach): an argument that the action passes
  to `manage_relationship` (for example of a `many_to_many`). The user
  selects the related records. The resolved input is in select mode with
  `__multiple?__: true`, `__relationship__` (the relationship), and
  `__resource__` (its destination).
- **Free text**: a `:string` or `:ci_string` that is not a foreign key. The
  user types any text, and the combobox suggests the distinct existing
  values. Any other type is a compile error.

The combobox declares its search **inline**. Do not add a read action to a
resource only for a combobox. An `argument :name, value` entity gives an
input for an argument of `read_action`. The value is a literal or a
template with no `^`: `search()`, `input(:name)`, `actor(:field)`, or
`arg(:name)`.

```elixir
combobox :supplier_id

combobox :lot_number

combobox :lot_number do
  filter expr(is_nil(^input(:name)) or name == ^input(:name))
end

combobox :brewer_id do
  filter expr(active == true)
  sort name: :asc
  limit 50
end

combobox :supplier_id do
  read_action :by_prefix
  argument :prefix, search()
  search false
end
```

| Key           | Default                   | Notes                                                                                                         |
| ------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `read_action` | primary read              | The read action. Its own filter, preparations, and policies apply                                             |
| `search`      | `[label_key]`             | The fields that the typed text matches (`contains`, case-insensitive, joined with `or`). `false` to disable   |
| `filter`      | nil                       | An Ash expression, joined with `and`. It can use `^search()`, `^input(:name)`, and `^actor(...)`              |
| `sort`        | `[{label_key, :asc}]`     | The order of the options. In free text, it must start with the value key                                      |
| `limit`       | `20`                      | 1 to 100                                                                                                      |
| `label_key`   | `default_label` of dest.  | Select mode only. Free text: always the value key                                                             |
| `value_key`   | primary key / field name  | The value of an option                                                                                        |

The transformer validates the query at compile time: the read action
exists, each required argument is mapped, `search`, `sort`, and the keys are
fields, the `filter` parses, the typed text filters the options (by
`search`, `^search()` in `filter`, or `search()` in an `argument`), and each
`^input(:name)` is an input at the same level.

### `input`

A custom input type: a module that implements `PyroManiac.Form.InputType`
(`schema/0`, the Spark options of the type, and `default_size/0`). The
options are validated at compile time.

```elixir
input :description, {BreweryWeb.Inputs.Markdown, toolbar: :minimal}
input :notes, BreweryWeb.Inputs.Markdown
```

A renderer renders it with its own behaviour, which the module also
implements.

## Sizes

`size` is the **content role** of an input, not a width:

| `size`    | Content                                    |
| --------- | ------------------------------------------ |
| `:code`   | Short identifiers: lot number, code, unit  |
| `:term`   | One short value: date, phone, gravity      |
| `:name`   | Names, emails, titles                      |
| `:phrase` | Long text of one line: a test result       |
| `:prose`  | Block content: textarea, notes (full row)  |

`:auto` (the default) is resolved at compile time: textarea, attachment,
and checkbox groups are `:prose`; date, time, number, boolean, toggle,
checkbox, and interval are `:term`; a text input with an Ash `max_length`
≤ 10 is `:code`, ≤ 24 is `:term`, ≥ 100 is `:phrase`; `select` and
`combobox` are `:name`; `input` uses `default_size/0`; others are `:name`.

## Layout entities

### `section`

A titled block of inputs. Recursive. With `path`, the inputs are in the
nested form of that relationship. A `row` of sections puts them side by
side.

```elixir
section :lines do
  path [:lines]
  density :dense
  field :description
  field :quantity
  field :pallet_count
end

section :internal do
  collapsible? true
  collapsed? true
  description "Notes for the purchasing team."
  field :notes
end
```

| Key            | Default    | Notes                                                    |
| -------------- | ---------- | -------------------------------------------------------- |
| `name`         | required   | Positional atom. The identifier                          |
| `label`        | humanized  | The heading (`:quality_tests` gives `"Quality Tests"`)                 |
| `path`         | `[]`       | Path prefix (appended to outer paths)                    |
| `density`      | `:normal`  | `:dense` uses narrower tracks (lists of short inputs)    |
| `max_columns`  | nil        | The maximum number of columns                            |
| `collapsible?` | `false`    | The user can close and open the section                  |
| `collapsed?`   | `false`    | Starts closed. Requires `collapsible? true`              |
| `only`         | nil        | The actions that show it (`[:read]`: view mode only)     |
| `visible?`     | nil        | Conditional visibility                                   |

A section can have a `description` (text below the label) and `render`
entities: each a text, an Ash expression, or `Renderer, implementation`.
The sections of a view and of an action are the same entity.

A closed section keeps its inputs in the form, so they submit. An input with
`autofocus` cannot be in a closed section.

### `tabs` and `tab`

One `tabs`, the last node of the top level, with 2 or more `tab :name`
entities (`label`, `count`, `only`). The nodes before `tabs` show on every
tab. `count` is an aggregate or a calculation. The input with `autofocus`
is above the tabs or on the first tab.

### `related` and `attachments`

`related :rel` shows the records of a relationship, read-only in a form:
`delegate_to` (a page of the destination, as a delegated viewer) or `type`
(`:list`, `:data_table`, `:grid`, `:count`, `:badge`) with `field`
entities. `presentation` is where they show: `:inline` (the default), or
`:modal` or `:drawer` over the page. It has `count`, `limit`, `description`,
`render`, and one `link_to`: each record links to its single view, and a list link opens
a list view filtered by the relationship (refer to `views.md`).
`attachments :name` shows the files of an AshStorage attachment; it has
`label` and `description` (no `render`). Both have `only` and `visible?`. Both are of the record: not in a section with a
`path`, and not in a bulk action.

### `row`

**Layout only**: keep the children on one line when there is space, and
wrap them as a unit. It has 2 children or more, and no `:prose` input.

```elixir
row do
  field :target_og, size: :code
  field :target_fg, size: :code
  field :target_abv
end
```

### `compound`

**Meaning**: one value made of tiny inputs, for example the original and
the final gravity of a batch. The label is the legend. The labels of the
parts are for assistive technology only, unless `show_labels? true`. The
errors of the parts show in one list. It has 2 parts or more, and no `:phrase` or `:prose` part. It has `description` and `render` entities.

```elixir
compound :gravity do
  field :actual_og, label: "OG"
  field :actual_fg, label: "FG"
end
```

`row` and `compound` are orthogonal: a row can contain compounds.

### `step` (wizard forms)

A `step` is a single page of a multi-step wizard, for a long create form.
In view mode, a step is a section. A step has no `only`: put the steps in
the own tree of an action.

```elixir
action :create, :recover do
  step :basics do
    field :name, autofocus: true
    field :email, type: :email
  end

  step :role do
    description "What the staff member does."
    select :role
    field :active
  end

  step :review do
    review? true
  end
end
```

| Key           | Default   | Notes                                                                    |
| ------------- | --------- | ------------------------------------------------------------------------ |
| `name`        | required  | Step identifier                                                          |
| `label`       | humanized | Step heading                                                             |
| `path`        | `[]`      | Base path; the renderer wraps the inputs in a nested form for this path  |
| `review?`     | `false`   | Auto-generate a read-only summary of previous steps                      |
| `density`     | `:normal` | `:dense` uses narrower tracks                                            |
| `max_columns` | nil       | The maximum number of columns                                            |
| `visible?`    | nil       | Conditional visibility                                                   |

A step can have a `description` (text below the heading) and `render`
entities.

## `visible?`

`visible?` is an **Ash expression**, not a function. The server evaluates
it in memory with the current values of the form, so it can refer only to
the attributes and arguments at the level of the entity (no relationship
paths, aggregates, or calculations), `^arg(:name)`, `^actor(...)`, and
`parent(field)`: an attribute of the form one level up, as in Ash. The refs
are validated at compile time.

The level of an input, a row, a compound, or a step is its full path. A
section with a `path` shows or hides all its rows, so its level is the level
that contains it.

```elixir
field :package_date, visible?: expr(status == :packaging)

section :measurements do
  visible? expr(status == :complete)
  field :actual_og
  field :actual_fg
end

section :lines do
  path [:lines]
  field :pallet_count, visible?: expr(parent(carrier) == :truck)
end
```

The option is not called `when`: Elixir parses a line that starts with
`when` as the guard operator of the line before it.

## `set` (cross-resource actions)

With `resource`, the action runs on another resource than the resource of
the view, for example a quality test of a batch from the card of the
batch. `set` fills a field of the action from the record of the view:

```elixir
action :create, :guard do
  resource Brewery.QualityTest
  label "Add test"
  set :batch_id, :id

  select :test_type, autofocus: true
  field :tested_at
  field :result
  field :passed
  field :notes
  combobox :tester_id
end
```

| Key            | Default | Notes                                                                 |
| -------------- | ------- | --------------------------------------------------------------------- |
| `name`         |         | The field (argument or attribute) of the action                       |
| `source`       |         | The field of the record of the view                                   |
| `overridable?` | `false` | Set the value when the form opens; the user can change it (see below) |

By default, the value is set on submit, and the form has no input for it.
A field with such a `set` needs no input (the completeness check). With
`overridable? true`, the value is set when the form opens and the user can
change it: the form must have an input of that name.

```elixir
action :create, :guard do
  resource Brewery.Batch
  set :recipe_id, :id, overridable?: true

  combobox :recipe_id
  field :batch_number, autofocus: true
  # the other inputs
end
```

`set` is only valid inside `action` (not `bulk_action`).

## Common mistakes

- An `action`, `bulk_action`, or `edit_columns` without a `state`. It is
  required: `action :update, :guard`, `state :guard` in the block, or
  `edit_columns :update, [:a, :b], :discard`. `recover?` and `guard?` do
  not exist.
- `tone` on an input. It is renamed `decoration`.
- `set ..., overridable?: true` without an input of that name in the form.
- `forms do ... end`, `form :update` on a card, or `exclude` in a `forms`
  or `views` section. They are removed: the actions are in the views, a
  card has `action [:create, :update]` and its own tree, and `page do
  exclude [...] end` lists the unused exposed actions.
- An action with inputs in a list view without nodes or `delegate_to`. A
  list view has no tree of its own to use.
- `action :read`. A read action is the name of a view, not an `action`.
- A form without an accepted attribute or public argument of the action,
  without one `autofocus`, or with two.
- An exposed action that no view uses and that is not in `page do exclude
  [...] end`.
- `only :view` or `only :edit`. Use `only [:read]` or `only [:create,
  :update]`.
- `field` on a foreign key or on an enum/`one_of` attribute in a form. Use
  `combobox` or `select`.
- `type: :combobox`, `type: :select`, or `type: :markdown` on a `field`.
  These are entities (`combobox`, `select`) or an `input` type module.
- A `class`, `input_class`, or `render_fn` option. They are removed: use
  `size`, `density`, a layout entity, or a `render` entity.
- `section "Title" do`. The argument is an atom: `section :title do`, with
  `label "..."` when the humanized name differs.
- `display` on `related`. It is `type` (`:table` is `:data_table`).
- A `visible?` function (`fn form -> ... end`). Use `visible? expr(...)`.
- A read action on the resource only for a combobox (`read :autocomplete`).
  Declare `filter`, `sort`, and `search` in the combobox.
- `^search()` in an `argument`. Use `argument :name, search()` (no pin), as
  in `set_attribute(:status, arg(:status))` of Ash: the value is not in an
  `expr/1`. In `filter`, which is an expression, use `^search()`.
- Mixing `delegate_to` with nodes. They're mutually exclusive.
- Using `set` inside `bulk_action` (not supported).
- `description: "..."` as a keyword (`field :notes, description: "..."`).
  `description` is an entity: `field :notes do description "..." end`.
- `render "text"` or `render expr(...)` on an input (`field`, `select`,
  `combobox`, `input`). An input takes `render Renderer, implementation`
  only.
- `delegate_to`, `resource`, a `section`, or a `step` in the `action` of a
  column. An inline edit has inputs only (`field`, `select`, `combobox`,
  `input`, `compound`) and edits the record of the row.
