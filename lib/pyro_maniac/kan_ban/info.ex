defmodule PyroManiac.KanBan.Info do
  @moduledoc """
  Introspection helpers for the `PyroManiac.KanBan` extension.
  """

  @doc "Returns the lane (group_by) field for the kanban board."
  @spec lane!(Ash.Resource.t()) :: atom()
  def lane!(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:kan_ban], :lane) ||
      raise "Resource #{inspect(resource)} does not have the PyroManiac.KanBan extension"
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

  @doc "Returns true if the resource has the PyroManiac.KanBan extension."
  @spec has_kanban?(Ash.Resource.t()) :: boolean()
  def has_kanban?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:kan_ban], :lane) != nil
  end
end
