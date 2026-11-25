defmodule PyroManiac.FilterPresets.Transformers.Setup do
  @moduledoc false

  # Adds the attributes, the owner, and the actions of a filter preset
  # storage (refer to `PyroManiac.FilterPresets`).

  use Spark.Dsl.Transformer

  import Ash.Expr, only: [expr: 1, arg: 1]

  alias Ash.Resource.Builder

  @fields [:name, :page, :view, :filter, :sort, :search, :inputs, :interactive?, :shared?]

  @impl true
  def before?(Ash.Resource.Transformers.DefaultAccept), do: true
  def before?(Ash.Resource.Transformers.SetPrimaryActions), do: true
  def before?(Ash.Resource.Transformers.BelongsToAttribute), do: true
  def before?(Ash.Resource.Transformers.SetRelationshipSource), do: true
  def before?(_), do: false

  @impl true
  def transform(dsl) do
    owner = Spark.Dsl.Transformer.get_option(dsl, [:filter_presets], :owner)

    with {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :id, :uuid,
             primary_key?: true,
             allow_nil?: false,
             default: &Ash.UUID.generate/0,
             public?: true,
             writable?: false
           ),
         {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :name, :string, allow_nil?: false, public?: true),
         {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :page, :string, allow_nil?: false, public?: true),
         {:ok, dsl} <- Builder.add_new_attribute(dsl, :view, :string, public?: true),
         {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :filter, :map,
             allow_nil?: false,
             default: %{},
             public?: true
           ),
         {:ok, dsl} <- Builder.add_new_attribute(dsl, :sort, :string, public?: true),
         {:ok, dsl} <- Builder.add_new_attribute(dsl, :search, :string, public?: true),
         {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :inputs, :map,
             allow_nil?: false,
             default: %{},
             public?: true
           ),
         {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :interactive?, :boolean,
             allow_nil?: false,
             default: true,
             public?: true
           ),
         {:ok, dsl} <-
           Builder.add_new_attribute(dsl, :shared?, :boolean,
             allow_nil?: false,
             default: false,
             public?: true
           ),
         {:ok, dsl} <- Builder.add_new_create_timestamp(dsl, :inserted_at),
         {:ok, dsl} <- Builder.add_new_update_timestamp(dsl, :updated_at),
         {:ok, dsl} <- add_owner(dsl, owner) do
      add_actions(dsl, owner)
    end
  end

  defp add_owner(dsl, nil), do: {:ok, dsl}

  defp add_owner(dsl, owner),
    do: Builder.add_new_relationship(dsl, :belongs_to, :owner, owner, public?: true)

  defp add_actions(dsl, owner) do
    create_changes =
      if owner,
        do: [
          Builder.build_action_change(
            Ash.Resource.Change.Builtins.relate_actor(:owner, allow_nil?: true)
          )
        ],
        else: []

    with {:ok, create_changes} <- sequence(create_changes),
         {:ok, page_arg} <- Builder.build_action_argument(:page, :string, allow_nil?: false),
         {:ok, dsl} <- Builder.add_new_action(dsl, :read, :read, primary?: true),
         {:ok, dsl} <-
           Builder.add_new_action(dsl, :read, :for_page,
             arguments: [page_arg],
             preparations: [
               Builder.build_preparation(
                 {Ash.Resource.Preparation.Build, options: [filter: expr(page == ^arg(:page))]}
               )
             ]
           ),
         {:ok, dsl} <-
           Builder.add_new_action(dsl, :create, :create,
             primary?: true,
             accept: @fields,
             changes: create_changes
           ),
         {:ok, dsl} <-
           Builder.add_new_action(dsl, :update, :update,
             primary?: true,
             accept: @fields,
             require_atomic?: false
           ) do
      Builder.add_new_action(dsl, :destroy, :destroy, primary?: true)
    end
  end

  defp sequence(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, value}, {:ok, acc} -> {:cont, {:ok, acc ++ [value]}}
      error, _acc -> {:halt, error}
    end)
  end
end
