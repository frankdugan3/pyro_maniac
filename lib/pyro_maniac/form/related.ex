defmodule PyroManiac.Form.Related do
  @moduledoc """
  The records of a relationship of the record, in either direction. They are
  read-only in edit mode: each has its own form.

  With `delegate_to`, a delegated viewer (a page of the destination, scoped
  to the record). Without it, the records in a `type` (`:list`,
  `:data_table`, `:grid`, `:count`, or `:badge`), with the `field` entities
  as the columns.

  `presentation` is where they show: `:inline` in the record, or `:modal`
  or `:drawer` over the page (the record shows a count that opens them).

      related :batches do
        delegate_to BreweryWeb.BatchLive
        presentation :modal
        count :batch_count
      end

      related :recipe_ingredients do
        type :badge
      end

  A `link_to` navigates to another page: each record to its single view,
  and the link to all the records to a list view filtered by the
  relationship (refer to `PyroManiac.LinkTo`).
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Type

  use PyroManiac.Dsl.Entity,
    name: :related,
    args: [:name],
    describe: "The records of a relationship. Read-only in edit mode.",
    imports: [Ash.Expr],
    entities: [
      description: [PyroManiac.Description],
      fields: [PyroManiac.View.Field],
      link_to: [PyroManiac.LinkTo],
      render: [PyroManiac.Render]
    ],
    schema: [
      name: [
        doc: "The relationship of the resource.",
        required: true,
        type: :atom
      ],
      label: [
        doc: "The heading (defaults to the capitalized name).",
        type: :string
      ],
      delegate_to: [
        doc:
          "A page of the destination resource, mounted as a delegated viewer scoped to the record.",
        type: Type.link_target()
      ],
      type: [
        default: :list,
        doc:
          "How the records look without `delegate_to`: `:list`, `:data_table`, `:grid`, `:count`, or `:badge`.",
        type: Type.related_type()
      ],
      presentation: [
        default: :inline,
        doc:
          "Where the records show: `:inline` in the record, or `:modal` or `:drawer` over the page.",
        type: Type.related_presentation()
      ],
      count: [
        doc: "An aggregate or a calculation of the resource: the count in the heading.",
        type: :atom
      ],
      limit: [
        doc: "The maximum number of records that show (without `delegate_to`).",
        type: :pos_integer
      ],
      empty_text: [
        default: "None",
        doc: "The text when there is no related record.",
        type: :string
      ],
      only: [
        doc:
          "The actions that show it: the read action of the view (view mode) and the actions of the tree. `nil`: all.",
        type: Type.only()
      ],
      visible?: [
        doc: "Conditional visibility: an Ash expression.",
        type: Type.expression()
      ]
    ],
    private_fields: [
      __depends_on__: [
        default: [],
        doc:
          "The attributes and arguments that `visible?` refers to, and `{:parent, name}` for `parent(name)`. Set by the transformer.",
        type: {:list, :any}
      ],
      __full_path__: [
        default: [],
        doc: "The full path from the form resource. Set by the transformer.",
        type: {:list, :atom}
      ],
      __destination__: [
        doc: "The destination resource of the relationship. Set by the transformer.",
        type: :atom
      ]
    ]
end
