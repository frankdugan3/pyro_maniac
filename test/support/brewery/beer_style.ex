defmodule Brewery.BeerStyle do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      ipa: [label: "IPA", description: "India Pale Ale and variants."],
      stout: [label: "Stout", description: "Dark, roasted malt ales."],
      lager: [label: "Lager", description: "Bottom-fermented, clean and crisp."],
      wheat: [label: "Wheat", description: "Wheat-forward ales including hefeweizen."],
      sour: [label: "Sour", description: "Intentionally tart or acidic beers."],
      porter: [label: "Porter", description: "Dark ales with chocolate and caramel notes."],
      pale_ale: [label: "Pale Ale", description: "Balanced, hop-forward pale ales."]
    ]
end
