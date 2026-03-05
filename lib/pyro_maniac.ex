defmodule PyroManiac do
  @moduledoc """
  A declarative, framework-agnostic UI DSL for Ash resources.

  A page module binds an Ash resource and configures the `page`, `views`,
  `forms`, and `searches` sections that describe the UI. The DSL is consumed
  at runtime via `PyroManiac.Info` by a renderer (e.g. `pyro_maniac_live_view`).

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

  [DSL documentation](dsl-pyromaniac.html)
  """
  use Spark.Dsl,
    opt_schema: [
      resource: [
        type: {:spark, Ash.Resource},
        doc: "The Ash resource",
        required: true
      ]
    ],
    default_extensions: [extensions: [PyroManiac.Dsl]]

  @type t :: module

  @impl Spark.Dsl
  def init(opts) do
    resource = opts[:resource]

    if Ash.Resource.Info.resource?(resource) do
      {:ok, opts}
    else
      {:error, "#{resource} is not a valid Ash resource."}
    end
  end

  @impl Spark.Dsl
  def handle_opts(opts) do
    quote bind_quoted: [
            resource: opts[:resource]
          ] do
      @persist {:resource, resource}
    end
  end
end
