defmodule PyroManiac.Dsl do
  @moduledoc false

  use Spark.Dsl.Extension,
    sections: [
      %Spark.Dsl.Section{
        describe: """
        The page: its route, title, and filters. A module with this section is a page
        (`PyroManiac.Info.page?/1`). A module without it is not a page: it declares
        views and searches that the pages of the application reuse, and it has no route.
        """,
        entities: [
          PyroManiac.Page.ExtraAction.__entity__(),
          PyroManiac.Description.__entity__()
        ],
        name: :page,
        imports: [Ash.Expr],
        schema: [
          title: [
            type: :string,
            doc:
              "Page title used for the document title and rendered as a page header. Defaults to the plural name of the resource."
          ],
          route: [
            type: :string,
            required: true,
            doc:
              ~s{The URL path of the page (e.g. `"/recipes"`). It starts with `/`. } <>
                "A renderer uses it for the route declarations. A navigation item or a " <>
                "command with `page` opens this route; the navigation does not set it."
          ],
          width: [
            type: PyroManiac.Dsl.Type.width(),
            default: :full,
            doc:
              "The width of the views of the page (an intent, `PyroManiac.Dsl.Type.width/0`): `:full` (the whole content area), `:record`, `:form`, or `:prose`. A view can set its own `width`."
          ],
          track_presence?: [
            type: :boolean,
            default: false,
            doc:
              "When true, tracks the users who view this page (a presence of the page) and the users who edit its records (a presence of the resource and the action, shared by every page of the resource)."
          ],
          custom_filters?: [
            type: :boolean,
            default: false,
            doc:
              "The user builds filters on the filterable fields of each list view (the advanced filter view), in addition to the `search` presets."
          ],
          filter_storage: [
            type: :atom,
            doc:
              "Where the filters that a user builds are saved: `:client` (in the client, for example the local storage of a browser), or a resource with the `PyroManiac.FilterPresets` extension. Requires `custom_filters? true`. `nil`: not saved."
          ],
          delete_preset_confirm: [
            type: {:or, [:string, {:literal, false}]},
            doc:
              "The confirmation of the delete of a saved filter: a message, or `false` (no confirmation). Required with `filter_storage`: a renderer never adds a confirmation."
          ],
          shared_filters?: [
            type: :boolean,
            default: false,
            doc:
              "A user can share a saved filter with other users. Requires a resource in `filter_storage`; its policies control who reads and writes each preset."
          ],
          exclude: [
            type: {:list, :atom},
            default: [],
            doc:
              "The actions of the resource that the page does not use. Each exposed action (read, create, update, destroy, generic) is used by a view, or is here."
          ]
        ]
      },
      %Spark.Dsl.Section{
        describe:
          "The views of the page: the records of a read action, and the actions that they run.",
        entities: [
          PyroManiac.View.View.__entity__()
        ],
        name: :views,
        top_level?: true
      },
      %Spark.Dsl.Section{
        describe: "Configure simple search forms for the tabbed filter UI.",
        entities: [
          PyroManiac.Search.Search.__entity__()
        ],
        name: :searches,
        top_level?: true
      }
    ],
    transformers: [
      __MODULE__.Transformers.ResolveViewResources,
      __MODULE__.Transformers.ExpandViewArguments,
      __MODULE__.Transformers.ValidateViews,
      __MODULE__.Transformers.LiftViewActions,
      __MODULE__.Transformers.ExpandFormActions,
      __MODULE__.Transformers.ValidatePage,
      __MODULE__.Transformers.ValidateCard,
      __MODULE__.Transformers.ValidateRenders,
      __MODULE__.Transformers.ValidateSurface,
      __MODULE__.Transformers.ValidatePrimaryViews
    ],
    verifiers: [
      __MODULE__.Verifiers.ResourceHasExtension,
      __MODULE__.Verifiers.VerifyLinks,
      __MODULE__.Verifiers.VerifyFilterStorage
    ],
    persisters: [
      __MODULE__.Persisters.Views
    ]
end
