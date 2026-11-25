defmodule PyroManiac.Ordering.Setup do
  @moduledoc false

  # The parts of an ordered attribute that `PyroManiac.Ordering` and
  # `PyroManiac.KanBan` share: the rank attribute (a `:string` fractional
  # index), its byte-order collation, the unique index of the scope and the
  # rank, the rank of a new record, and the move action.

  alias Ash.Resource.Builder
  alias PyroManiac.Dsl.Error
  alias Spark.Dsl.Transformer

  @doc false
  def ensure_rank_attribute(dsl, attribute, module, location_path) do
    case Enum.find(Transformer.get_entities(dsl, [:attributes]), &(&1.name == attribute)) do
      nil ->
        {:ok, dsl} =
          Builder.add_attribute(dsl, attribute, :string, public?: true, allow_nil?: true)

        dsl

      %{type: type} when type in [:string, Ash.Type.String] ->
        dsl

      %{type: type} ->
        Error.raise!(
          module: module,
          location:
            Transformer.get_opt_anno(dsl, Enum.drop(location_path, -1), List.last(location_path)),
          path: location_path,
          why:
            "the rank attribute #{inspect(attribute)} must be a :string (a fractional " <>
              "index), got #{inspect(type)}",
          fix: "change its type to :string, or remove it and let the extension add it"
        )
    end
  end

  @doc false
  def set_column_collation(dsl, attribute) do
    table = Transformer.get_option(dsl, [:postgres], :table)
    col = Atom.to_string(attribute)

    statement = %AshPostgres.Statement{
      code?: false,
      down: ~s[ALTER TABLE #{table} ALTER COLUMN #{col} TYPE text],
      name: :"#{table}_#{col}_collation",
      up: ~s[ALTER TABLE #{table} ALTER COLUMN #{col} TYPE text COLLATE "C"]
    }

    Transformer.add_entity(dsl, [:postgres, :custom_statements], statement)
  end

  # `build_entity` applies the defaults of the DSL schema (for example
  # `include_base_filter?` and `all_tenants?`). A struct that is made
  # directly has `nil` for them, and AshPostgres expects booleans.
  @doc false
  def ensure_unique_index(dsl, fields, suffix) do
    table = Transformer.get_option(dsl, [:postgres], :table)

    {:ok, index} =
      Transformer.build_entity(AshPostgres.DataLayer, [:postgres, :custom_indexes], :index,
        fields: fields,
        name: "#{table}_#{suffix}",
        unique: true
      )

    Transformer.add_entity(dsl, [:postgres, :custom_indexes], index)
  end

  @doc false
  def add_assign_rank(dsl, scope, attribute) do
    {:ok, dsl} =
      Builder.add_change(dsl, {PyroManiac.KanBan.AssignRank, lane: scope, priority: attribute},
        on: [:create]
      )

    dsl
  end

  @doc false
  def add_move_action(dsl, name, accept, change, module, location_path) do
    if Ash.Resource.Info.action(dsl, name) do
      Error.raise!(
        module: module,
        location:
          Transformer.get_opt_anno(dsl, Enum.drop(location_path, -1), List.last(location_path)),
        path: location_path,
        why: "action #{inspect(name)} already exists on this resource; the extension adds it",
        fix: "rename the existing action, or name another move action"
      )
    end

    {:ok, dsl} =
      Builder.add_action(dsl, :update, name,
        accept: accept,
        arguments: move_arguments(dsl),
        require_atomic?: false,
        changes: [Builder.build_action_change(change)]
      )

    dsl
  end

  @placements [:before, :after, :last]

  @doc false
  def placements, do: @placements

  # The public arguments of a move: the record to move before or after, and
  # where. A client (for example over RPC) gives them as any other input.
  defp move_arguments(dsl) do
    {type, constraints} =
      case Enum.filter(Transformer.get_entities(dsl, [:attributes]), & &1.primary_key?) do
        [%{type: type, constraints: constraints}] -> {type, constraints}
        _ -> {:string, []}
      end

    {:ok, target} =
      Builder.build_action_argument(:target_id, type,
        constraints: constraints,
        allow_nil?: true,
        public?: true,
        description:
          "The record to move before or after. Without it, the record moves to the end."
      )

    {:ok, placement} =
      Builder.build_action_argument(:placement, :atom,
        constraints: [one_of: @placements],
        allow_nil?: false,
        default: :last,
        public?: true,
        description: "Where the record goes: before or after the target, or last."
      )

    [target, placement]
  end
end
