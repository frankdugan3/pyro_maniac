defmodule PyroManiac do
  @moduledoc """
  A declarative, framework-agnostic UI DSL for Ash resources.

  A module binds an Ash resource and declares its views (`view`, top level)
  and its searches (`search`, top level). A view shows the records of a read
  action and runs the actions that it names (`action`, `bulk_action`). With
  the `page` section, the module is a page, with a `route`
  (`PyroManiac.Info.page?/1`); without it, the module declares views and
  searches that the pages reuse. A renderer reads the result at runtime with
  `PyroManiac.Info`.

      defmodule BreweryWeb.RecipeLive do
        use PyroManiac, resource: Brewery.Recipe

        page do
          route "/recipes"
          title "Recipes"
          description "Recipes in production, in draft, and retired."
          exclude [:list, :activate, :retire, :destroy]
        end

        view :read do
          type :data_table
          primary? true
          default_sort "name"

          exclude [:id, :description, :target_abv, :target_og, :target_fg, :gravity_spread,
                   :ingredient_count, :batch_count, :recipe_ingredients, :batches, :photos,
                   :photos_urls]

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
