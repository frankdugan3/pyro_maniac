defmodule PyroManiac.Realtime do
  @moduledoc """
  Realtime helpers for resources with the `realtime` section of
  `PyroManiac.Resource`.
  """
  @moduledoc group: "PyroManiac"

  @doc """
  The full topic of a resource, from its `Ash.Notifier.PubSub` prefix and
  delimiter. Use it in place of a literal topic string.

      PyroManiac.Realtime.topic(MyApp.Brewery.Recipe, "*")
      #=> "brewery_recipe:*"
  """
  @spec topic(Ash.Resource.t(), String.t() | [String.t()]) :: String.t()
  def topic(resource, suffix) do
    prefix = Ash.Notifier.PubSub.Info.prefix(resource)
    delimiter = Ash.Notifier.PubSub.Info.delimiter(resource)
    suffix = suffix |> List.wrap() |> Enum.join(delimiter)

    case {prefix, suffix} do
      {nil, suffix} -> suffix
      {prefix, ""} -> prefix
      {prefix, suffix} -> prefix <> delimiter <> suffix
    end
  end

  @doc """
  The default topic prefix of a resource: the module name without its first
  segment, in snake case, joined with `_`.

      iex> PyroManiac.Realtime.default_prefix(MyApp.Purchasing.Vendor)
      "purchasing_vendor"

      iex> PyroManiac.Realtime.default_prefix(MyApp.FFL.ADRecord)
      "ffl_ad_record"
  """
  @spec default_prefix(module()) :: String.t()
  def default_prefix(module) do
    module
    |> Module.split()
    |> Enum.drop(1)
    |> Enum.map_join("_", &Macro.underscore/1)
  end

  @doc """
  The topic of the `PyroManiac.Realtime.Bulk` messages of a resource: the
  topic with the suffix `"bulk"`.
  """
  @spec bulk_topic(Ash.Resource.t()) :: String.t()
  def bulk_topic(resource), do: topic(resource, "bulk")

  @doc """
  Sends one `PyroManiac.Realtime.Bulk` message for `resource`. Use it after
  a bulk change that Ash does not notify, for example a truncate:

      PyroManiac.Realtime.broadcast_bulk(MyApp.Brewery.Recipe, :truncate)

  `event` must be in `bulk` of the `realtime` section. `PyroManiac.Realtime.BulkNotifier`
  calls this function for the bulk actions.

  ## Options

  - `:type` - `:create`, `:update`, or `:destroy`. The default is `nil`.
  """
  @spec broadcast_bulk(Ash.Resource.t(), atom(), keyword()) :: :ok
  def broadcast_bulk(resource, event, opts \\ []) when is_atom(event) do
    if event not in PyroManiac.Resource.Info.realtime_bulk(resource) do
      raise ArgumentError,
            "#{inspect(event)} is not in `bulk` of the `realtime` section of #{inspect(resource)}"
    end

    bulk = %PyroManiac.Realtime.Bulk{resource: resource, event: event, type: opts[:type]}
    topic = bulk_topic(resource)
    payload = payload(Ash.Notifier.PubSub.Info.broadcast_type(resource), topic, bulk)
    module = Ash.Notifier.PubSub.Info.module(resource)

    case Ash.Notifier.PubSub.Info.name(resource) do
      nil -> module.broadcast(topic, "bulk", payload)
      name -> module.broadcast(name, topic, payload)
    end

    :ok
  end

  # The same formats as `Ash.Notifier.PubSub.to_payload/4`.
  defp payload(:phoenix_broadcast, topic, bulk),
    do: %{__struct__: Phoenix.Socket.Broadcast, topic: topic, event: "bulk", payload: bulk}

  defp payload(:broadcast, topic, bulk), do: %{topic: topic, event: "bulk", payload: bulk}
  defp payload(_notification, _topic, bulk), do: bulk

  @doc """
  The publication filter of a resource with bulk actions. It is `false` for
  a notification of a bulk operation of an action in `bulk` of the
  `realtime` section: `PyroManiac.Realtime.BulkNotifier` sends one message
  for the operation. `:auto` mode adds it to its publications. In
  `:validate` mode, add it to each publication of a bulk action:

      publish_all :update, ["*"], filter: &PyroManiac.Realtime.record_notification?/1
  """
  @spec record_notification?(Ash.Notifier.Notification.t()) :: boolean()
  def record_notification?(%Ash.Notifier.Notification{resource: resource, action: action} = n) do
    not bulk?(n) or action.name not in PyroManiac.Resource.Info.realtime_bulk(resource)
  end

  @doc false
  @spec bulk?(Ash.Notifier.Notification.t()) :: boolean()
  def bulk?(%Ash.Notifier.Notification{changeset: %{context: context}}) do
    Enum.any?([:bulk_create, :bulk_update, :bulk_destroy], &Map.has_key?(context, &1))
  end

  def bulk?(_notification), do: false

  @doc """
  The default PubSub module: `config :pyro_maniac, :realtime, module: ...`.
  """
  @spec default_module() :: module() | nil
  def default_module do
    :pyro_maniac
    |> Application.get_env(:realtime, [])
    |> Keyword.get(:module)
  end
end
