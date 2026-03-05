{:ok, _} = Brewery.Repo.start_link()

# Disable ANSI for stable, color-free test output.
Application.put_env(:elixir, :ansi_enabled, false)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Brewery.Repo, :manual)
