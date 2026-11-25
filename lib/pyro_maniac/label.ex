defmodule PyroManiac.Label do
  @moduledoc """
  The label of a column: `label "text"` or `label expr(...)` for every
  renderer, and `label Renderer, implementation` for one renderer. Without
  it, the label is the capitalized name. Refer to `PyroManiac.Content`.
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :label,
    args: [:renderer, {:optional, :implementation}],
    describe:
      "The label: a text or an Ash expression for every renderer, or an implementation for one renderer.",
    no_depend_modules: [:renderer, :implementation],
    schema: PyroManiac.Content.schema(),
    private_fields: PyroManiac.Content.private_fields(),
    transform: {PyroManiac.Content, :normalize, []}
end
