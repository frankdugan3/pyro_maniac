defmodule PyroManiac.Realtime.BulkCoalescer do
  @moduledoc """
  Sends one `PyroManiac.Realtime.Bulk` message for the notifications of a
  bulk operation.

  Ash gives a notifier the notifications of a bulk operation one at a time,
  and no notification identifies the operation. `PyroManiac.Realtime.BulkNotifier`
  sends each notification of a bulk action here. The coalescer sends the
  message when no notification of the same resource and action came for
  `window` milliseconds. Two bulk operations of one action inside the window
  give one message.

  The window is `config :pyro_maniac, :realtime, bulk_window: 50` (the
  default, in milliseconds).

  Add the coalescer to the supervision tree of the app:

      children = [
        # ...
        PyroManiac.Realtime.BulkCoalescer
      ]

  Without it, the first bulk notification starts the coalescer without a
  supervisor.
  """
  @moduledoc group: "PyroManiac"

  use GenServer

  @default_window 50

  @doc false
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Records one notification of a bulk operation of `action` on `resource`.
  """
  @spec push(Ash.Resource.t(), Ash.Resource.Actions.action()) :: :ok
  def push(resource, action) do
    GenServer.cast(server(), {:push, resource, action.name, action.type})
  end

  defp server do
    case GenServer.start(__MODULE__, [], name: __MODULE__) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:push, resource, name, type}, timers) do
    key = {resource, name}

    case Map.get(timers, key) do
      nil -> :ok
      {timer, _type} -> Process.cancel_timer(timer)
    end

    timer = Process.send_after(self(), {:flush, key}, window())
    {:noreply, Map.put(timers, key, {timer, type})}
  end

  @impl true
  def handle_info({:flush, {resource, name} = key}, timers) do
    {{_timer, type}, timers} = Map.pop(timers, key)
    PyroManiac.Realtime.broadcast_bulk(resource, name, type: type)
    {:noreply, timers}
  end

  defp window do
    :pyro_maniac
    |> Application.get_env(:realtime, [])
    |> Keyword.get(:bulk_window, @default_window)
  end
end
