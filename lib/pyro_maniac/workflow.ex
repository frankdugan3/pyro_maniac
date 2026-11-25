defmodule PyroManiac.Workflow do
  @moduledoc """
  The workflow of a resource for the `workflow` node of a record tree
  (`PyroManiac.Form.Workflow`): [AshWorkflow](https://hex.pm/packages/ash_workflow)
  or [AshStateMachine](https://hexdocs.pm/ash_state_machine). Both are
  optional: PyroManiac does not depend on them.
  """
  @moduledoc group: "PyroManiac"

  @ash_workflow_loads [:current_step, :steps, :available_actions, :pending_deadlines]

  @doc """
  The workflow extension of a resource: `:ash_workflow`,
  `:ash_state_machine`, or `nil`. AshWorkflow adds AshStateMachine, so it
  comes first.
  """
  @spec engine(Ash.Resource.t()) :: :ash_workflow | :ash_state_machine | nil
  def engine(resource) do
    extensions = Spark.extensions(resource)

    cond do
      AshWorkflow in extensions -> :ash_workflow
      AshStateMachine in extensions -> :ash_state_machine
      true -> nil
    end
  rescue
    _ -> nil
  end

  @doc "The state attribute of a resource with a state machine, or `nil`."
  @spec state_attribute(Ash.Resource.t()) :: atom() | nil
  def state_attribute(resource) do
    if engine(resource),
      do: state_machine_info().state_machine_state_attribute!(resource)
  rescue
    _ -> nil
  end

  @doc "The states of the state machine of a resource, or `[]`."
  @spec states(Ash.Resource.t()) :: [atom()]
  def states(resource) do
    if engine(resource),
      do: state_machine_info().state_machine_all_states(resource),
      else: []
  rescue
    _ -> []
  end

  @doc """
  The fields that the `workflow` node loads: the state, and with AshWorkflow
  its calculations (`:current_step`, `:steps`, `:available_actions`,
  `:pending_deadlines`) that the resource has.
  """
  @spec loads(Ash.Resource.t()) :: [atom()]
  def loads(resource) do
    state = List.wrap(state_attribute(resource))

    calculations =
      if engine(resource) == :ash_workflow,
        do: Enum.filter(@ash_workflow_loads, &Ash.Resource.Info.calculation(resource, &1)),
        else: []

    state ++ calculations
  end

  # A variable module: AshStateMachine is optional, so it is not a
  # compile-time reference.
  defp state_machine_info, do: Module.concat([AshStateMachine, Info])
end
