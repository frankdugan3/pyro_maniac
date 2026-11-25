defmodule PyroManiac.LinkTo do
  @moduledoc """
  A link to another page: it navigates to the page, to the single view of a
  record or to a list view filtered by the relationship.

      column :recipe do
        link_to BreweryWeb.RecipeLive
      end

      related :batches do
        type :data_table
        limit 5

        link_to BreweryWeb.BatchLive do
          list_view :read
        end
      end

  - On a relationship to one record, the link opens the single view of the
    record: `single_view`, else the primary single view of the page.
  - On a relationship to many records (`related`), each record links to its
    single view, and the link to all the records opens a list view filtered
    by the relationship: `list_view`, else the primary list view of the page.

  `single_view` and `list_view` name a view of the page (the action of the
  view).

  `open` says how a click on a record opens it. `:navigate` goes to the page
  of the record. `:stack` opens the card of the record in a layer over the
  current page (or over the current layer: a dialog on a dialog), and
  `:replace` opens it in place of the top layer. A layer keeps the page
  below as it is: Close, Escape, or Back closes the top layer. Its Edit
  stays in the layer. The `href` of the link is always the page of the
  record (a new tab, a copy of the link).

      column :supplier do
        link_to BreweryWeb.SuppliersPage do
          open :stack
          presentation :drawer
        end
      end

  The page is not a compile-time dependency (two pages can link to each
  other). A verifier checks it after everything compiles.
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :link_to,
    args: [:page],
    describe: "A link to another page: the single view of a record, or a list view.",
    no_depend_modules: [:page],
    schema: [
      page: [
        doc: "The PyroManiac page. Its resource is the destination of the relationship.",
        required: true,
        type: :atom
      ],
      single_view: [
        doc: "The single view of a record (a `:card` view). Defaults to the primary single view.",
        type: :atom
      ],
      open: [
        doc:
          "How a click on a record opens it: `:navigate` (the default: the page of the record), `:stack` (its card in a new layer over the current page or layer), or `:replace` (its card in place of the top layer). The link to all the records (a list view) always navigates.",
        type: {:one_of, [:navigate, :stack, :replace]},
        default: :navigate
      ],
      presentation: [
        doc:
          "The shape of a layer (`:stack`, `:replace`): `:modal` or `:drawer`. Defaults to the `presentation` of the card of the page (a card with `presentation :page` opens as a modal).",
        type: {:one_of, [:modal, :drawer]}
      ],
      list_view: [
        doc:
          "The list view of all the related records (a relationship to many records only). Defaults to the primary list view.",
        type: :atom
      ]
    ]
end
