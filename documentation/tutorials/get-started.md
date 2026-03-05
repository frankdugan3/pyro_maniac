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
need a renderer library — for Phoenix LiveView apps, add
[`pyro_maniac_live_view`](https://github.com/frankdugan3/pyro_maniac_live_view)
and follow its installation guide.

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
`PyroManiac.Resource` extension and declare a `default_label`:

```elixir
defmodule MyApp.Brewery.Recipe do
  use Ash.Resource,
    domain: MyApp.Brewery,
    extensions: [PyroManiac.Resource]

  pyro_maniac do
    default_label :name
  end

  # ... attributes, actions, etc.
end
```

The `default_label` is the field renderers use as the human-readable name
for a record (in dropdowns, breadcrumbs, etc.). It can be any attribute,
calculation, or aggregate.

## 4. Define a page module

A page module binds an Ash resource and configures the UI:

```elixir
defmodule MyAppWeb.RecipeLive do
  use PyroManiac, resource: MyApp.Brewery.Recipe

  page do
    title "Recipes"
  end

  views do
    view :read do
      type :data_table
      default_sort "name"
      column :name
      column :style
      column :status
    end
  end
end
```

The `view :read do ... end` block declares a `data_table` view backed by
the resource's `:read` action. Each `column :name` references an
attribute, calculation, or aggregate on the resource.

## 5. (Optional) Define navigation

If your app needs a sidebar or top-nav, declare it once with
`PyroManiac.Navigation`:

```elixir
defmodule MyAppWeb.Navigation do
  use PyroManiac.Navigation

  nav do
    item :home do
      path "/"
      module MyAppWeb.HomeLive
    end

    group :brewery do
      label "Brewery"
      icon :beer

      item :recipes do
        path "/recipes"
        page MyAppWeb.RecipeLive
      end
    end
  end
end
```

The compiled module exposes the navigation tree and a route manifest via
`PyroManiac.Navigation.Info`.

## 6. Wire up the renderer

PyroManiac stops here — the page module is data. Install your renderer
library and follow its instructions to mount the page at a route, render
the navigation, and connect the runtime (PubSub, presence, scope).
