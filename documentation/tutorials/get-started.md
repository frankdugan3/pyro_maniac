# Get Started

This guide walks through installing PyroManiac and configuring a minimal
page module backed by an Ash resource. It assumes you already have an
Ash project (~> 3.20) with at least one resource.

## 1. Add the dependency

```elixir
def deps do
  [
    {:pyro_maniac, "~> 0.1"},
    {:ash, "~> 3.20"}
  ]
end
```

PyroManiac is the DSL layer only. To actually render anything you also
need a renderer library. Add the renderer for your stack and follow its
installation guide.

## 2. Configure the formatter

In `.formatter.exs`:

```elixir
[
  import_deps: [:pyro_maniac, :ash],
  plugins: [Spark.Formatter]
]
```

## 3. Add the `PyroManiac.Resource` extension to each resource

Every resource that backs a PyroManiac page must use the
`PyroManiac.Resource` extension, declare a `default_label`, and expose the
actions and fields that its pages use:

```elixir
defmodule Brewery.Recipe do
  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource]

  pyro_maniac do
    default_label :name

    realtime do
      mode :auto
    end

    expose :read do
      loads [:name, :style, :status, :description, :target_abv, :target_og, :target_fg]
      filter [:name, :style, :status]
      sort [:name, :style, :status]
    end

    expose [:create, :update]
  end

  # ... attributes, actions, etc.
end
```

The `default_label` is the field renderers use as the human-readable name
for a record (in dropdowns, breadcrumbs, etc.). It can be any attribute,
calculation, or aggregate.

The `expose` entities are the **surface** of the resource. A page that uses
an action or a field that is not exposed does not compile. Refer to
[The surface](surface.md).

## 4. Define a page module

A page module binds an Ash resource and configures the UI:

```elixir
defmodule BreweryWeb.RecipeLive do
  use PyroManiac, resource: Brewery.Recipe

  page do
    title "Recipes"
    route "/recipes"
  end

  view :read do
    type :data_table
    primary? true
    default_sort "name"
    exclude [:description, :target_abv, :target_og, :target_fg]
    column :name
    column :style
    column :status

    action :create, :guard do
      delegate_to BreweryWeb.RecipeLive
    end
  end

  view :read do
    type :card
    primary? true
    action [:create, :update], :guard

    section :recipe do
      field :name, autofocus: true
      select :style
      select :status
      field :description, type: :textarea
    end

    section :targets do
      field :target_abv
      field :target_og
      field :target_fg
    end
  end
end
```

The `page` section makes the module a page, and `route` (required) is its
URL path; the renderer routes it. A module without the `page` section is
not a page: it has no route, and it declares views and searches that the
pages reuse.

`view` is a top-level entity. The first `view :read do ... end` block
declares a `data_table` view backed by the resource's `:read` action: the
primary list view. Each `column :name` references an attribute,
calculation, or aggregate on the resource, and `exclude` lists the other
exposed fields of the read action.

Each page needs a primary single view: a `:card` with `primary? true`. The
nodes of the card are its record tree: the card shows one recipe in view
mode. `action [:create, :update], :guard` makes that tree the form of
both actions: **Edit** switches the card to the update form in the same
place. The form of each action has each attribute that the action accepts,
and one input with `autofocus`.

Each action declares its `state`, the fate of the unsaved inputs:
`:guard` warns before the user leaves with unsaved changes, `:recover`
restores the inputs after a reload or a lost connection, and `:discard`
does neither. It is required, with no default: the second argument, or
`state :guard` in the block of the action.

A view runs the actions that it names. In the table, `action :create`
with `delegate_to` this page is the **New** button: it opens the form of
the card. Each exposed action of the resource is used by a view, or is in
`page do exclude [...] end`. Refer to
[The record layout](record-layout.md).

## 5. (Optional) Define navigation

If your app needs a sidebar or top-nav, declare it once with
`PyroManiac.Navigation`:

```elixir
defmodule BreweryWeb.Navigation do
  use PyroManiac.Navigation

  nav do
    item :home do
      path "/"
      module BreweryWeb.HomeLive
    end

    group :brewery do
      label "Brewery"
      icon :beer

      item :recipes do
        page BreweryWeb.RecipeLive
      end
    end
  end
end
```

A `page` item opens the `route` of its page, so it has no `path`; a
`module` item has a `path`. Groups are not part of a route, and no two
routes overlap. The compiled module exposes the navigation tree and a
route manifest via `PyroManiac.Navigation.Info`. A `command_palette` section adds a palette
that finds the navigation items and your own `command` entities, opened
with `mod+k`:

```elixir
command_palette do
  command :new_recipe do
    label "New recipe"
    page BreweryWeb.RecipeLive
    path "/recipes?new"
  end
end
```

## 6. (Optional) Let the users build filters

The `search` entities of a page are preset filters. With
`custom_filters? true`, the user also builds filters on the filterable
fields of each list view. `filter_storage` saves them, in the client
(`:client`) or in a resource with the `PyroManiac.FilterPresets`
extension, and `shared_filters? true` lets a user share them:

```elixir
page do
  title "Recipes"
  route "/recipes"
  custom_filters? true
  filter_storage Brewery.FilterPreset
  shared_filters? true
end
```

## 7. Wire up the renderer

PyroManiac stops here — the page module is data. Install your renderer
library and follow its instructions to mount the page at its route, render
the navigation, and connect the runtime (PubSub, presence, scope).
