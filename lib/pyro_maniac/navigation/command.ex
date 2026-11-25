defmodule PyroManiac.Navigation.Command do
  @moduledoc """
  A command of the command palette, in addition to the items of the
  navigation. It has exactly one target: `page` (a PyroManiac page),
  `module` (another module), `href` (a URL), or `render` (custom content or
  behaviour, one for each renderer, for example a search of the records or
  an action).

      command_palette do
        command :new_batch do
          label "New batch"
          group "Batches"
          keywords ["brew", "schedule"]
          page BreweryWeb.BatchLive
          path "/batches?new"
        end
      end
  """
  @moduledoc group: "PyroManiac.Navigation"

  use PyroManiac.Dsl.Entity,
    name: :command,
    args: [:name],
    describe: "A command of the command palette.",
    entities: [render: [PyroManiac.Render]],
    schema: [
      name: [doc: "Unique identifier for this command.", required: true, type: :atom],
      label: [doc: "Display text. Auto-derived from name if omitted.", type: :string],
      description: [doc: "Text below the label.", type: :string],
      group: [doc: "The group of the command in the palette.", type: :string],
      keywords: [default: [], doc: "Words that also find the command.", type: {:list, :string}],
      icon: [doc: "Icon name to be passed to the renderer.", type: :atom],
      page: [doc: "A PyroManiac page module. Validated and authorization-aware.", type: :atom],
      module: [doc: "A non-PyroManiac module.", type: :atom],
      path: [
        doc:
          "URL path. Required for `module` (starts with `/`). Optional for `page`: it starts with the `route` of the page (for example `\"/batches?new\"`); without it, the command opens the route.",
        type: :string
      ],
      href: [doc: "A URL.", type: :string],
      authorizer: [
        doc: "Custom authorizer function `(scope -> boolean)`.",
        type: {:fun, [:map], :boolean}
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  @doc false
  def __set_defaults__(command) do
    {:ok,
     Map.update!(command, :label, fn
       nil -> PyroManiac.Dsl.Transformers.default_label(command.name)
       label -> label
     end)}
  end
end
