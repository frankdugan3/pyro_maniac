if Code.ensure_loaded?(AshStorage) do
  defmodule PyroManiac.Storage do
    @moduledoc """
    The upload of a file to an `attachments` node of a view, with AshStorage.
    Available only when AshStorage is a dependency.

    A JSON RPC cannot carry a file, so a renderer that runs its actions over
    RPC (AshTypescript) uploads with a multipart request to
    `PyroManiac.Storage.Plug`. The upload runs the `attach_<name>` action of
    AshStorage on the record, with the actor and its policies. Detach and
    purge are normal actions.

    Only an attachment of the record tree of a view of a page can get a
    file: the name of the client never makes an atom, and the page decides
    what can be uploaded.
    """
    @moduledoc group: "PyroManiac"

    require Logger

    @type scope :: %{actor: term(), tenant: term(), context: map()}
    @type result :: {:ok, map()} | {:error, pos_integer(), String.t()}

    @doc """
    Attaches an uploaded file to a record.

    Params: `page` (the name of the page module, `"MyAppWeb.RecipesPage"`),
    `view` (the key of the view, `PyroManiac.ListState.view_key/1`), `id`,
    `attachment` (the name of the `attachments` node), and `file` (a
    `Plug.Upload`).
    """
    @spec attach(atom(), map(), scope()) :: result()
    def attach(otp_app, params, scope) do
      with {:ok, view} <- find_view(otp_app, params["page"], params["view"]),
           {:ok, name} <- attachment_of(view, params["attachment"]),
           {:ok, upload} <- upload(params["file"]),
           {:ok, record} <- get_record(view.resource, params["id"], scope) do
        record
        |> Ash.Changeset.for_update(
          :"attach_#{name}",
          %{
            io: upload,
            filename: upload.filename,
            content_type: upload.content_type || "application/octet-stream"
          },
          opts(scope)
        )
        |> Ash.update(opts(scope))
        |> case do
          {:ok, _record} -> {:ok, %{"ok" => true}}
          {:error, error} -> {:error, 422, error_message(error)}
        end
      end
    end

    @doc """
    The message of an error for a client: the messages of an invalid input
    (without the bread crumbs of Ash), or "You cannot do this." for a
    forbidden action. Any other error (a bug, the database) is logged, and the
    client gets "The action failed." and no detail of the server.

        iex> PyroManiac.Storage.error_message(Ash.Error.Forbidden.exception([]))
        "You cannot do this."
    """
    @spec error_message(term()) :: String.t()
    def error_message(error) do
      case Ash.Error.to_error_class(error) do
        %Ash.Error.Invalid{errors: errors} ->
          errors |> Enum.map(&clean_message/1) |> Enum.uniq() |> Enum.join(" ")

        %Ash.Error.Forbidden{} ->
          "You cannot do this."

        other ->
          Logger.error("PyroManiac: " <> Exception.format(:error, other))
          "The action failed."
      end
    end

    defp clean_message(error) do
      error
      |> Exception.message()
      |> String.replace(~r/\A\s*Bread Crumbs:\n(?:[ \t]+>.*\n)*\s*/, "")
      |> String.trim()
    end

    defp find_view(otp_app, page, key) when is_binary(page) and is_binary(key) do
      otp_app
      |> Application.spec(:modules)
      |> List.wrap()
      |> Enum.find(&(inspect(&1) == page and PyroManiac.Info.page?(&1)))
      |> case do
        nil ->
          {:error, 404, "no page #{inspect(page)}"}

        module ->
          module
          |> PyroManiac.Info.views()
          |> Enum.find(&(PyroManiac.ListState.view_key(&1) == key))
          |> case do
            nil -> {:error, 404, "no view #{inspect(key)}"}
            view -> {:ok, view}
          end
      end
    end

    defp find_view(_otp_app, _page, _key), do: {:error, 400, "page and view are required"}

    defp attachment_of(view, name) when is_binary(name) do
      view
      |> tree()
      |> PyroManiac.Form.Tree.all()
      |> Enum.find_value({:error, 404, "no attachments #{inspect(name)}"}, fn
        %PyroManiac.Form.Attachments{name: attachment} ->
          if Atom.to_string(attachment) == name, do: {:ok, attachment}

        _ ->
          nil
      end)
    end

    defp attachment_of(_view, _name), do: {:error, 400, "attachment is required"}

    defp tree(view) do
      PyroManiac.Card.tree(view)
    rescue
      _ -> []
    end

    defp upload(%{__struct__: Plug.Upload} = upload), do: {:ok, upload}
    defp upload(_other), do: {:error, 400, "file is required"}

    defp get_record(resource, id, scope) when is_binary(id) do
      case Ash.get(resource, id, opts(scope)) do
        {:ok, record} -> {:ok, record}
        {:error, _} -> {:error, 404, "not found"}
      end
    end

    defp get_record(_resource, _id, _scope), do: {:error, 400, "id is required"}

    defp opts(scope),
      do: [actor: scope.actor, tenant: scope.tenant, context: scope.context || %{}]
  end
end
