defmodule PyroManiac.KanBan.AssignRank do
  @moduledoc """
  Ash resource change that assigns a fractional index rank on create
  if one is not already set. Appends the card to the end of its lane.

  The read of the last rank does not authorize. The rank is the order of
  all cards of the lane, and the actor can be permitted to read only some
  of them. A read with the actor would then give a rank that another card
  already has. The read uses the tenant of the changeset.

  ## Options

    * `:lane` — the attribute name for lane grouping
    * `:priority` — the attribute name for the rank string
  """
  use Ash.Resource.Change

  alias PyroManiac.KanBan.FractionalIndex

  @impl true
  def change(changeset, opts, context) do
    lane_field = Keyword.fetch!(opts, :lane)
    priority_field = Keyword.fetch!(opts, :priority)

    if Ash.Changeset.get_attribute(changeset, priority_field) do
      changeset
    else
      Ash.Changeset.before_action(changeset, fn changeset ->
        lane_value = Ash.Changeset.get_attribute(changeset, lane_field)
        rank = rank_after_last(changeset, lane_field, priority_field, lane_value, context)
        Ash.Changeset.force_change_attribute(changeset, priority_field, rank)
      end)
    end
  end

  @doc """
  Returns a rank after the last card of the lane `lane_value`. The card of
  the changeset is not included, so an update can move it to the end.
  """
  def rank_after_last(changeset, lane_field, priority_field, lane_value, context) do
    changeset
    |> last_rank(lane_field, priority_field, lane_value, context)
    |> FractionalIndex.generate_key_between(nil)
  end

  defp last_rank(_changeset, _lane_field, _priority_field, nil, _context), do: nil

  # The actor goes with the read, because a domain can require an actor also
  # for a read that does not authorize.
  defp last_rank(changeset, lane_field, priority_field, lane_value, context) do
    changeset.resource
    |> Ash.Query.filter_input(%{lane_field => %{"eq" => lane_value}})
    |> exclude_self(changeset)
    |> Ash.Query.sort([{priority_field, :desc}])
    |> Ash.Query.limit(1)
    |> Ash.Query.set_tenant(changeset.tenant)
    |> Ash.read!(actor: context && context.actor, authorize?: false)
    |> case do
      [record] -> Map.get(record, priority_field)
      _ -> nil
    end
  end

  defp exclude_self(query, %{action_type: :update, data: data}) do
    pkey = Ash.Resource.Info.primary_key(query.resource)
    Ash.Query.filter_input(query, %{"not" => Map.new(pkey, &{&1, %{"eq" => Map.get(data, &1)}})})
  end

  defp exclude_self(query, _changeset), do: query
end
