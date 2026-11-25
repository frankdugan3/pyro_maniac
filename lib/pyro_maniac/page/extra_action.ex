defmodule PyroManiac.Page.ExtraAction do
  @moduledoc """
  A custom action button that can be added to the page toolbar, data table rows, or card actions.

  `render` gives the whole action for a renderer: its button and its
  content (for example a modal or a panel). It gets `:action`, `:base_path`,
  `:params`, and (for row-level) `:row`. Without it, the renderer shows a
  link button and a generic action.

      extra_action :export do
        label "Export"
        render PyroManiac.LiveView, BreweryWeb.RecipeLive.ExportAction
      end

  ## Fields

  """

  use PyroManiac.Dsl.Entity,
    name: :extra_action,
    args: [:name],
    describe: "Add a custom action to the page toolbar, data table rows, or card actions.",
    imports: [Ash.Expr],
    entities: [render: [PyroManiac.Render]],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Unique identifier for this action."
      ],
      label: [
        type: :string,
        required: true,
        doc: "Display label for the action button."
      ]
    ]
end
