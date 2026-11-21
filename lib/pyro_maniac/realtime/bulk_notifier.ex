defmodule PyroManiac.Realtime.BulkNotifier do
  @moduledoc """
  Sends one `PyroManiac.Realtime.Bulk` message for each bulk operation of
  the actions in `bulk` of the `realtime` section.

  Ash sends the notifications of a bulk operation after the operation (or
  after each batch, with `return_stream?: true`), one for each record. The
  changesets of a bulk operation have a `bulk_create`, `bulk_update`, or
  `bulk_destroy` context. This notifier gives each such notification of a
  bulk action to `PyroManiac.Realtime.BulkCoalescer`, which sends one
  message. The publication filter `PyroManiac.Realtime.record_notification?/1`
  stops the record notifications of the operation.

  A call with `notify?: false` (or `return_notifications?: true` without a
  later `Ash.Notifier.notify/1`) sends no notifications, thus no message.
  `:auto` mode adds this notifier when `bulk` has an action.
  """
  @moduledoc group: "PyroManiac"

  use Ash.Notifier

  @impl true
  def notify(%Ash.Notifier.Notification{resource: resource, action: action} = notification) do
    if PyroManiac.Realtime.bulk?(notification) and
         action.name in PyroManiac.Resource.Info.realtime_bulk(resource) do
      PyroManiac.Realtime.BulkCoalescer.push(resource, action)
    end

    :ok
  end
end
