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

## Section schema

| Key                | Default | Notes                                              |
| ------------------ | ------- | -------------------------------------------------- |
| `class`            | nil     | Default CSS class for forms                        |
| `description`      | nil     | Default description (inheritable)                  |
| `exclude`          | `[]`    | Action names to exclude                            |
| `extra_form_types` | `[]`    | Additional `field type:` atoms beyond the defaults |

## `action` — single-record forms

`action :name do ... end` configures a form for a create/update/destroy
action. `name` may be a single atom or a list (`action [:create, :update]`)
to share configuration across actions.

```elixir
action :create do
  label "New Recipe"
  description "Draft a new recipe."

  field_group "Basics" do
    field :name
    field :style
  end

  field :description do
    type :long_text
  end
end
```

| Key           | Notes                                                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `name`        | Required. Action name(s). `wrap_list` — accepts atom or `[atom]`                                                                |
| `label`       | Display label (defaults to capitalized name)                                                                                    |
| `description` | Form description (defaults to action's `description`)                                                                           |
| `class`       | CSS classes                                                                                                                     |
| `resource`    | Target a different resource (cross-resource action — use with `set`)                                                            |
| `delegate_to` | Resolve fields from a matching action in another PyroManiac module. Mutually exclusive with inline `field`/`field_group`/`step` |

Nested entities: `field`, `field_group`, `step`, `set`.

## `bulk_action` — multi-record forms

`bulk_action :name do ... end` configures a button that runs an update or
destroy action against the selected rows.

```elixir
bulk_action :archive do
  label "Archive Selected"
end

bulk_action :reassign do
  set_all_fields? true

  field :assignee_id
  field :reason
end
```

| Key               | Default   | Notes                                                                                                  |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------ |
| `name`            | required  | Action name(s) (`wrap_list`)                                                                           |
| `label`           | humanized | Button label                                                                                           |
| `description`     | action's  | Description text                                                                                       |
| `class`           | nil       | CSS classes for the button                                                                             |
| `set_all_fields?` | `false`   | When `true`, all fields submit (even nil); when `false`, empty fields are stripped for partial updates |
| `delegate_to`     | nil       | Defer to another PyroManiac module's matching bulk_action                                              |

Nested entities: `field`, `field_group`, `step`. (No `set` — bulk actions
operate on selected rows, not a parent record.)

## `field`

```elixir
field :name
field :description do
  type :long_text
  description "Markdown supported."
end
field :status do
  options [draft: "Draft", active: "Active", retired: "Retired"]
end
```

Selected schema (see `PyroManiac.Form.Field` for the full set):

| Key                   | Default           | Notes                                                                                              |
| --------------------- | ----------------- | -------------------------------------------------------------------------------------------------- |
| `name`                | required          | Field name (attribute or argument)                                                                 |
| `label`               | humanized         | Field label                                                                                        |
| `description`         | from Ash          | Override the action's description                                                                  |
| `type`                | `:default`        | Form input type. Extensible via `extra_form_types` on the section                                  |
| `options`             | `[]`              | Options for select-type inputs                                                                     |
| `prompt`              | nil               | Override the default prompt                                                                        |
| `class`/`input_class` | nil               | CSS hooks                                                                                          |
| `path`                | `[]`              | Append to the root path (nested forms via `inputs_for`)                                            |
| `autofocus`           | `false`           | Autofocus the input                                                                                |
| `form_only?`          | `false`           | When `true`, field is UI-only and not submitted                                                    |
| `when`                | nil               | 1-arity predicate `fn form -> boolean end` for conditional visibility                              |
| `autocomplete_*`      | sensible defaults | `option_label_key` (`:label`), `option_value_key` (`:id`), `search_action` (`:read`), `search_arg` |
| `allow_nil?`          | `true`            | Auto-populated by the transformer from the Ash attribute                                           |
| `enum_options`        | `[]`              | Auto-populated for Ash enums and `one_of` constraints                                              |

## `field_group`

Groups fields under a labeled heading. Recursive — groups can contain
fields and nested groups.

```elixir
field_group "Targets" do
  field :target_abv
  field :target_og
  field :target_fg
end
```

| Key     | Default                   | Notes                                      |
| ------- | ------------------------- | ------------------------------------------ |
| `label` | required (positional arg) | Group heading                              |
| `class` | nil                       | CSS classes                                |
| `path`  | `[]`                      | Path prefix (appended to outer paths)      |
| `when`  | nil                       | Conditional visibility predicate (1-arity) |

## `step` (wizard forms)

A `step` is a single page of a multi-step wizard. Steps can contain
fields and field_groups.

```elixir
action :onboard do
  step :basics do
    field :name
    field :email
  end

  step :preferences do
    field :timezone
  end

  step :review do
    review? true
  end
end
```

| Key         | Default   | Notes                                                          |
| ----------- | --------- | -------------------------------------------------------------- |
| `name`      | required  | Step identifier                                                |
| `label`     | humanized | Step heading                                                   |
| `class`     | nil       | CSS classes                                                    |
| `path`      | `[]`      | Base path; renderer wraps fields in `inputs_for` for this path |
| `render_fn` | nil       | Override the step's render entirely                            |
| `review?`   | `false`   | Auto-generate a read-only summary of previous steps            |
| `when`      | nil       | Conditional visibility predicate                               |

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

- Putting `type` as an inline keyword on a field with a `do` block:
  `field :description, type: :long_text do ... end` fails. Use
  `field :description do; type :long_text; end`.
- Mixing `delegate_to` with inline fields/groups/steps. They're mutually
  exclusive — pick one.
- Using `set` inside `bulk_action` (not supported).
- Forgetting `extra_form_types` on the section when introducing a custom
  field `type:`. Unknown types raise during compilation.
