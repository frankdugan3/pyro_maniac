defmodule PyroManiac.Navigation.Item do
  @moduledoc """
  A navigation item in `PyroManiac`.

  Represents a single link in the navigation sidebar. Each item must have
  exactly one of `page`, `module`, or `href`:

  - `page` — A PyroManiac page (validated, authorization-aware). The item
    opens the `route` of the page (`page do route "/recipes" end`), so it
    has no `path`.
  - `module` — A non-PyroManiac module (always visible). It has a `path`.
  - `href` — An external URL (opens in new tab). It has no `path`.

  Groups are not part of a route. No two routes of the navigation match the
  same URL: `"/recipes/:id"` and `"/recipes/new"` overlap.
  """

  use PyroManiac.Dsl.Entity,
    name: :item,
    args: [:name],
    describe: "Declare a navigation link.",
    schema: [
      name: [
        doc: "Unique identifier for this nav item.",
        required: true,
        type: :atom
      ],
      path: [
        doc:
          "URL path of a `module` item (starts with `/`). A `page` item opens the `route` of its page.",
        type: :string
      ],
      label: [
        doc: "Display text. Auto-derived from name if omitted.",
        type: :string
      ],
      decoration: [
        doc:
          "The meaning of the item: `:neutral`, `:info`, `:success`, `:warning`, or `:danger`. Each renderer maps it to its own style.",
        type: {:one_of, PyroManiac.Dsl.Type.decorations()}
      ],
      icon: [
        doc: "Icon name to be passed to the renderer.",
        type: :atom
      ],
      image: [
        doc: "Path or URL to an image (e.g. company logo). Mutually exclusive with `icon`.",
        type: :string
      ],
      image_alt: [
        doc: "Alt text for the image.",
        type: :string
      ],
      page: [
        doc:
          "A PyroManiac page (a module with a `page` section). The item opens its `route`. Validated and authorization-aware.",
        type: :atom
      ],
      module: [
        doc: "A non-PyroManiac module. Not validated against PyroManiac.",
        type: :atom
      ],
      href: [
        doc: "External URL. Opens in a new tab.",
        type: :string
      ],
      authorizer: [
        doc:
          "Custom authorizer function `(scope -> boolean)`. When set, takes precedence over the default page-based authorization.",
        type: {:fun, [:map], :boolean}
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  alias PyroManiac.Dsl.Transformers

  @doc false
  def __set_defaults__(item) do
    {:ok,
     item
     |> Map.update!(:label, fn
       nil -> Transformers.default_label(item.name)
       label -> label
     end)}
  end
end
