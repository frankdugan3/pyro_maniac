defmodule BreweryWeb.QualityTestLive do
  @moduledoc false

  use PyroManiac, resource: Brewery.QualityTest

  view :read do
    type :data_table
    primary? true
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

  view :read do
    type :card

    primary? true

    section :main do
      field :test_type
    end
  end

  page do
    route "/quality-tests"
    exclude [:create, :update, :archive, :destroy]
  end
end
