defmodule PyroManiac.Page.ExtraAction do
  @moduledoc """
  A custom action button that can be added to the page toolbar, data table rows, or card actions.

  ## Fields

  """

  use PyroManiac.Dsl.Entity,
    name: :extra_action,
    args: [:name],
    describe: "Add a custom action to the page toolbar, data table rows, or card actions.",
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
      ],
      button: [
        type: PyroManiac.Dsl.Type.render_fn(),
        doc:
          "Render function for the action button. Receives assigns with `:action`, `:base_path`, `:params`, and (for row-level) `:row`. Defaults to a generic link button."
      ],
      render: [
        type: PyroManiac.Dsl.Type.render_fn(),
        doc:
          "Render function for the action content (e.g. a modal or panel). Receives assigns with `:action`, `:base_path`, `:params`, and (for row-level) `:row`. Defaults to a generic action renderer."
      ]
    ]
end
