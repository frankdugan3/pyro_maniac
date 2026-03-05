defmodule PyroManiac.Dsl do
  @moduledoc false

  use Spark.Dsl.Extension,
    sections: [
      %Spark.Dsl.Section{
        describe: "Page-level configuration for the PyroManiac UI.",
        entities: [
          PyroManiac.Page.TenantFrom.__entity__(),
          PyroManiac.Page.ExtraAction.__entity__()
        ],
        name: :page,
        schema: [
          title: [
            type: :string,
            required: true,
            doc: "Page title used for the document title and rendered as a page header."
          ],
          description: [
            type: {:or, [:string, __MODULE__.Type.render_fn()]},
            doc:
              "Optional page description rendered below the title. " <>
                "Accepts a string or a render function that receives assigns."
          ],
          route: [
            type: :string,
            doc:
              ~s{URL path for this page (e.g. `"/recipes"`, `"/recipes/:id"`). } <>
                "Renderers may use this to generate route declarations; navigation " <>
                "items can auto-resolve paths from the page module."
          ],
          default_viewer: [
            type: {:one_of, [:data_table, :grid, :calendar, :gantt, :kanban, :list]},
            default: :data_table,
            doc: "The default viewer type for the page."
          ],
          track_presence?: [
            type: :boolean,
            default: true,
            doc:
              "When true, tracks which users are viewing or editing records on this page via the configured presence backend."
          ]
        ]
      },
      %Spark.Dsl.Section{
        describe:
          "Configure views for displaying resource data. Views can be nested recursively.",
        entities: [
          PyroManiac.View.View.__entity__()
        ],
        name: :views,
        schema: [
          exclude: [
            default: [],
            doc: "Action names to exclude from all views.",
            type: {:list, :atom}
          ]
        ]
      },
      %Spark.Dsl.Section{
        describe: "Configure the appearance of forms in the `PyroManiac.Dsl` extension.",
        entities: [
          PyroManiac.Form.Action.__entity__(),
          PyroManiac.Form.BulkAction.__entity__()
        ],
        name: :forms,
        schema: [
          class: [
            doc: "The default class for the form.",
            type: __MODULE__.Type.css_class()
          ],
          description: [
            doc: "The default description for forms.",
            type: __MODULE__.Type.inheritable(:string)
          ],
          exclude: [
            default: [],
            doc: "The actions to exclude from forms.",
            type: {:list, :atom}
          ],
          extra_form_types: [
            default: [],
            doc: "Additional field type atoms accepted by the form DSL.",
            type: {:list, :atom}
          ]
        ]
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
      __MODULE__.Transformers.ValidateViews,
      __MODULE__.Transformers.ExpandFormActions,
      __MODULE__.Transformers.ValidatePage
    ],
    verifiers: [
      __MODULE__.Verifiers.ResourceHasExtension
    ],
    persisters: [
      __MODULE__.Persisters.Views
    ]
end
