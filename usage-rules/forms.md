# Forms

The `forms` section configures forms for the resource's create, update,
destroy, and bulk actions.

```elixir
forms do
  action :create
  action :update

  bulk_action :archive
end
```

If you do not declare `action` entities, the resource's actions are still
exposed by the form DSL (the `ExpandFormActions` transformer fills in
defaults). Use the `exclude` key on the section to skip specific actions:

```elixir
forms do
  exclude [:retire, :activate]
end
```

## The boundary: meaning, not styles

The form DSL declares **meaning**. It has no `class` or `input_class`
option, and no functions. A renderer (LiveView, or a native renderer such as
Mob or Scenic) maps the meaning to its own styles:

- The kind of input: `field`, `select`, `combobox`, or `input`.
- The content role of an input: `size`.
- The spacing of a group or a step: `density`.
- The structure: `group`, `step`, `row`, `compound`, and `visible?`.
- The number of columns at most: `max_columns`.

`PyroManiac.Info.form_layout/1` gives the resolved tree as plain maps (no
functions), so it encodes as JSON for other renderers.

## Section schema

| Key           | Default | Notes                             |
| ------------- | ------- | --------------------------------- |
| `description` | nil     | Default description (inheritable) |
| `exclude`     | `[]`    | Action names to exclude           |

## `action` — single-record forms

`action :name do ... end` configures a form for a create/update/destroy
action. `name` may be a single atom or a list (`action [:create, :update]`)
to share configuration across actions.

```elixir
action :create do
  label "New Recipe"
  description "Draft a new recipe."

  group "Basics" do
    field :name
    select :style
  end

  field :description, type: :textarea
end
```

| Key           | Notes                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------- |
| `name`        | Required. Action name(s). `wrap_list` — accepts atom or `[atom]`                                        |
| `label`       | Display label (defaults to capitalized name)                                                            |
| `description` | Form description (defaults to action's `description`)                                                   |
| `max_columns` | The maximum number of columns of the form                                                               |
| `resource`    | Target a different resource (cross-resource action — use with `set`)                                    |
| `delegate_to` | Resolve fields from a matching action in another PyroManiac module. Mutually exclusive with inline items |

Nested entities: `field`, `select`, `combobox`, `input`, `group`, `row`,
`compound`, `step`, `set`.

## `bulk_action` — multi-record forms

`bulk_action :name do ... end` configures a button that runs an update or
destroy action against the selected rows.

```elixir
bulk_action :archive do
  label "Archive Selected"
end

bulk_action :reassign do
  set_all_fields? true

  combobox :assignee_id
  field :reason
end
```

| Key               | Default   | Notes                                                                                                  |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------ |
| `name`            | required  | Action name(s) (`wrap_list`)                                                                           |
| `label`           | humanized | Button label                                                                                           |
| `description`     | action's  | Description text                                                                                       |
| `max_columns`     | nil       | The maximum number of columns of the form                                                              |
| `set_all_fields?` | `false`   | When `true`, all fields submit (even nil); when `false`, empty fields are stripped for partial updates |
| `delegate_to`     | nil       | Defer to another PyroManiac module's matching bulk_action                                              |

Nested entities: the same as `action`, without `set` (bulk actions operate
on selected rows, not a parent record).

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
| `description` | from Ash  | Help text (`:inherit` takes the description of the attribute or argument)                 |
| `autofocus`   | `false`   | Focus this input when the form opens                                                      |
| `path`        | `[]`      | A relative path of relationships: the input is in the nested form of that path, no group |
| `size`        | `:auto`   | The content role: `:code`, `:term`, `:name`, `:phrase`, or `:prose` (see below)           |
| `visible?`    | nil       | Conditional visibility: an Ash expression (see below)                                     |

### `field`

A value that the user types or picks with a native control.

```elixir
field :name
field :description, type: :textarea
field :zip, size: :code
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
select :priority, prompt: "Pick a priority"
select :unit, options: [{"Inches", "in"}, {"Millimeters", "mm"}]
```

| Key       | Notes                                                   |
| --------- | ------------------------------------------------------- |
| `prompt`  | The text of the empty option                            |
| `options` | Explicit options: values, or `{label, value}` tuples    |

A `select` with no options (no closed set and no `options`) is a compile
error.

### `combobox`

A searchable list. It has two modes, from the field:

- **Select mode**: the foreign key of a `belongs_to`. It selects a record of
  the destination. The value is its primary key, and the label is its
  `default_label`.
- **Free text**: a `:string` or `:ci_string` that is not a foreign key. The
  user types any text, and the combobox suggests the distinct existing
  values. Any other type is a compile error.

The combobox declares its search **inline**. Do not add a read action to a
resource only for a combobox. An `argument :name, value` entity gives an
input for an argument of `read_action`. The value is a literal or a
template with no `^`: `search()`, `input(:name)`, `actor(:field)`, or
`arg(:name)`.

```elixir
combobox :type_id

combobox :make

combobox :model do
  filter expr(is_nil(^input(:make)) or make == ^input(:make))
end

combobox :standard_id do
  filter expr(standard == true)
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
input :body, {MyAppWeb.Inputs.Markdown, profile: :issue}
input :color, MyAppWeb.Inputs.Color
```

A renderer renders it with its own behaviour. For LiveView, the module also
implements `PyroManiac.LiveView.Input`.

## Sizes

`size` is the **content role** of an input, not a width:

| `size`    | Content                                    |
| --------- | ------------------------------------------ |
| `:code`   | Short identifiers: ZIP code, state, unit   |
| `:term`   | One short value: date, phone, amount       |
| `:name`   | Names, emails, titles                      |
| `:phrase` | Long text of one line: street, subject     |
| `:prose`  | Block content: textarea, notes (full row)  |

`:auto` (the default) is resolved at compile time: textarea, attachment,
and checkbox groups are `:prose`; date, time, number, boolean, toggle,
checkbox, and interval are `:term`; a text input with an Ash `max_length`
≤ 10 is `:code`, ≤ 24 is `:term`, ≥ 100 is `:phrase`; `select` and
`combobox` are `:name`; `input` uses `default_size/0`; others are `:name`.

## Layout entities

### `group`

A labeled set of inputs. Recursive. With `path`, the inputs are in the
nested form of that relationship.

```elixir
group "Phones" do
  path [:phones]
  density :dense
  field :label
  field :number
end

group "Legacy" do
  collapsible? true
  collapsed? true
  description "Imported data. Edit only to correct an import error."
  field :lead_time
end
```

| Key            | Default    | Notes                                                    |
| -------------- | ---------- | -------------------------------------------------------- |
| `label`        | last path  | Positional. The group heading                            |
| `description`  | nil        | Text below the label                                     |
| `path`         | `[]`       | Path prefix (appended to outer paths)                    |
| `density`      | `:normal`  | `:dense` uses narrower tracks (lists of short inputs)    |
| `max_columns`  | nil        | The maximum number of columns                            |
| `collapsible?` | `false`    | The user can close and open the group                    |
| `collapsed?`   | `false`    | Starts closed. Requires `collapsible? true`              |
| `visible?`     | nil        | Conditional visibility                                   |

A closed group keeps its inputs in the form, so they submit. An input with
`autofocus` cannot be in a closed group.

### `row`

**Layout only**: keep the children on one line when there is space, and
wrap them as a unit. It has 2 children or more, and no `:prose` input.

```elixir
row do
  field :city
  field :state, size: :code
  field :zip, size: :code
end
```

### `compound`

**Meaning**: one value made of tiny inputs, for example a value and its
unit. The label is the legend. The labels of the parts are for assistive
technology only, unless `show_labels? true`. The errors of the parts show
in one list. It has 2 parts or more, and no `:phrase` or `:prose` part.

```elixir
compound "Temperature" do
  field :temperature, label: "Value"
  select :temperature_unit, label: "Unit"
end
```

`row` and `compound` are orthogonal: a row can contain compounds.

### `step` (wizard forms)

A `step` is a single page of a multi-step wizard.

```elixir
action :onboard do
  step :basics do
    field :name
    field :email
  end

  step :preferences do
    select :timezone
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
| `render`      | nil       | A render module of the renderer (for LiveView, `PyroManiac.LiveView.Render`) |
| `review?`     | `false`   | Auto-generate a read-only summary of previous steps                      |
| `density`     | `:normal` | `:dense` uses narrower tracks                                            |
| `max_columns` | nil       | The maximum number of columns                                            |
| `visible?`    | nil       | Conditional visibility                                                   |

## `visible?`

`visible?` is an **Ash expression**, not a function. The server evaluates
it in memory with the current values of the form, so it can refer only to
the attributes and arguments at the level of the entity (no relationship
paths, aggregates, or calculations), `^arg(:name)`, `^actor(...)`, and
`parent(field)`: an attribute of the form one level up, as in Ash. The refs
are validated at compile time.

The level of an input, a row, a compound, or a step is its full path. A
group with a `path` shows or hides all its rows, so its level is the level
that contains it.

```elixir
field :standard_due, visible?: expr(standard == true)

group "Shipping" do
  visible? expr(ship? == true)
  field :carrier
end

group "Lines" do
  path [:lines]
  field :pallet_count, visible?: expr(parent(carrier) == :truck)
end
```

The option is not called `when`: Elixir parses a line that starts with
`when` as the guard operator of the line before it.

## `set` (cross-resource forms)

When an `action` declares an explicit `resource`, the form runs against a
different resource than the page's. `set` declares how to populate target
fields from the parent record:

```elixir
action :create do
  resource MyApp.Brewery.Batch

  set :recipe_id, :id

  field :batch_number
  field :brew_date
end
```

| Key      | Notes                                                     |
| -------- | --------------------------------------------------------- |
| `name`   | Target field (argument or attribute) on the form resource |
| `source` | Field on the parent record                                |

`set` is only valid inside `action` (not `bulk_action`).

## Common mistakes

- `field` on a foreign key or on an enum/`one_of` attribute. Use `combobox`
  or `select`.
- `type: :combobox`, `type: :select`, or `type: :markdown` on a `field`.
  These are entities (`combobox`, `select`) or an `input` type module.
- A `class`, `input_class`, or `render_fn` option. They are removed: use
  `size`, `density`, a layout entity, or a render module.
- A `visible?` function (`fn form -> ... end`). Use `visible? expr(...)`.
- A read action on the resource only for a combobox (`read :autocomplete`).
  Declare `filter`, `sort`, and `search` in the combobox.
- `^search()` in an `argument`. Use `argument :name, search()` (no pin), as
  in `set_attribute(:status, arg(:status))` of Ash: the value is not in an
  `expr/1`. In `filter`, which is an expression, use `^search()`.
- Mixing `delegate_to` with inline items. They're mutually exclusive.
- Using `set` inside `bulk_action` (not supported).
