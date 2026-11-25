# Filters And Sorts

The contract of the filters, the sorts, the searches, and the presets of
every list view. For the design expectations (what the user sees, and the
DSL), refer to [Filters and sorts](../tutorials/pages.md#filters-and-sorts)
and [Searches](../tutorials/pages.md#searches) in the tutorial Pages.

Each list view has the same filter and sort experience: a `:data_table`,
a `:grid`, a `:list`, a `:kanban`, a `:calendar`, a `:gantt`, a
`:timeline`, and a `:card` that is the list view. The same filter bar, the
same chips, the same presets, the same URL state, and the same rules, so a
user who filters one list can filter each one. Only the place of the sort
control differs (the headers of a table; a sort menu for the others). A
`:render` view gets the same state, and SHOULD show the same filter bar.
A `related` with `delegate_to` shows the list view of the other page with
its filter bar, scoped to the record.

## The page options

| DSL | The UI | Function |
|---|---|---|
| (always) | The **simple mode**: the chips of the active filter, the quick chips of the searches, the filter of each filterable field, and the sort. | `PyroManiac.Info.searches/1` |
| `custom_filters? true` | The **advanced view** in addition: a filter builder, with groups. Without it, no builder. | `PyroManiac.Info.custom_filters?/1` |
| `filter_storage :client` | **Save** in the advanced view: the presets of the user, in the browser only. | `PyroManiac.Info.filter_storage/1` |
| `filter_storage MyApp.FilterPreset` | **Save**: the presets are records of a resource with `PyroManiac.FilterPresets`. | `PyroManiac.Info.filter_storage/1`, `PyroManiac.FilterPresets.storage?/1` |
| `shared_filters? true` | **Share** on a saved preset; the presets that other users share. | `PyroManiac.Info.shared_filters?/1` |

`filter_storage` requires `custom_filters? true`, and `shared_filters?`
requires a resource in `filter_storage` (compile errors otherwise).

## The state of a list

The state of a list view is its **filter**, its **sort**, its **search**
(a `search` of the page and the values of its fields), its **page**, and
its page size: a `PyroManiac.ListState`. Everything else (the presets,
the chips, the builder) reads and writes this state.

The encoding is PyroManiac's, not the renderer's: every renderer MUST
encode, decode, and apply the state with `PyroManiac.ListState`, so a URL,
a preset, and a stored filter mean the same list in each renderer. The
renderer implements the UI that changes the state.

- **Filter**: an Ash filter input, in the map form: field keys with
  operator maps, relationship keys with nested maps, and `and`, `or`,
  `not`. It is the form of `Ash.Query.filter_input/2`, of the `filter` of a
  preset, of a list link (`PyroManiac.Link.list_filter/3`), and of
  `PyroManiac.FilterChips`.

  ```elixir
  %{
    "and" => [
      %{"status" => %{"in" => ["fermenting", "conditioning"]}},
      %{"recipe" => %{"style" => %{"eq" => "ipa"}}},
      %{"or" => [
        %{"brew_date" => %{"greater_than_or_equal" => "2026-11-01"}},
        %{"notes" => %{"contains" => "dry hop"}}
      ]}
    ]
  }
  ```

- **Sort**: an Ash sort input string ([Sorts](#sorts)), for example
  `"-brew_date,batch_number"`.
- **Search**: the name of a `search` of the page, and the values of its
  fields (string keys). `PyroManiac.ListState.search_filter/3` gives its
  filter; `PyroManiac.ListState.filter/3` joins it to the filter (and).
- **Page**: the page number (offset), or the keyset (`after`, `before`),
  and the page size.

**The URL.** The state of each list view MUST be in the query params of
the URL, so a link, a reload, Back, and Forward give the same list.
`PyroManiac.ListState.encode/1` gives the params and
`PyroManiac.ListState.decode/1` reads them:

| Param | Value | Example |
|---|---|---|
| `f` | The filter, JSON | `{"status":{"eq":"active"}}` |
| `s` | The sort | `-brew_date,batch_number` |
| `q` | The search | `by_number` |
| `qi` | The values of the fields of the search, JSON | `{"batch_number":"B-12"}` |
| `p` | The page number | `2` |
| `af` / `bf` | The keyset after / before the page | a keyset |
| `ps` | The page size | `25` |

The params of one list are flat. A renderer with more than one list in a
URL (a nested list, a `related` list) puts the params of each list under
its own key, for example `v[f]` for the root list and
`v[<path>:<id>][f]` for a nested one; the key scheme is the renderer's,
the params under it are not. A state equal to the default (no filter,
the `default_sort`, page 1) is not in the URL. A change of the filter or
the sort SHOULD replace the history entry while the user types
(debounced), and push one when it is applied.

**Pages.** A change of the filter, the sort, the search, or the page size
MUST reset the list to its first page (offset page 1, no keyset), so the
user never sees an empty page after a narrower filter:
`PyroManiac.ListState.put/3` does it. The count ("1–25 of 112") is for the
filtered records.

**Loading.** The renderer runs the read action of the view with the
state, for the actor:

1. `PyroManiac.ListState.decode/1`. A param that is not valid (bad JSON,
   not a positive integer) is left out: its default.
2. `PyroManiac.ListState.query/3` with the `page` option: the filter of
   the search joins the filter, and `PyroManiac.Surface.restrict_filter/3`
   and `PyroManiac.Surface.restrict_sort_input/3` drop each predicate and
   each sort key that the exposed `filter` and `sort` of the read action
   (`expose` of the resource) do not cover. A URL cannot filter or sort on
   a field that the page does not offer.
3. `PyroManiac.ListState.query/3` gives them to `Ash.Query.filter_input/2`
   and `Ash.Query.sort_input/2`: Ash validates the input. A field that is
   not public, an operator that the type has not, or a value that does not
   cast is an error. `PyroManiac.ListState.validate/4` gives the errors of
   the filter and the sort before the read, for the inline errors.
   `PyroManiac.ListState.page_opts/2` gives the `page` option of the read.
   The renderer MUST NOT build a filter from user input in another way
   (string interpolation, `expr` with the raw value).
4. The read action runs with the actor: its own filter, preparations,
   policies, and field policies apply as always. The filter of the user is
   added to them (and), never in place of them.

**Errors.** An error of the filter shows inline, at the input or the chip
of the predicate that has it (`aria-invalid`, the message with
`aria-describedby`), and in the builder at its row. The list keeps its
last valid result until the filter is valid again; an invalid filter from
a URL shows the error and the unfiltered list. An error MUST NOT clear the
inputs of the user.

## The fields and the operators

The fields that the user can filter on are the fields that the exposed
`filter` of the read action covers: `PyroManiac.Resource.Info.exposed/2`
gives the expose entity, with `:*` expanded to the public attributes,
calculations, and aggregates of the resource without `filterable?
false` (`PyroManiac.Resource.Info.public_fields(resource, :filter)`);
`PyroManiac.Surface.paths/1` gives its paths.

- A relationship in the exposed `filter` (`filter [:*, :recipe]`) gives
  the fields of the destination, one level, with their path
  (`recipe.style`, the label "Recipe › Style"). A relationship to one
  record also gives a filter on the record itself: a combobox of the
  destination, which filters by the foreign key (`recipe_id`), and whose
  chip shows the label of the record.
- In a `:data_table`, a column with `filterable? false` is not offered
  (the transformer turns it off for a field that cannot filter). The other
  list types offer the fields of their `field` entities and of the exposed
  filter.
- A calculation with a required argument is not offered. A private field
  is never offered.
- Field policies still apply: a predicate on a field that the actor
  cannot read gives what Ash gives (no match, or an error that the
  renderer shows). The renderer SHOULD NOT offer a field that the actor
  cannot read when it knows it.

The operators depend on the type of the field. They are the predicates of
an Ash filter input:

| The type | The operators | The value input |
|---|---|---|
| `:string`, `:ci_string` | `contains`, `eq`, `not_eq`, `in`, `is_nil`; MAY add `string_starts_with`, `string_ends_with` | A text input; `in` takes several values (chips). |
| `:integer`, `:float`, `:decimal` | `eq`, `not_eq`, `less_than`, `greater_than`, `less_than_or_equal`, `greater_than_or_equal`, `is_nil`; a range is two predicates | A number input, with the constraints of the attribute (`min`, `max`). |
| `:date`, `:datetime`, `:utc_datetime`, ... | `eq`, `less_than` ("before"), `greater_than` ("after"), the `_or_equal` forms, `is_nil`; a range ("between") is two predicates | A date (or date-time) picker; relative values ("the last 7 days") SHOULD resolve to dates when applied. |
| `:boolean` | `eq`, `is_nil` | A tri-state control: yes, no, any. |
| an `Ash.Type.Enum` or `one_of` | `eq`, `not_eq`, `in`, `is_nil` | A select of the values (their labels), multi-select for `in` (`PyroManiac.Info.enum_options_for/2`). |
| a relationship to one record (the foreign key) | `eq`, `in`, `is_nil` | A combobox of the destination (its `default_label`), multi-select for `in`. |
| an array | `has` (the item is in it), `is_nil` | The input of the item type. |
| `:map`, `:struct`, a file, a type without equality | — | Not offered. |

`not` (for example "is not", "does not contain") is the `not` key around a
predicate (`%{"not" => %{"status" => %{"eq" => "retired"}}}`). Each
operator has a label in plain language ("contains", "is", "is not", "is
before", "is empty"); the raw names do not show. An operator that the data
layer cannot run gives an Ash error: show it as any error.

## Searches

A `search` is a predefined filter of the page
([Searches](../tutorials/pages.md#searches)): a **quick chip** of the
filter bar of each list view. `PyroManiac.Info.searches/1` gives the
searches of the page.

| DSL | The renderer |
|---|---|
| `search :name` | A quick chip (`label`, default: the humanized name). |
| `operator` (search) | How the predicates of the fields combine: `:and` or `:or`. |
| `interactive? false` | The inputs are disabled: the search applies at once, as stored. |
| `field :name` | An input (`label`). `value` fills it. |
| `source` | The fields that the value matches (joined with `or`). |
| `operator` (field), `negated?` | The predicate (`:contains`, `:eq`, ...) and `not`. |

- **The predicates.** Each `field` is one predicate on its `source` fields
  (joined with `or`), with its `operator` and `negated?`; the predicates
  join with the `operator` of the search. The renderer MUST NOT build them
  itself: `PyroManiac.ListState.search_filter/3` gives the filter of the
  active search from its name and its values, and
  `PyroManiac.ListState.filter/3` joins it to the filter of the list (and).
- **The state.** An active search is the `search` of the
  `PyroManiac.ListState` (the `q` param) and the values of its fields
  (`inputs`, string keys; the `qi` param). A change of the search or of
  its values resets the page ([The state of a list](#the-state-of-a-list)).
- **The form.** Selecting a quick chip opens the small form of the search
  (a popover, or a tab of the filter panel): its `field` inputs, filled
  with `value`. **Apply** makes it an active chip with its values. With
  `interactive? false`, the inputs are disabled and the search applies at
  once.
- **The chip.** An active search is one chip ([Simple mode:
  chips](#simple-mode-chips)): with `interactive? true`, its label and its
  values; with `interactive? false`, its label only (its values are fixed,
  and their raw form means nothing to the user). Removing it removes its
  predicates (it clears `search` and `inputs`). **Clear all** removes it.
- **A toggle.** The quick chip of an active search is pressed
  (`aria-pressed="true"`); selecting it again removes the search.
- **Presets.** A preset can name a search and its values
  ([Presets](#presets)).

## Simple mode: chips

Simple mode is the default for every list view, with or without
`custom_filters?`. Above the list:

- **One chip for each active filter**: each predicate of the top-level
  conjunction, and each active search (one chip, with its label and its
  values). A chip reads "Field operator value" ("Status is Fermenting",
  "Brew date after 2026-11-01"); a chip of a relationship shows the label
  of the record, as a link with the `link_to` of its column. An `or` or a
  `not` that is not a simple predicate is one group chip ("2 conditions"),
  which opens the advanced view (or shows its text without
  `custom_filters?`).
- **Edit a chip**: a click opens its value input (a popover) with the
  operators of the field; the change applies to the filter.
- **Remove a chip**: its × button ("Remove filter Status is
  Fermenting"); Backspace or Delete on a focused chip.
- **Add a filter**: **+ Filter** opens the list of the filterable fields
  (with a search), then the operator and the value of the field.
- **Clear all**: removes every chip and every search; the list goes back to
  its default state (the `default_sort` stays).
- **Quick chips**: each `search` of the page is a quick chip, not active
  until the user selects it. A search with `interactive? true` opens its
  small form (its `field` inputs); applied, it becomes an active chip with
  its values. A search with `interactive? false` applies at once, as
  stored (its inputs are disabled). Each search gives a fixed set of
  predicates: each `field` is one predicate on its `source` fields (joined
  with `or`) with its `operator` and `negated?`, and the predicates join
  with the `operator` of the search (`:and`, `:or`). An active search is
  one chip; removing it removes its predicates.
- **Presets**: the saved presets of the user, and the shared ones, are in
  a menu of the filter bar ([Presets](#presets)).

`PyroManiac.FilterChips` makes the chips from the filter:
`chips(view, resource, filter)` gives one `%Chip{}` for each predicate of
the top-level conjunction (with `path`, `operator`, `value`, `label`, and
the filter of the chip alone), and a `:group` chip for an `or`, a `not`, or
an unknown field; `load_labels/2` loads the labels of the records of
relationship chips (for the actor); `remove(chips, id)` gives the filter
without one chip.

## The advanced view

With `custom_filters? true`, the filter bar has **Advanced** (and a chip
of a group opens it). The advanced view is a filter builder of the same
filter:

- A **row** is one predicate: the field (a searchable select of the
  filterable fields, with the paths of the relationships), the operator
  (the operators of the type of the field), and the value (the input of
  the type). A change of the field resets the operator and the value to
  the defaults of the new type.
- A **group** joins its rows and groups with **All of** (`and`) or **Any
  of** (`or`), and can be negated (**None of**: a `not` around it). The
  top level is a group. **+ Condition** adds a row, **+ Group** a nested
  group; each row and group has a remove button. Groups nest at least
  three levels deep.
- The builder reads the current filter (the chips and the active
  searches), and writes the filter of the list on **Apply** (or live,
  debounced). **Cancel** keeps the filter as it was. A filter that the
  chips can show goes back to chips when the view closes.
- An error shows at its row ([The state of a list](#the-state-of-a-list)).
- **Save**, **Update**, **Delete**, and **Share** of the presets are in
  the advanced view when the page has a `filter_storage`.

Without `custom_filters?`, there is no builder: the user has the chips
of single predicates (on the filterable fields), the searches, and the
filter of a list link.

## Sorts

The sort of a list view is an **Ash sort input string**: the fields in
order, joined with `,`; a `-` prefix is descending; `++` is ascending with
`nil` first, `--` descending with `nil` last; a relationship field has its
path (`recipe.name`). For example `"-brew_date,batch_number"`.

- **The names.** The names of a filter and a sort are the names of the
  fields in Ash (`late?`, `recipe.name`), with a `.` between the parts of
  a path. A client whose tooling gives the fields other names (for
  example the camel case or the `field_names` of AshTypescript: `isLate`)
  MUST send the names of Ash in a filter and a sort input, and read the
  records by the client names.
- **A relationship.** The sort of a relationship (a column of a
  `belongs_to`) is the sort by the label of the related record, a path
  (`recipe.name`); a sort by the relationship itself is not valid.
- **The default.** The `default_sort` of the view (a string, or a sort
  list: `PyroManiac.Helpers.encode_sort/1` gives the string), else the
  sort of the read action (its preparations), else none. The rank of
  `PyroManiac.Ordering` is a valid key of `default_sort` without a column
  (the renderer does not show a column for it). A kanban sorts by its
  priority. The URL has the sort only when it is not the default.
- **The fields.** The sortable fields are the fields that the exposed
  `sort` of the read action covers (`PyroManiac.Resource.Info.public_fields(resource, :sort)`
  for `:*`, and the relationship paths); in a `:data_table`, a column
  with `sortable? true` (offset pages and no pages) or `keyset_sortable?
  true` (keyset pages). `PyroManiac.Surface.restrict_sort_input/3`
  removes the others; Ash validates the rest (`Ash.Query.sort_input/2`).
- **A table.** A click on a sortable header sorts by it alone, and cycles
  ascending, descending, off. Shift+click adds it to the sort (a
  multi-sort) or flips its direction, in place. Ctrl+click (Cmd on macOS)
  cycles where its `nil` values go. `PyroManiac.Helpers.toggle_sort_param/3`
  implements the three (`%{}`, `%{multiple?: true}`, `%{toggle_nil?:
  true}`) on the string. The header shows the direction (an arrow) and,
  in a multi-sort, the position (1, 2, ...); it has `aria-sort`
  (`ascending`, `descending`; on the first sort column only, as ARIA
  allows one), and the button reads "Sort by Brew date, descending".
- **The other list types.** A sort menu: the sortable fields, a direction
  toggle for each, and **+ Then by** for a multi-sort. A `:calendar`, a
  `:gantt`, and a `:timeline` sort by their dates; their menu MAY be
  hidden.
- A change of the sort resets the page ([The state of a list](#the-state-of-a-list)).
- **Reorder.** With `reorder? true`, the sort by the rank ascending alone
  (`"position"`) turns the drag handles on ([Actions](renderer-actions.md)); a sort
  menu SHOULD offer it as "Manual order".

## Presets

A **preset** is a saved filter and sort of a list view, with a name. The
searches of the page are presets too, fixed in the DSL; the presets of the
users exist with `custom_filters? true` and a `filter_storage`.

| Field | Meaning |
|---|---|
| `name` | The name in the menu. |
| `page` | The page key: `PyroManiac.ListState.page_key/1` (`"BreweryWeb.BatchLive"`). |
| `view` | The view key: `PyroManiac.ListState.view_key/1` (`"read:data_table"`), or `nil` for each list view of the page. |
| `filter` | The filter input of the list (a map). |
| `sort` | The sort input string, or `nil` (the default sort). |
| `search` | The name of a `search` of the page, or `nil`. |
| `inputs` | The values of the fields of the search (a map, the field names as keys). |
| `interactive?` | `true` (the default of the resource): applying the preset opens its inputs for editing first. `false`: static, applied as stored. |
| `shared?` | Other users see it ([Sharing](#sharing)). |

**Apply.** Selecting a preset replaces the filter and the sort of the
list with the preset's (the page resets to 1), and marks the preset as
active in the menu while the state is equal to it ("Fermenting IPAs", or
"Fermenting IPAs (changed)" after an edit). `PyroManiac.ListState.from_preset/1`
gives the state of a preset, and `PyroManiac.ListState.to_preset/1` the
attributes of a state (the page position is not saved). With
`interactive? true` and a `search`, the renderer first shows the fields of
the search, filled from `inputs`, and applies on **Apply**; with
`interactive? false`, or without a search, it applies the preset at once.

**Save.** **Save** asks for a name (and **Interactive**, and **Share**
with `shared_filters?`) and saves the current filter and sort. **Update**
saves the current state into the active preset; **Rename** and **Delete**
change it. **Delete** asks with `delete_preset_confirm` of the page (a
message), or runs at once (`false`); the renderer never adds a
confirmation. A preset that the user cannot change has
none of these.

### Client storage

**`filter_storage :client`.** The presets are in the browser (for example
`localStorage`), private to the browser: they are not on the server, not
shared, and not on another device. The renderer MUST store them under
`PyroManiac.ListState.storage_key/2` (the page and the view:
`pyro_maniac:filters:BreweryWeb.BatchLive:read:data_table`), as a JSON
list of presets: `to_preset/1` with a `name`, an `id`, and
`interactive?`, without `owner` and `shared?`. A value that does not
decode is ignored.

### FilterPresets storage

**A resource.** With `filter_storage MyApp.FilterPreset`, the presets are
records of a resource with the `PyroManiac.FilterPresets` extension. The
extension adds the attributes of the table, the timestamps, and with
`owner` a `belongs_to :owner`, set to the actor on create (`relate_actor`).
The renderer calls its actions, with the actor, and nothing else:

| Action | The renderer |
|---|---|
| `for_page` (argument `page`) | The menu: the presets of the page that the actor can read; then the presets of the view (`view` is the view or `nil`). |
| `create` | **Save**. The owner is the actor: the renderer does not set it. |
| `update` | **Update**, **Rename**, **Share**. |
| `destroy` | **Delete**. |

The tutorial has an example of a preset resource with its policies
([Presets](../tutorials/pages.md#presets)).

A preset applies only its filter and sort; the filter of a preset goes
through the same pipeline as a URL ([The state of a list](#the-state-of-a-list)),
so a preset with a field that is not offered any more loses that
predicate, and a preset cannot widen what the actor can read.

### Sharing

With `shared_filters? true`, a preset has **Share** (the `shared?`
attribute, through `update`), and the menu shows the shared presets of
other users in their own group ("Shared", with the name of the owner).
Who can share a preset, and who sees a shared one, is decided only by the
policies of the preset resource: the renderer calls the actions and hides
what the actor cannot do (`Ash.can?/3` for **Share**, **Update**, and
**Delete** of each preset). It MUST NOT filter the presets itself by
`shared?` or by the owner: `for_page` gives what the actor can read.

## Accessibility

- **Keyboard.** Every control of the filter bar, the chips, the builder,
  the presets, and the sort is reachable and usable with the keyboard, in
  reading order. Enter applies a value input; Escape closes a popover and
  returns the focus to its chip. After a chip is removed, the focus goes
  to the next chip, else to **+ Filter**.
- **Labels.** The filter bar is a `region` (or `search` landmark) with
  the label "Filters"; each chip is a button with its full text ("Status
  is Fermenting") and its remove button names it ("Remove filter Status is
  Fermenting"). Each input of the builder has a label (the field, the
  operator, the value of row 2), and each group its operator ("Any of the
  conditions below"). An active preset is `aria-pressed` or
  `aria-current`.
- **Results.** A polite live region (`aria-live="polite"`) announces the
  result count after each change of the filter or the sort ("41
  batches", "No batches match the filters"), and an error of the filter.
  It does not announce while the user types.
- **No results.** An empty result says that the filters cause it, with
  **Clear all**.
- The direction and the active state are not shown by color only.

## Checklist

- [ ] The same filter bar, chips, presets, and URL state for each list
  type (`:data_table`, `:grid`, `:list`, `:kanban`, `:calendar`, `:gantt`,
  `:timeline`, the `:card` that is the list view, and `:render`), and for
  `related` with `delegate_to`.
- [ ] The state in the URL with `PyroManiac.ListState` (`encode/1`,
  `decode/1`), the default state left out, and the history entries.
- [ ] The read with `PyroManiac.ListState.query/3` and `page_opts/2`: the
  surface restricts the filter and the sort, Ash validates them
  (`validate/4` for the inline errors), and the filter of the user joins
  the filter and the policies of the read action.
- [ ] The reset to the first page on each change of the filter, the sort,
  the search, and the page size.
- [ ] The fields of the exposed `filter` and `sort`, and the operators of
  each type, with plain labels.
- [ ] The chips (`PyroManiac.FilterChips`), the group chips, **+ Filter**,
  **Clear all**, and the searches as quick chips.
- [ ] The advanced view with `custom_filters?`: rows, nested groups,
  **Apply** and **Cancel**, the errors at their rows.
- [ ] The sort input string: the header clicks (with Shift and Ctrl/Cmd),
  the sort menu, `aria-sort`, and "Manual order" with `reorder?`.
- [ ] The presets of `filter_storage`: `:client` under
  `PyroManiac.ListState.storage_key/2`, or the actions of a
  `PyroManiac.FilterPresets` resource; sharing with `shared_filters?`,
  decided by the policies only.
- [ ] The keyboard, the labels, the live region of the result count, and
  the empty state with **Clear all**.
