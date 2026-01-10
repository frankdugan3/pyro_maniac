defmodule PyroManiac.Dsl.Verifiers.DataTable.DefaultDisplaysValid do
  @moduledoc """
  Ensure all actions have a valid default display.
  """
  use PyroManiac.Dsl.Verifiers

  alias PyroManiac.DataTable.Action

  @impl true
  def verify(dsl) do
    context = %{
      dsl: dsl,
      module: Verifier.get_persisted(dsl, :module, nil),
      resource: Verifier.get_persisted(dsl, :resource, nil)
    }

    for %Action{} = action <- Verifier.get_entities(dsl, [:data_table]) do
      columns =
        action.columns
        |> Map.values()
        |> MapSet.new(& &1.name)

      if Enum.empty?(action.default_display) do
        raise DslError.exception(
                module: context.module,
                path: [:data_table, :action, action.name, :default_display],
                message: "must display at least one column by default"
              )
      end

      for column <- action.default_display do
        if !MapSet.member?(columns, column) do
          raise DslError.exception(
                  module: context.module,
                  path: [:data_table, :action, action.name, :default_display],
                  message: "#{inspect(column)} is an undefined or excluded column"
                )
        end
      end
    end

    :ok
  end
end
