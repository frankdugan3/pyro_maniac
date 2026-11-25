defmodule BreweryWeb.BatchLive do
  @moduledoc false

  use PyroManiac, resource: Brewery.Batch

  view :read do
    type :data_table
    primary? true
    default_sort "-batch_number"
    exclude [:id, :recipe_id, :brewer_id, :recipe, :brewer, :kanban_priority]
    column :batch_number
    column :status
    column :brew_date
    column :package_date
    column :actual_og
    column :actual_fg
    column :actual_abv
    column :volume_liters
    column :notes
    column :test_count
    column :passed_test_count
    column :pass_rate
  end

  view :read do
    type :card
    primary? true

    section :batch do
      field :batch_number
      field :status
    end
  end

  page do
    route "/batches"

    exclude [
      :create,
      :update,
      :start_brewing,
      :advance_status,
      :complete,
      :move_card,
      :destroy,
      :list,
      :kanban_read
    ]
  end
end
