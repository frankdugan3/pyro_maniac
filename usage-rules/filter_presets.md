# FilterPresets extension

`PyroManiac.FilterPresets` is an Ash resource extension that stores the
filter presets of the users. A page with `custom_filters? true` and
`filter_storage MyApp.FilterPreset` saves the filters that a user builds
as records of this resource (refer to [page](page.md)).

## Adding the extension

```elixir
defmodule Brewery.FilterPreset do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.FilterPresets],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "filter_presets"
    repo Brewery.Repo
  end

  filter_presets do
    owner Brewery.Staff
  end

  policies do
    # who reads and writes the presets: for example the owner, and every
    # user for a shared preset
  end
end
```

| Key     | Notes                                                                       |
| ------- | --------------------------------------------------------------------------- |
| `owner` | The resource of the users (an actor). Adds `belongs_to :owner`, set to the actor on create |

## What the extension adds

Unless the resource already has them:

- The attributes `id`, `name`, `page` (the page key), `view` (the view
  key, or `nil` for each list view of the page), `filter` (the filter
  input of the view, a map), `sort` (the sort input), `search` (the name
  of a `search` of the page), `inputs` (the values of the fields of the
  search, a map), `interactive?` (the user changes the values of the
  inputs when the preset is applied; else it is static), `shared?` (other
  users see it), and the timestamps.
- With `owner`, a `belongs_to :owner`, related to the actor on create.
- The actions `read` (primary), `create`, `update`, `destroy`, and
  `for_page` (the presets of a page, with the argument `page`).

The policies of the resource control who reads and writes the presets, so
sharing a preset (`shared_filters? true` on the page) is a normal
authorization of its records. `PyroManiac.FilterPresets.storage?/1` tells
whether a resource has the extension.

## One encoding

`PyroManiac.ListState` is the state of a list (filter, sort, search,
inputs, page) and its one encoding for every renderer: the URL params
(`encode/1`, `decode/1`), the preset attributes (`to_preset/1`,
`from_preset/1`), the keys (`page_key/1`, `view_key/1`, `storage_key/2`
for `filter_storage :client`), and the query (`query/3`, `validate/4`,
`page_opts/2`). Do not encode a filter or a preset in another way.

```elixir
state = PyroManiac.ListState.decode(params)

Brewery.Batch
|> Ash.Query.for_read(:read, %{}, actor: actor)
|> PyroManiac.ListState.query(state, page: BreweryWeb.BatchLive)
|> Ash.read(actor: actor, page: PyroManiac.ListState.page_opts(state, 25))
```

## Presets and searches

The `search` entities of a page remain: they are the presets of the page
(refer to [searches](searches.md)). Every list view has the same filter
experience: the searches as simple chips, and with `custom_filters? true`
the advanced filter view, whose filters the storage saves.

## Common mistakes

- A `filter_storage` resource without this extension. A verifier warns.
- `shared_filters? true` with `filter_storage :client`. Sharing needs a
  resource.
- A storage resource without `Ash.Policy.Authorizer`: every user reads and
  writes every preset.
