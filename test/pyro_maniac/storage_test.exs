defmodule PyroManiac.StorageTest do
  # The upload endpoint finds the attachment in the record tree of a view of
  # a page; the names of the client never make an atom. (A real upload is in
  # the browser tests of the demo.)
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias PyroManiac.Storage

  doctest PyroManiac.Storage

  @scope %{actor: nil, tenant: nil, context: %{}}

  test "only a page of the application" do
    assert {:error, 404, "no page \"Elixir.Nope\""} =
             Storage.attach(
               :pyro_maniac,
               %{"page" => "Elixir.Nope", "view" => "read:card"},
               @scope
             )

    assert {:error, 404, _} =
             Storage.attach(
               :pyro_maniac,
               %{"page" => "Brewery.Recipe", "view" => "read:card"},
               @scope
             )

    assert {:error, 400, "page and view are required"} = Storage.attach(:pyro_maniac, %{}, @scope)
  end

  test "only a view of the page, and an attachments node of its tree" do
    page = %{"page" => "BreweryWeb.RecipeLive"}

    assert {:error, 404, "no view \"read:nope\""} =
             Storage.attach(:pyro_maniac, Map.put(page, "view", "read:nope"), @scope)

    assert {:error, 404, "no attachments \"photos\""} =
             Storage.attach(
               :pyro_maniac,
               Map.merge(page, %{"view" => "read:card", "attachment" => "photos"}),
               @scope
             )
  end

  test "the plug answers JSON" do
    opts = PyroManiac.Storage.Plug.init(otp_app: :pyro_maniac)

    conn =
      conn(:post, "/attach", %{"page" => "Elixir.Nope", "view" => "x"})
      |> PyroManiac.Storage.Plug.call(opts)

    assert conn.status == 404
    assert get_resp_header(conn, "content-type") |> hd() =~ "application/json"
    assert Jason.decode!(conn.resp_body) == %{"error" => "no page \"Elixir.Nope\""}

    assert %{status: 404} = conn(:get, "/attach") |> PyroManiac.Storage.Plug.call(opts)
  end
end
