defmodule PyroManiac.Navigation.Item do
  @moduledoc """
  A navigation item in `PyroManiac`.

  Represents a single link in the navigation sidebar. Each item must have
  exactly one of `page`, `module`, or `href`:

  - `page` — A PyroManiac page module (validated, authorization-aware)
  - `module` — A non-PyroManiac module (always visible)
  - `href` — An external URL (opens in new tab)

  Items with `page` or `module` require a `path`. Items with `href` do not.
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
        doc: "URL path for `page` or `module` items (must start with `/`).",
        type: :string
      ],
      label: [
        doc: "Display text. Auto-derived from name if omitted.",
        type: :string
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
        doc: "A PyroManiac page module. Validated and authorization-aware.",
        type: :atom
      ],
      module: [
        doc: "A non-PyroManiac module. Not validated against PyroManiac.",
        type: :atom
      ],
      href: [
        doc: "External URL. Opens in a new tab.",
        type: :string
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
