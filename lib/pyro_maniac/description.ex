defmodule PyroManiac.Description do
  @moduledoc """
  The description of a node: `description "text"` or `description
  expr(...)` for every renderer, and `description Renderer, implementation`
  for one renderer. The page and a view have no record, so their
  description is a text or implementations. `description :inherit` on an
  input, an action, or a bulk action takes the description of its
  attribute, argument, or action, as a text. It is an entity, not a keyword
  option. Refer to `PyroManiac.Content`.

      field :notes do
        type :textarea
        description :inherit
      end

      section :measurements do
        description expr(if is_nil(package_date), do: "Not packaged yet.", else: "Packaged.")
        field :actual_og
        field :actual_fg
      end
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :description,
    args: [:renderer, {:optional, :implementation}],
    describe:
      "The description: a text or an Ash expression for every renderer, or an implementation for one renderer.",
    no_depend_modules: [:renderer, :implementation],
    schema: PyroManiac.Content.schema(),
    private_fields: PyroManiac.Content.private_fields(),
    transform: {PyroManiac.Content, :normalize, []}
end
