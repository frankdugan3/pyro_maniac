defmodule Brewery.QualityTest do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [PyroManiac.Resource, AshStorage],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "brewery_quality_tests"
    repo(Brewery.Repo)
  end

  pyro_maniac do
    default_label :test_type
  end

  storage do
    service({AshStorage.Service.Disk, root: "/tmp/pyro_maniac_test_attachments"})
    blob_resource(Brewery.StorageBlob)
    attachment_resource(Brewery.StorageAttachment)
    has_many_attached(:lab_reports)
  end

  pub_sub do
    module Phoenix.PubSub
    name PyroManiac.PubSub
    prefix "brewery:quality_test"
    publish_all :create, ["created"]
    publish_all :update, ["updated"]
    publish_all :destroy, ["destroyed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :test_type, Brewery.TestType,
      allow_nil?: false,
      public?: true,
      description: "Category of quality test."

    attribute :tested_at, :utc_datetime,
      allow_nil?: false,
      public?: true,
      description: "When the test was performed."

    attribute :result, :string,
      allow_nil?: false,
      public?: true,
      description: "Test result value or summary."

    attribute :passed, :boolean,
      allow_nil?: false,
      public?: true,
      description: "Whether the test met quality standards."

    attribute :notes, :string,
      public?: true,
      description: "Additional observations."
  end

  relationships do
    belongs_to :batch, Brewery.Batch, allow_nil?: false, public?: true
    belongs_to :tester, Brewery.Staff, allow_nil?: true, public?: true
  end

  calculations do
    calculate :passed_text, :string do
      calculation expr(if(passed, "PASS", "FAIL"))
      public? true
      description "Human-readable pass/fail text."
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy]

    create :create do
      primary? true

      argument :batch_id, :uuid, allow_nil?: false
      argument :tester_id, :uuid

      change manage_relationship(:batch_id, :batch, type: :append_and_remove)
      change manage_relationship(:tester_id, :tester, type: :append_and_remove)

      description "Record a quality test result."
    end

    update :update do
      primary? true
      require_atomic? false
    end

    # Exercises the form-DSL attachment validator: an action that accepts files
    # via an `Ash.Type.File` argument must declare a `type: :attachment` field.
    update :archive do
      accept []
      require_atomic? false
      argument :lab_reports, {:array, Ash.Type.File}, allow_nil?: false
    end
  end
end
