defmodule PyroManiac.KanBan.Transformers.Setup do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias Ash.Resource.Builder
  alias PyroManiac.Dsl.Error
  alias Spark.Dsl.Transformer

  @ash_resource_transformers Ash.Resource.Dsl.transformers()

  @impl true
  def after?(transformer) when transformer in @ash_resource_transformers, do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module, nil)
    lane = Transformer.get_option(dsl_state, [:kan_ban], :lane)
    priority = Transformer.get_option(dsl_state, [:kan_ban], :priority)
    move_action = Transformer.get_option(dsl_state, [:kan_ban], :move_action)
    read_action = Transformer.get_option(dsl_state, [:kan_ban], :read_action)
    per_lane = Transformer.get_option(dsl_state, [:kan_ban], :per_lane)
    count? = Transformer.get_option(dsl_state, [:kan_ban], :count?)

    validate_lane!(dsl_state, lane, module)

    dsl_state = ensure_priority_attribute(dsl_state, priority, module)
    dsl_state = set_column_collation(dsl_state, priority)
    dsl_state = ensure_unique_index(dsl_state, lane, priority)
    dsl_state = add_assign_rank_change(dsl_state, lane, priority)
    dsl_state = create_move_action(dsl_state, move_action, lane, priority, module)

    dsl_state =
      create_read_action(dsl_state, read_action, lane, priority, per_lane, count?, module)

    {:ok, dsl_state}
  end

  defp validate_lane!(dsl_state, lane, module) do
    Transformer.get_entities(dsl_state, [:attributes])
    |> Enum.find(&(&1.name == lane))
    |> case do
      nil ->
        Error.raise!(
          module: module,
          location: Transformer.get_opt_anno(dsl_state, [:kan_ban], :lane),
          path: [:kan_ban, :lane],
          why: "lane field #{inspect(lane)} does not exist as an attribute on this resource",
          suggestions: attribute_suggestions(lane, dsl_state),
          fix: "set `lane :existing_attr` in the kan_ban block, where :existing_attr is an enum"
        )

      attr ->
        if !valid_lane_type?(attr) do
          Error.raise!(
            module: module,
            location: Transformer.get_opt_anno(dsl_state, [:kan_ban], :lane),
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

  defp ensure_priority_attribute(dsl_state, priority, module) do
    existing =
      Transformer.get_entities(dsl_state, [:attributes])
      |> Enum.find(&(&1.name == priority))

    if existing do
      if existing.type not in [:string, Ash.Type.String] do
        Error.raise!(
          module: module,
          location: Transformer.get_opt_anno(dsl_state, [:kan_ban], :priority),
          path: [:kan_ban, :priority],
          why:
            "priority attribute #{inspect(priority)} must be a :string type for fractional " <>
              "indexing, got #{inspect(existing.type)}",
          fix:
            "change the priority attribute's type to :string, or remove it and let the " <>
              "extension generate one"
        )
      end

      dsl_state
    else
      {:ok, dsl_state} =
        Builder.add_attribute(dsl_state, priority, :string,
          public?: true,
          allow_nil?: true
        )

      dsl_state
    end
  end

  defp add_assign_rank_change(dsl_state, lane, priority) do
    {:ok, dsl_state} =
      Builder.add_change(
        dsl_state,
        {PyroManiac.KanBan.AssignRank, lane: lane, priority: priority},
        on: [:create]
      )

    dsl_state
  end

  defp set_column_collation(dsl_state, priority) do
    table = Transformer.get_option(dsl_state, [:postgres], :table)
    col = Atom.to_string(priority)

    statement = %AshPostgres.Statement{
      code?: false,
      down: ~s[ALTER TABLE #{table} ALTER COLUMN #{col} TYPE text],
      name: :"#{table}_#{col}_collation",
      up: ~s[ALTER TABLE #{table} ALTER COLUMN #{col} TYPE text COLLATE "C"]
    }

    Transformer.add_entity(dsl_state, [:postgres, :custom_statements], statement)
  end

  defp ensure_unique_index(dsl_state, lane, priority) do
    table = Transformer.get_option(dsl_state, [:postgres], :table)

    index = %AshPostgres.CustomIndex{
      fields: [lane, priority],
      name: "#{table}_kanban_rank_index",
      unique: true
    }

    Transformer.add_entity(dsl_state, [:postgres, :custom_indexes], index)
  end

  defp create_move_action(dsl_state, action_name, lane, priority, module) do
    if Ash.Resource.Info.action(dsl_state, action_name) do
      Error.raise!(
        module: module,
        location: Transformer.get_opt_anno(dsl_state, [:kan_ban], :move_action),
        path: [:kan_ban, :move_action],
        why:
          "action #{inspect(action_name)} already exists on this resource — the kanban " <>
            "extension creates it automatically",
        fix:
          "either rename the existing action or set `move_action :different_name` in the " <>
            "kan_ban block"
      )
    end

    {:ok, dsl_state} =
      Builder.add_action(dsl_state, :update, action_name,
        accept: [lane, priority],
        require_atomic?: false,
        changes: [
          Builder.build_action_change(
            {PyroManiac.KanBan.MoveCard, lane: lane, priority: priority}
          )
        ]
      )

    dsl_state
  end

  defp create_read_action(dsl_state, action_name, _lane, priority, per_lane, count?, module) do
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

    {:ok, dsl_state} =
      Builder.add_action(dsl_state, :read, action_name,
        pagination: pagination,
        preparations: [
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
