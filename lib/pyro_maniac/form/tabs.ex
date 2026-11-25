defmodule PyroManiac.Form.Tabs do
  @moduledoc """
  Divides the record into tabs. A record has one `tabs`, at the top level,
  after the nodes that show on every tab. A tab cannot contain `tabs`.

      tabs do
        tab :overview do
          section :recipe do
            field :name
            field :style
          end
        end

        tab :batches do
          count :batch_count
          related :batches
        end
      end

  `orientation :vertical` puts the tab list at the side of the panel (the
  default, `:horizontal`, puts it above).
  """
  @moduledoc group: "PyroManiac"

  use PyroManiac.Dsl.Entity,
    name: :tabs,
    args: [],
    describe: "Divides the record into tabs.",
    entities: [fields: [PyroManiac.Form.Tab], render: [PyroManiac.Render]],
    schema: [
      orientation: [
        default: :horizontal,
        doc:
          "The axis of the tab list: `:horizontal` (above the panel, the default) or `:vertical` (at the side of the panel).",
        type: PyroManiac.Dsl.Type.orientation()
      ]
    ],
    private_fields: [
      __full_path__: [
        default: [],
        doc: "The full path from the form resource. Set by the transformer.",
        type: {:list, :atom}
      ]
    ]
end
