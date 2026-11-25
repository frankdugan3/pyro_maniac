defmodule PyroManiac.Navigation do
  @moduledoc """
  Declarative navigation structure for PyroManiac applications.

  Define your app's navigation in a single module:

      defmodule BreweryWeb.Navigation do
        use PyroManiac.Navigation

        nav do
          item :home do
            path "/"
            module BreweryWeb.HomeLive
            image "/images/logo.svg"
            image_alt "Acme Brewery"
          end

          group :brewery do
            label "Brewery"
            icon :beer

            item :recipes do
              page BreweryWeb.RecipeLive
            end

            item :batches do
              page BreweryWeb.BatchLive
            end
          end

          item :docs do
            href "https://docs.example.com"
            label "Docs"
            icon :book
          end
        end
      end

  A `page` item opens the `route` of its page (`page do route "/recipes"
  end`), so the route is in the page, not in the navigation. A `module`
  item has a `path`, and an `href` item opens a URL. Groups are not part of
  a route. No two routes match the same URL (`"/recipes/:id"` and
  `"/recipes/new"` overlap), and a `page` item opens a route without
  parameters.

  Items and groups have a `decoration` (the meaning of the item; each
  renderer maps it to a style). The `command_palette` section adds a
  palette, opened with a hotkey (default `"mod+k"`), that finds the items
  of the navigation (`navigation? true`) and the `command` entities (refer
  to `PyroManiac.Navigation.Command`).

  The compiled module exposes a nav tree, a route manifest, and the command
  palette via `PyroManiac.Navigation.Info`. Routing and layout rendering
  are the responsibility of the chosen renderer.
  """
  use Spark.Dsl,
    default_extensions: [extensions: [PyroManiac.Navigation.Dsl]]

  @type t :: module
end
