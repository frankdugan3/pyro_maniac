defmodule BreweryWeb.QualityTestLive do
  @moduledoc false

  use PyroManiac, resource: Brewery.QualityTest

  views do
    view :read do
      type :data_table
      default_sort "-tested_at"

      exclude [
        :id,
        :batch_id,
        :tester_id,
        :batch,
        :tester,
        :passed_text,
        :lab_reports,
        :lab_reports_urls
      ]

      column :test_type
      column :tested_at
      column :result
      column :passed
      column :notes
    end
  end

  forms do
    exclude [:create, :update, :archive]
  end
end
