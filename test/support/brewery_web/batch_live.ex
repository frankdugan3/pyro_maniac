defmodule BreweryWeb.BatchLive do
  @moduledoc false

  use PyroManiac, resource: Brewery.Batch

  views do
    view :read do
      type :data_table
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

      view do
        type :delegated
        relationship :quality_tests
        delegate_to BreweryWeb.QualityTestLive
      end
    end
  end

  forms do
    exclude [:create, :update, :start_brewing, :advance_status, :complete, :move_card]
  end
end
