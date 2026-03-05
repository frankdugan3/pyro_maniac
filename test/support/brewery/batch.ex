defmodule Brewery.Batch do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource, PyroManiac.KanBan],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "brewery_batches"
    repo(Brewery.Repo)
  end

  pyro_maniac do
    default_label :batch_number
  end

  kan_ban do
    lane :status
    priority :kanban_priority
    count? true
    per_lane 20
    move_action :move_card
    read_action :kanban_read
  end

  pub_sub do
    module Phoenix.PubSub
    name PyroManiac.PubSub
    prefix "brewery:batch"
    publish_all :create, ["created"]
    publish_all :update, ["updated"]
    publish_all :destroy, ["destroyed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :batch_number, :string,
      allow_nil?: false,
      public?: true,
      description: "Unique batch identifier (e.g. B-2024-042)."

    attribute :status, Brewery.BatchStatus,
      allow_nil?: false,
      default: :planned,
      public?: true,
      description: "Current production stage."

    attribute :brew_date, :date, public?: true, description: "Date brewing started."
    attribute :package_date, :date, public?: true, description: "Date packaged for distribution."

    attribute :actual_og, :decimal,
      public?: true,
      description: "Measured original gravity."

    attribute :actual_fg, :decimal,
      public?: true,
      description: "Measured final gravity."

    attribute :actual_abv, :decimal,
      public?: true,
      description: "Calculated ABV from actual gravities."

    attribute :volume_liters, :decimal,
      public?: true,
      description: "Total volume produced."

    attribute :notes, :string,
      public?: true,
      description: "Brewer observations and notes."
  end

  identities do
    identity :unique_batch_number, [:batch_number]
  end

  relationships do
    belongs_to :recipe, Brewery.Recipe, allow_nil?: false, public?: true
    belongs_to :brewer, Brewery.Staff, allow_nil?: true, public?: true
    has_many :quality_tests, Brewery.QualityTest
  end

  aggregates do
    count :test_count, :quality_tests, public?: true

    count :passed_test_count, :quality_tests do
      public? true
      filter expr(passed == true)
    end
  end

  calculations do
    calculate :pass_rate, :decimal do
      calculation expr(
                    if test_count > 0 do
                      fragment("?::decimal * 100 / ?::decimal", passed_test_count, test_count)
                    end
                  )

      public? true
      description "Percentage of quality tests passed."
    end
  end

  actions do
    default_accept [
      :batch_number,
      :status,
      :brew_date,
      :package_date,
      :actual_og,
      :actual_fg,
      :actual_abv,
      :volume_liters,
      :notes,
      :recipe_id,
      :brewer_id
    ]

    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [batch_number: :desc])
    end

    create :create do
      primary? true

      argument :recipe_id, :uuid, allow_nil?: false
      argument :brewer_id, :uuid

      change manage_relationship(:recipe_id, :recipe, type: :append_and_remove)
      change manage_relationship(:brewer_id, :brewer, type: :append_and_remove)

      description "Schedule a new production batch."
    end

    update :update do
      primary? true
      require_atomic? false
    end

    update :start_brewing do
      accept []
      change set_attribute(:status, :brewing)
      change set_attribute(:brew_date, &Date.utc_today/0)
      description "Begin the brewing process."
    end

    update :advance_status do
      accept [:status]
      require_atomic? false
      description "Move batch to the next production stage."
    end

    update :complete do
      accept [:actual_og, :actual_fg, :actual_abv, :volume_liters, :package_date]
      change set_attribute(:status, :complete)
      require_atomic? false
      description "Mark batch as complete with final measurements."
    end
  end
end
