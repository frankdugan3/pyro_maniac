defmodule Brewery.Repo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :pyro_maniac

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext", PyroManiac.KanBan.PostgresExtension]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
