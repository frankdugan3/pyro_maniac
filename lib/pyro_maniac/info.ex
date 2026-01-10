defmodule PyroManiac.Info do
  @moduledoc """
  Helpers to introspect `PyroManiac` modules. Intended for use in components that automatically build UI from resource configuration.
  """

  alias Ash.Resource.Relationships.{BelongsTo, HasMany, HasOne, ManyToMany}
  alias Ash.Resource.{Aggregate, Attribute, Calculation, Info}
  alias PyroManiac.Dsl.DataTable
  alias PyroManiac.Form.Action
  alias Spark.Dsl.Extension

  @doc """
  Returns the form fields defined in the `PyroManiac.Dsl` extension for the given action.

  ## Examples

      iex> form_for(PyroManiac.InfoTest.UserPage, :create) |> Map.get(:fields) |> Enum.map(& &1.label)
      ["Primary Info", "Authorization", "Friendships", "Notes"]
  """
  @spec form_for(PyroManiac.t(), atom()) :: Action.t() | nil
  def form_for(pyro_maniac, action_name) do
    pyro_maniac
    |> Extension.get_entities([:form])
    |> Enum.find(fn action ->
      action.name == action_name
    end)
  end

  @doc """
  Returns the data table defined in the `PyroManiac.Dsl` extension for the given action.

  ## Examples

      iex> data_table_for(PyroManiac.InfoTest.UserPage, :list) |> Map.get(:name)
      :list
  """
  @spec data_table_for(PyroManiac.t(), atom()) :: DataTable | nil
  def data_table_for(pyro_maniac, action_name) do
    pyro_maniac
    |> Extension.get_persisted(:data_table_actions_by_name, %{})
    |> Map.get(action_name)
  end

  @doc """
  Get a resource via a path from starting resource.
  """
  @spec resource_by_path(Ash.Resource.t(), [atom() | binary()]) :: Ash.Resource.t()
  def resource_by_path(resource, []), do: resource

  def resource_by_path(resource, [relationship | rest]) do
    case Info.field(resource, relationship) do
      %Aggregate{} ->
        resource

      %Calculation{} ->
        resource

      %Attribute{} ->
        resource

      %BelongsTo{destination: destination} ->
        resource_by_path(destination, rest)

      %HasOne{destination: destination} ->
        resource_by_path(destination, rest)

      %HasMany{destination: destination} ->
        resource_by_path(destination, rest)

      %ManyToMany{destination: destination} ->
        resource_by_path(destination, rest)
    end
  end
end
