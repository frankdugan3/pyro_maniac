defmodule PyroManiac.SubscriptionManager do
  @moduledoc """
  Shared PubSub subscription logic for PyroManiac viewers.

  Provides a common interface for subscribing to Ash.Notifier.PubSub topics
  and interpreting incoming notifications.
  """

  alias PyroManiac.Info

  @doc """
  Subscribe the current process to PubSub topics for the given resource.

  Uses the resource's `Ash.Notifier.PubSub` configuration to determine
  the PubSub module and topic prefix.

  Returns `:ok` if subscribed, `:noop` if PubSub is not configured.
  """
  @spec subscribe(module()) :: :ok | :noop
  def subscribe(resource) do
    if pubsub_configured?(resource) do
      pubsub_module = Ash.Notifier.PubSub.Info.module(resource)
      pubsub_name = Ash.Notifier.PubSub.Info.name(resource)

      Enum.each(publication_topics(resource), &do_subscribe(pubsub_module, pubsub_name, &1))
      :ok
    else
      :noop
    end
  end

  defp do_subscribe(pubsub_module, nil, topic), do: pubsub_module.subscribe(topic)
  defp do_subscribe(pubsub_module, name, topic), do: pubsub_module.subscribe(name, topic)

  @doc """
  Unsubscribe the current process from PubSub topics for the given resource.
  """
  @spec unsubscribe(module()) :: :ok | :noop
  def unsubscribe(resource) do
    if pubsub_configured?(resource) do
      pubsub_module = Ash.Notifier.PubSub.Info.module(resource)
      pubsub_name = Ash.Notifier.PubSub.Info.name(resource)

      Enum.each(publication_topics(resource), &do_unsubscribe(pubsub_module, pubsub_name, &1))
      :ok
    else
      :noop
    end
  end

  defp do_unsubscribe(pubsub_module, nil, topic), do: pubsub_module.unsubscribe(topic)
  defp do_unsubscribe(pubsub_module, name, topic), do: pubsub_module.unsubscribe(name, topic)

  @doc """
  Check whether a resource has PubSub configured via Ash.Notifier.PubSub.
  """
  @spec pubsub_configured?(module()) :: boolean()
  def pubsub_configured?(resource) do
    prefix = Ash.Notifier.PubSub.Info.prefix(resource)
    pubsub_module = Ash.Notifier.PubSub.Info.module(resource)
    prefix != nil && pubsub_module != nil
  end

  @doc """
  Compute all subscribable topics from a resource's publications.

  Only includes topics that are fully static (no dynamic segments like `:id`).
  Topics with dynamic segments cannot be subscribed to ahead of time.
  """
  @spec publication_topics(module()) :: [String.t()]
  def publication_topics(resource) do
    prefix = Ash.Notifier.PubSub.Info.prefix(resource) || ""
    delimiter = Ash.Notifier.PubSub.Info.delimiter(resource)

    resource
    |> Ash.Notifier.PubSub.Info.publications()
    |> Enum.flat_map(&static_topic(&1, prefix, delimiter))
    |> Enum.uniq()
  end

  defp static_topic(pub, prefix, delimiter) do
    topic_parts = List.wrap(pub.topic)

    if Enum.all?(topic_parts, &is_binary/1) do
      [join_topic(prefix, Enum.join(topic_parts, delimiter), delimiter)]
    else
      []
    end
  end

  defp join_topic("", "", _), do: ""
  defp join_topic(prefix, "", _), do: prefix
  defp join_topic("", topic, _), do: topic
  defp join_topic(prefix, topic, delimiter), do: "#{prefix}#{delimiter}#{topic}"

  @doc """
  Check whether a PyroManiac module has any realtime options configured
  on its views (on_create, on_update, on_destroy).
  """
  @spec has_realtime?(module()) :: boolean()
  def has_realtime?(pyro_maniac_module) do
    views = Info.views(pyro_maniac_module)

    Enum.any?(views, fn view ->
      Map.get(view, :on_create, :none) != :none ||
        Map.get(view, :on_update, :none) != :none ||
        Map.get(view, :on_destroy, :none) != :none
    end)
  rescue
    _ -> false
  end

  @doc """
  Interpret an incoming PubSub notification against a view's realtime config.

  Returns an instruction tuple describing what the receiver should do:

  - `{:prepend, record}` — add the record to the front of the list
  - `{:append, record}` — add the record to the end of the list
  - `{:replace, record}` — replace the matching record in the list
  - `{:remove, id}` — remove the record with this ID from the list
  - `:reload` — reload the entire data set from the server
  - `{:notify, action_type}` — show a notification without modifying data
  - `:ignore` — no action needed
  """
  @spec handle_notification(term(), map()) ::
          {:prepend, map()}
          | {:append, map()}
          | {:replace, map()}
          | {:remove, any()}
          | :reload
          | {:notify, atom()}
          | :ignore
  def handle_notification(message, view) do
    case extract_notification(message) do
      %Ash.Notifier.Notification{action: action, data: data} ->
        dispatch_action(action.type, data, view)

      nil ->
        :ignore
    end
  end

  @doc """
  Extract the `Ash.Notifier.Notification` from any broadcast format.

  Handles all three `broadcast_type` configurations:
  - `:notification` (default) — the raw notification struct
  - `:broadcast` — `%{topic:, event:, payload: notification}`
  - `:phoenix_broadcast` — `%Phoenix.Socket.Broadcast{payload: notification}`
  """
  @spec extract_notification(term()) :: Ash.Notifier.Notification.t() | nil
  def extract_notification(%Ash.Notifier.Notification{} = notification), do: notification

  def extract_notification(%{payload: %Ash.Notifier.Notification{} = notification}),
    do: notification

  def extract_notification(_), do: nil

  defp dispatch_action(:create, data, view) do
    case Map.get(view, :on_create, :none) do
      :prepend -> {:prepend, data}
      :append -> {:append, data}
      :reload -> :reload
      :notify -> {:notify, :create}
      _ -> :ignore
    end
  end

  defp dispatch_action(:update, data, view) do
    case Map.get(view, :on_update, :none) do
      :replace -> {:replace, data}
      :reload -> :reload
      :notify -> {:notify, :update}
      _ -> :ignore
    end
  end

  defp dispatch_action(:destroy, data, view) do
    case Map.get(view, :on_destroy, :none) do
      :remove -> {:remove, data.id}
      :reload -> :reload
      :notify -> {:notify, :destroy}
      _ -> :ignore
    end
  end

  defp dispatch_action(_, _, _), do: :ignore

  @doc """
  Build a Phoenix Presence topic string for a PyroManiac page.
  """
  @spec presence_topic(module()) :: String.t()
  def presence_topic(pyro_maniac_module) do
    resource = Info.resource(pyro_maniac_module)
    "pyro_maniac:presence:#{inspect(resource)}"
  end
end
