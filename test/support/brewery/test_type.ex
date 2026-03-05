defmodule Brewery.TestType do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      gravity: [label: "Gravity", description: "Specific gravity measurement (OG/FG)."],
      ph: [label: "pH", description: "Acidity level measurement."],
      appearance: [
        label: "Appearance",
        description: "Visual clarity, color, and head assessment."
      ],
      taste: [label: "Taste", description: "Sensory panel evaluation."],
      microbiology: [label: "Microbiology", description: "Contamination and cell count testing."]
    ]
end
