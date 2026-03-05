defmodule Brewery.BatchStatus do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      planned: [label: "Planned", description: "Scheduled for future production."],
      brewing: [label: "Brewing", description: "Brew day in progress."],
      fermenting: [label: "Fermenting", description: "Active fermentation underway."],
      conditioning: [label: "Conditioning", description: "Resting at cellar temperature."],
      packaging: [label: "Packaging", description: "Being packaged for distribution."],
      complete: [label: "Complete", description: "Batch finished and released."],
      cancelled: [label: "Cancelled", description: "Production cancelled."]
    ]
end
