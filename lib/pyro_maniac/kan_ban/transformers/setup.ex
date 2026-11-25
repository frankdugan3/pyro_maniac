defmodule PyroManiac.KanBan.Transformers.Setup do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias Ash.Resource.Builder
  alias PyroManiac.Dsl.Error
  alias PyroManiac.KanBan.Lane
  alias PyroManiac.Ordering.Setup
  alias Spark.Dsl.Entity
  alias Spark.Dsl.Transformer

  @ash_resource_transformers Ash.Resource.Dsl.transformers()

  @impl true
  def after?(transformer) when transformer in @ash_resource_transformers, do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module, nil)
    lane_entity = lane_entity!(dsl_state, module)
    priority = Transformer.get_option(dsl_state, [:kan_ban], :priority)
    move_action = Transformer.get_option(dsl_state, [:kan_ban], :move_action)
    read_action = Transformer.get_option(dsl_state, [:kan_ban], :read_action)
    per_lane = Transformer.get_option(dsl_state, [:kan_ban], :per_lane)
    count? = Transformer.get_option(dsl_state, [:kan_ban], :count?)

    # A `belongs_to` lane (dynamic lanes) orders the cards by its foreign key.
    {dsl_state, lane} =
      case lane_relationship(dsl_state, lane_entity.name) do
        %{source_attribute: attribute, destination: destination} ->
          resolved = resolve_lane_actions!(lane_entity, destination, module)

          {Transformer.replace_entity(dsl_state, [:kan_ban], resolved, &match?(%Lane{}, &1)),
           attribute}

        nil ->
          validate_lane!(dsl_state, lane_entity, module)
          validate_static_options!(lane_entity, module)
          {dsl_state, lane_entity.name}
      end

    # The order of the cards is a `PyroManiac.Ordering` scoped by the lane
    # (`PyroManiac.Ordering.Setup`), with the kanban move change.
    dsl_state =
      dsl_state
      |> Setup.ensure_rank_attribute(priority, module, [:kan_ban, :priority])
      |> Setup.set_column_collation(priority)
      |> Setup.ensure_unique_index([lane, priority], "kanban_rank_index")
      |> Setup.add_assign_rank(lane, priority)
      |> add_rerank_change(lane, priority, move_action)
      |> Setup.add_move_action(
        move_action,
        [lane, priority],
        {PyroManiac.KanBan.MoveCard, lane: lane, priority: priority},
        module,
        [:kan_ban, :move_action]
      )

    dsl_state =
      create_read_action(dsl_state, read_action, lane, priority, per_lane, count?, module)

    {:ok, dsl_state}
  end

  defp lane_relationship(dsl_state, lane) do
    dsl_state
    |> Transformer.get_entities([:relationships])
    |> Enum.find(&match?(%Ash.Resource.Relationships.BelongsTo{name: ^lane}, &1))
  end

  defp lane_entity!(dsl_state, module) do
    case Enum.filter(Transformer.get_entities(dsl_state, [:kan_ban]), &match?(%Lane{}, &1)) do
      [lane] ->
        lane

      lanes ->
        Error.raise!(
          module: module,
          location: Transformer.get_section_anno(dsl_state, [:kan_ban]),
          path: [:kan_ban, :lane],
          why: "a board has exactly one `lane`, got #{length(lanes)}",
          fix: "set one `lane :status` (an attribute) or `lane :stage` (a `belongs_to`)"
        )
    end
  end

  @lane_action_types [read_action: :read]
  @managing_action_types [
    create_action: :create,
    update_action: :update,
    destroy_action: :destroy
  ]

  # The actions of dynamic lanes, on the destination: the option, else the
  # primary action of its type. A lane resource is read, so `read_action` is
  # required; without a create, update, or destroy, the board does not add,
  # rename, or delete lanes.
  defp resolve_lane_actions!(%Lane{} = lane, destination, module) do
    case Code.ensure_compiled(destination) do
      {:module, _} ->
        :ok

      {:error, reason} ->
        Error.raise!(
          module: module,
          location: Entity.anno(lane),
          path: [:kan_ban, :lane, lane.name],
          why:
            "the lanes are the records of #{inspect(destination)}, but it is not available " <>
              "(#{inspect(reason)})"
        )
    end

    lane =
      Enum.reduce(@lane_action_types, lane, fn {option, type}, lane ->
        %{lane | option => resolve_action!(lane, option, type, destination, module, true)}
      end)

    lane =
      Enum.reduce(@managing_action_types, lane, fn {option, type}, lane ->
        %{lane | option => resolve_action!(lane, option, type, destination, module, false)}
      end)

    lane = %{lane | move_action: resolve_move_action!(lane, destination, module)}
    validate_destroy_confirm!(lane, module)
    lane
  end

  defp validate_destroy_confirm!(
         %Lane{destroy_action: action, destroy_confirm: nil} = lane,
         module
       )
       when not is_nil(action) do
    Error.raise!(
      module: module,
      location: Entity.anno(lane),
      path: [:kan_ban, :lane, lane.name, :destroy_confirm],
      why:
        "the board deletes lanes (`#{action}`), and the lane does not say if the delete asks first",
      fix:
        "set `destroy_confirm \"Delete the lane?\"`, `destroy_confirm false`, or " <>
          "`destroy_action false`"
    )
  end

  defp validate_destroy_confirm!(_lane, _module), do: :ok

  # The move of a lane in the order of the lanes: the option, else the move
  # action of the ordered destination (`PyroManiac.Ordering.Info.ordering/1`).
  defp resolve_move_action!(%Lane{move_action: false}, _destination, _module), do: nil

  defp resolve_move_action!(%Lane{move_action: nil}, destination, _module) do
    with %{move_action: name} <- PyroManiac.Ordering.Info.ordering(destination),
         %{type: :update} <- Ash.Resource.Info.action(destination, name) do
      name
    else
      _ -> nil
    end
  end

  defp resolve_move_action!(%Lane{move_action: name} = lane, destination, module),
    do: validate_lane_action!(lane, :move_action, name, :update, destination, module)

  defp resolve_action!(lane, option, type, destination, module, required?) do
    case Map.fetch!(lane, option) do
      false when not required? ->
        nil

      nil ->
        primary_action!(lane, option, type, destination, module, required?)

      name ->
        validate_lane_action!(lane, option, name, type, destination, module)
    end
  end

  defp primary_action!(lane, option, type, destination, module, required?) do
    case Ash.Resource.Info.primary_action(destination, type) do
      %{name: name} ->
        name

      nil when required? ->
        Error.raise!(
          module: module,
          location: Entity.anno(lane),
          path: [:kan_ban, :lane, lane.name, option],
          why:
            "the board reads the lanes from #{inspect(destination)}, but it has no primary " <>
              "read action",
          fix:
            "add a read action to #{inspect(destination)}, or set `#{option}` to one of its " <>
              "read actions"
        )

      nil ->
        nil
    end
  end

  defp validate_lane_action!(lane, option, name, type, destination, module) do
    location = Entity.property_anno(lane, option) || Entity.anno(lane)
    path = [:kan_ban, :lane, lane.name, option]

    case Ash.Resource.Info.action(destination, name) do
      %{type: ^type} ->
        name

      nil ->
        Error.raise!(
          module: module,
          location: location,
          path: path,
          why: "`#{option} #{inspect(name)}` is not an action of #{inspect(destination)}",
          suggestions: Error.did_you_mean(name, actions_of_type(destination, type)),
          fix:
            "set `#{option}` to a #{type} action of #{inspect(destination)}, or remove it " <>
              "(the primary #{type} action)"
        )

      %{type: other} ->
        Error.raise!(
          module: module,
          location: location,
          path: path,
          why:
            "`#{option} #{inspect(name)}` is an action of type `#{inspect(other)}` of " <>
              "#{inspect(destination)}, but `#{option}` is an action of type `#{inspect(type)}`",
          fix:
            "set `#{option}` to one of the `#{inspect(type)}` actions of " <>
              "#{inspect(destination)}: #{inspect(actions_of_type(destination, type))}"
        )
    end
  end

  defp actions_of_type(resource, type) do
    for %{type: ^type, name: name} <- Ash.Resource.Info.actions(resource), do: name
  end

  @dynamic_options [
    :read_action,
    :destroy_confirm,
    :create_action,
    :update_action,
    :destroy_action,
    :move_action,
    :sort
  ]

  defp validate_static_options!(%Lane{} = lane, module) do
    for option <- @dynamic_options, not is_nil(Map.fetch!(lane, option)) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(lane, option) || Entity.anno(lane),
        path: [:kan_ban, :lane, lane.name, option],
        why:
          "`#{option}` is for dynamic lanes (a `belongs_to` lane), but the lane " <>
            "#{inspect(lane.name)} is an attribute: its lanes are its values",
        fix: "remove `#{option}`, or make the lane a `belongs_to` to the resource of the lanes"
      )
    end
  end

  defp validate_lane!(dsl_state, %Lane{name: lane} = lane_entity, module) do
    location = Entity.anno(lane_entity)

    Transformer.get_entities(dsl_state, [:attributes])
    |> Enum.find(&(&1.name == lane))
    |> case do
      nil ->
        Error.raise!(
          module: module,
          location: location,
          path: [:kan_ban, :lane],
          why:
            "lane #{inspect(lane)} is neither an attribute nor a `belongs_to` of this resource",
          suggestions: attribute_suggestions(lane, dsl_state),
          fix:
            "set `lane` to an enum attribute (static lanes), or to a `belongs_to` (dynamic lanes)"
        )

      attr ->
        if !valid_lane_type?(attr) do
          Error.raise!(
            module: module,
            location: location,
            path: [:kan_ban, :lane],
            why:
              "lane field #{inspect(lane)} must be an Ash enum type or an atom/string with " <>
                "`one_of` constraints, got #{inspect(attr.type)}",
            fix:
              "change the lane attribute's type to an Ash.Type.Enum subclass, or add " <>
                "`constraints: [one_of: [...]]`"
          )
        end
    end
  end

  defp valid_lane_type?(%{constraints: constraints, type: Ash.Type.Atom}),
    do: Keyword.has_key?(constraints, :one_of)

  defp valid_lane_type?(%{constraints: constraints, type: :atom}),
    do: Keyword.has_key?(constraints, :one_of)

  defp valid_lane_type?(%{type: type}) when is_atom(type) do
    Code.ensure_loaded?(type) and function_exported?(type, :values, 0)
  end

  defp valid_lane_type?(_), do: false

  defp add_rerank_change(dsl_state, lane, priority, move_action) do
    {:ok, dsl_state} =
      Builder.add_change(
        dsl_state,
        {PyroManiac.KanBan.RerankOnLaneChange,
         lane: lane, priority: priority, move_action: move_action},
        on: [:update]
      )

    dsl_state
  end

  defp create_read_action(dsl_state, action_name, lane, priority, per_lane, count?, module) do
    if Ash.Resource.Info.action(dsl_state, action_name) do
      Error.raise!(
        module: module,
        location: Transformer.get_opt_anno(dsl_state, [:kan_ban], :read_action),
        path: [:kan_ban, :read_action],
        why:
          "action #{inspect(action_name)} already exists on this resource — the kanban " <>
            "extension creates it automatically",
        fix:
          "either rename the existing action or set `read_action :different_name` in the " <>
            "kan_ban block"
      )
    end

    {:ok, pagination} =
      Builder.build_pagination(keyset?: true, countable: count?, default_limit: per_lane)

    {:ok, lane_argument} =
      Builder.build_action_argument(:lane_value, :string,
        allow_nil?: true,
        description: "The lane to read. All lanes when not set."
      )

    {:ok, dsl_state} =
      Builder.add_action(dsl_state, :read, action_name,
        arguments: [lane_argument],
        pagination: pagination,
        preparations: [
          Builder.build_preparation({PyroManiac.KanBan.FilterLane, lane: lane}),
          Builder.build_preparation({Ash.Resource.Preparation.Build, sort: [{priority, :asc}]})
        ]
      )

    dsl_state
  end

  defp attribute_suggestions(name, dsl_state) do
    candidates =
      dsl_state
      |> Transformer.get_entities([:attributes])
      |> Enum.map(& &1.name)

    Error.did_you_mean(name, candidates)
  end
end
