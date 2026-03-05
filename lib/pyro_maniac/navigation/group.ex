defmodule PyroManiac.Navigation.Group do
  @moduledoc """
  A navigation group in `PyroManiac`.

  Groups organize navigation items into collapsible sections. Groups can
  contain items and nested groups (recursive).
  """

  use PyroManiac.Dsl.Entity,
    name: :group,
    args: [:name],
    describe: "Declare a collapsible navigation group containing items and nested groups.",
    recursive_as: :items,
    entities: [
      items: [PyroManiac.Navigation.Item]
    ],
    schema: [
      name: [
        doc: "Unique identifier for this group.",
        required: true,
        type: :atom
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
        doc: "Path or URL to an image. Mutually exclusive with `icon`.",
        type: :string
      ],
      image_alt: [
        doc: "Alt text for the image.",
        type: :string
      ],
      default_open?: [
        doc: "Whether the group starts expanded.",
        default: true,
        type: :boolean
      ]
    ],
    transform: {__MODULE__, :__set_defaults__, []}

  alias PyroManiac.Dsl.Transformers

  @doc false
  def __set_defaults__(group) do
    {:ok,
     group
     |> Map.update!(:label, fn
       nil -> Transformers.default_label(group.name)
       label -> label
     end)}
  end
end
