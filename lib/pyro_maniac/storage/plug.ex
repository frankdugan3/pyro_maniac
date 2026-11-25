if Code.ensure_loaded?(AshStorage) do
  defmodule PyroManiac.Storage.Plug do
    @moduledoc """
    The upload endpoint of `PyroManiac.Storage`: `POST /attach`, a multipart
    request (`PyroManiac.Storage.attach/3`). It answers JSON: `{"ok": true}`,
    or `{"error": message}` with the status.

    Forward a path of the router to it, in a pipeline with the session, the
    actor (for example `load_from_session` of AshAuthentication), and the
    CSRF protection, as the AshTypescript RPC endpoints:

        scope "/" do
          pipe_through :browser
          forward "/pyro_maniac/storage", PyroManiac.Storage.Plug, otp_app: :my_app
        end

    The actor, the tenant, and the context come from `Ash.PlugHelpers`.
    """
    @moduledoc group: "PyroManiac"

    @behaviour Plug

    import Plug.Conn

    @impl Plug
    def init(opts) do
      %{otp_app: Keyword.get(opts, :otp_app) || raise(ArgumentError, "otp_app is required")}
    end

    @impl Plug
    def call(%Plug.Conn{method: "POST", path_info: ["attach"]} = conn, %{otp_app: otp_app}) do
      conn = ensure_params(conn)

      scope = %{
        actor: Ash.PlugHelpers.get_actor(conn),
        tenant: Ash.PlugHelpers.get_tenant(conn),
        context: Ash.PlugHelpers.get_context(conn) || %{}
      }

      case PyroManiac.Storage.attach(otp_app, conn.body_params, scope) do
        {:ok, data} -> json(conn, 200, data)
        {:error, status, message} -> json(conn, status, %{"error" => message})
      end
    end

    def call(conn, _opts), do: json(conn, 404, %{"error" => "not found"})

    defp ensure_params(%Plug.Conn{body_params: %Plug.Conn.Unfetched{}} = conn) do
      Plug.Parsers.call(conn, Plug.Parsers.init(parsers: [:multipart], pass: ["*/*"]))
    end

    defp ensure_params(conn), do: conn

    defp json(conn, status, data) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(status, Jason.encode!(data))
      |> halt()
    end
  end
end
