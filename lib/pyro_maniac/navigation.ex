defmodule PyroManiac.Navigation do
  @moduledoc """
  Declarative navigation structure for PyroManiac applications.

  Define your app's navigation in a single module:

      defmodule MyAppWeb.Navigation do
        use PyroManiac.Navigation

        nav do
          item :home do
            path "/"
            module MyAppWeb.DashboardLive
            image "/images/logo.svg"
            image_alt "Acme Co"
          end

          group :brewery do
            label "Brewery"
            icon :beer

            item :recipes do
              path "/recipes"
              page MyAppWeb.RecipeLive
            end

            item :batches do
              path "/batches"
              page MyAppWeb.BatchLive
            end
          end

          item :docs do
            href "https://docs.example.com"
            label "Docs"
            icon :book
          end
        end
      end

  The compiled module exposes a nav tree and a route manifest via
  `PyroManiac.Navigation.Info`. Routing and layout rendering are the
  responsibility of the chosen renderer (e.g. `pyro_maniac_live_view`).
  """
  use Spark.Dsl,
    default_extensions: [extensions: [PyroManiac.Navigation.Dsl]]

  @type t :: module
end
