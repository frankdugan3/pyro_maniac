defmodule Brewery.StorageBlob do
  @moduledoc false

  use Ash.Resource,
    domain: Brewery.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStorage.BlobResource]

  postgres do
    table "brewery_storage_blobs"
    repo(Brewery.Repo)
  end

  blob do
  end

  attributes do
    uuid_primary_key :id
  end
end
