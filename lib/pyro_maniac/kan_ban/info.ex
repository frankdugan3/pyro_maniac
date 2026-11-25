defmodule PyroManiac.KanBan.Info do
  @moduledoc """
  Introspection helpers for the `PyroManiac.KanBan` extension.
  """

  alias PyroManiac.KanBan.Lane

  @doc """
  The `lane` entity of the board, with the actions of dynamic lanes
  resolved, or `nil` without the `PyroManiac.KanBan` extension.
  """
  @spec lane(Ash.Resource.t()) :: Lane.t() | nil
  def lane(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:kan_ban])
    |> Enum.find(&match?(%Lane{}, &1))
  end

  @doc "Returns the lane (group_by) field for the kanban board: the name of the `lane`."
  @spec lane!(Ash.Resource.t()) :: atom()
  def lane!(resource) do
    case lane(resource) do
      %Lane{name: name} -> name
      nil -> raise "Resource #{inspect(resource)} does not have the PyroManiac.KanBan extension"
    end
  end

  @doc "Returns the priority field for card ordering."
  @spec priority!(Ash.Resource.t()) :: atom()
  def priority!(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:kan_ban], :priority) ||
      raise "Resource #{inspect(resource)} does not have the PyroManiac.KanBan extension"
  end

  @doc "Returns the kanban move action name."
  @spec move_action!(Ash.Resource.t()) :: atom()
  def move_action!(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:kan_ban], :move_action) ||
      raise "Resource #{inspect(resource)} does not have the PyroManiac.KanBan extension"
  end

  @doc "Returns the kanban read action name."
  @spec read_action!(Ash.Resource.t()) :: atom()
  def read_action!(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:kan_ban], :read_action) ||
      raise "Resource #{inspect(resource)} does not have the PyroManiac.KanBan extension"
  end

  @doc "Returns the per-lane card limit."
  @spec per_lane(Ash.Resource.t()) :: pos_integer()
  def per_lane(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:kan_ban], :per_lane, 20)
  end

  @doc "Returns whether lane counts are enabled."
  @spec count?(Ash.Resource.t()) :: boolean()
  def count?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:kan_ban], :count?, false)
  end

  @doc """
  The `belongs_to` of dynamic lanes (the `lane` is a relationship), or
  `nil` (static lanes: the `lane` is an attribute).
  """
  @spec lane_relationship(Ash.Resource.t()) :: Ash.Resource.Relationships.BelongsTo.t() | nil
  def lane_relationship(resource) do
    case Ash.Resource.Info.relationship(resource, lane!(resource)) do
      %Ash.Resource.Relationships.BelongsTo{} = relationship -> relationship
      _other -> nil
    end
  end

  @doc "Whether the lanes are dynamic: the records of the destination of a `belongs_to`."
  @spec dynamic_lanes?(Ash.Resource.t()) :: boolean()
  def dynamic_lanes?(resource), do: not is_nil(lane_relationship(resource))

  @doc """
  The attribute that groups the cards: the `lane` attribute, or the foreign
  key of a `belongs_to` lane. The cards are ordered in each value of it.
  """
  @spec lane_attribute!(Ash.Resource.t()) :: atom()
  def lane_attribute!(resource) do
    case lane_relationship(resource) do
      %{source_attribute: attribute} -> attribute
      nil -> lane!(resource)
    end
  end

  @doc "The resource of dynamic lanes, or `nil`."
  @spec lane_resource(Ash.Resource.t()) :: Ash.Resource.t() | nil
  def lane_resource(resource) do
    case lane_relationship(resource) do
      %{destination: destination} -> destination
      nil -> nil
    end
  end

  @doc """
  The read action of dynamic lanes: the `read_action` of the `lane`, else
  the primary read action of the lane resource. `nil` for static lanes.
  """
  @spec lane_read_action(Ash.Resource.t()) :: atom() | nil
  def lane_read_action(resource) do
    if dynamic_lanes?(resource), do: lane(resource).read_action
  end

  @doc """
  The action of dynamic lanes that adds (`:create`), edits (`:update`),
  deletes (`:destroy`), or moves (`:move`) a lane: the action of the
  `lane`, else the primary action of that type of the lane resource (for
  `:move`, the move action of the ordered lane resource). `nil` when it is
  turned off (`false`), when the lane resource has no such action, or for
  static lanes.
  """
  @spec lane_action(Ash.Resource.t(), :create | :update | :destroy | :move) :: atom() | nil
  def lane_action(resource, type) when type in [:create, :update, :destroy, :move] do
    if dynamic_lanes?(resource), do: Map.fetch!(lane(resource), :"#{type}_action")
  end

  @doc """
  Whether the board manages dynamic lanes: it adds, edits, or deletes
  them (`lane_action/2` is not `nil` for `:create`, `:update`, or
  `:destroy`). Moving a lane is `lane_action(resource, :move)`.
  """
  @spec manage_lanes?(Ash.Resource.t()) :: boolean()
  def manage_lanes?(resource),
    do: Enum.any?([:create, :update, :destroy], &lane_action(resource, &1))

  @doc """
  The order of dynamic lanes, an Ash sort input: the `sort` of the `lane`,
  else the rank of the lane resource when it is ordered, else `nil`.
  """
  @spec lane_sort(Ash.Resource.t()) :: String.t() | nil
  def lane_sort(resource) do
    with destination when not is_nil(destination) <- lane_resource(resource) do
      lane(resource).sort ||
        case PyroManiac.Ordering.Info.ordering(destination) do
          %{attribute: attribute} -> Atom.to_string(attribute)
          nil -> nil
        end
    end
  end

  @doc """
  The lanes of a board, in order: `%{value:, label:, record:}`. Static
  lanes are the values of the `lane` attribute (`record: nil`). Dynamic
  lanes are the records of the lane read action, for the options (`actor`,
  `tenant`, `authorize?`, and `query`: a query of the lane resource to
  start from, for example the lanes of one project); `value` is the
  primary key, and `label` the record label (`PyroManiac.Resource`), else
  its `name`.

  A board shows the lane "No lane" (`value: nil`) too when the foreign key
  of a dynamic lane can be `nil` and a card has none.
  """
  @spec lanes(Ash.Resource.t(), keyword()) ::
          {:ok, [%{value: term(), label: String.t(), record: struct() | nil}]}
          | {:error, term()}
  def lanes(resource, opts \\ []) do
    case lane_resource(resource) do
      nil -> {:ok, static_lanes(resource)}
      destination -> dynamic_lanes(resource, destination, opts)
    end
  end

  defp static_lanes(resource) do
    attribute = Ash.Resource.Info.attribute(resource, lane!(resource))

    attribute
    |> values()
    |> Enum.map(&%{value: &1, label: value_label(attribute.type, &1), record: nil})
  end

  # `function_exported?/3` is false for a module that is not loaded yet.
  defp values(%{type: type, constraints: constraints}) do
    cond do
      Keyword.has_key?(constraints, :one_of) -> constraints[:one_of]
      Code.ensure_loaded?(type) and function_exported?(type, :values, 0) -> type.values()
      true -> []
    end
  end

  defp value_label(type, value) do
    if Code.ensure_loaded?(type) and function_exported?(type, :label, 1) and type.label(value),
      do: type.label(value),
      else: value |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp dynamic_lanes(resource, destination, opts) do
    [key] = Ash.Resource.Info.primary_key(destination)
    query = Keyword.get(opts, :query, Ash.Query.new(destination))

    query =
      case lane_sort(resource) do
        nil -> query
        sort -> Ash.Query.sort_input(query, sort)
      end

    with {:ok, records} <-
           query
           |> Ash.Query.for_read(
             lane_read_action(resource),
             %{},
             Keyword.take(opts, [:actor, :tenant])
           )
           |> Ash.Query.load(label_load(destination))
           |> Ash.read(Keyword.take(opts, [:actor, :tenant, :authorize?])) do
      {:ok,
       Enum.map(
         records,
         &%{value: Map.get(&1, key), label: record_label(destination, &1), record: &1}
       )}
    end
  end

  defp label_load(destination) do
    if PyroManiac.Resource in Spark.extensions(destination),
      do: PyroManiac.Info.default_label_load(destination),
      else: []
  end

  defp record_label(destination, record) do
    if PyroManiac.Resource in Spark.extensions(destination),
      do: PyroManiac.Resource.Info.record_label(destination, record),
      else: to_string(Map.get(record, :name) || Map.get(record, :id))
  end

  @doc "Returns true if the resource has the PyroManiac.KanBan extension."
  @spec has_kanban?(Ash.Resource.t()) :: boolean()
  def has_kanban?(resource) do
    not is_nil(lane(resource))
  end
end
