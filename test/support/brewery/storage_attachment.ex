defmodule Brewery.StorageAttachment do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage.AttachmentResource]

  postgres do
    table "brewery_storage_attachments"
    repo(Brewery.Repo)
  end

  attachment do
    blob_resource(Brewery.StorageBlob)
    belongs_to_resource(:recipe, Brewery.Recipe)
    belongs_to_resource(:quality_test, Brewery.QualityTest)
  end

  attributes do
    uuid_primary_key :id
  end
end
