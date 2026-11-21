defmodule PyroManiac.Realtime.Bulk do
  @moduledoc """
  The single notification of a bulk operation on a resource.

  The message goes to the topic `PyroManiac.Realtime.bulk_topic/1`, with the
  event `"bulk"`, in the format of the `broadcast_type` of the `pub_sub`
  section (the same as the record notifications).

  - `resource`: the resource.
  - `event`: the name of the bulk action, or the event of
    `PyroManiac.Realtime.broadcast_bulk/2` (for example `:truncate`).
  - `type`: `:create`, `:update`, or `:destroy` for an action, else `nil`.
  """
  @moduledoc group: "PyroManiac"

  @enforce_keys [:resource, :event]
  defstruct [:resource, :event, :type]

  @type t :: %__MODULE__{
          resource: Ash.Resource.t(),
          event: atom(),
          type: :create | :update | :destroy | nil
        }
end
