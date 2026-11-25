defmodule PyroManiac.Navigation.Dsl do
  @moduledoc false

  use Spark.Dsl.Extension,
    sections: [
      %Spark.Dsl.Section{
        describe: "Define the application navigation structure.",
        entities: [
          PyroManiac.Navigation.Item.__entity__(),
          PyroManiac.Navigation.Group.__entity__()
        ],
        name: :nav,
        schema: [
          orientation: [
            type: PyroManiac.Dsl.Type.orientation(),
            default: :vertical,
            doc:
              "The axis of the navigation: `:vertical` (a sidebar, the default) or `:horizontal` (a top bar; its groups are menus)."
          ]
        ]
      },
      %Spark.Dsl.Section{
        describe:
          "The command palette: a search of the navigation items and of the commands, opened with a hotkey.",
        entities: [PyroManiac.Navigation.Command.__entity__()],
        name: :command_palette,
        schema: [
          enabled?: [
            type: :boolean,
            default: true,
            doc: "Show the command palette."
          ],
          hotkey: [
            type: :string,
            default: "mod+k",
            doc: "The key that opens the palette (`mod` is Cmd on macOS, else Ctrl)."
          ],
          navigation?: [
            type: :boolean,
            default: true,
            doc: "The palette finds the items of the navigation (that the user can open)."
          ],
          placeholder: [
            type: :string,
            default: "Search",
            doc: "The text of the empty search input."
          ]
        ]
      }
    ],
    transformers: [
      PyroManiac.Navigation.Transformers.ValidateNav
    ],
    persisters: [
      PyroManiac.Navigation.Persisters.NavTree
    ]
end
