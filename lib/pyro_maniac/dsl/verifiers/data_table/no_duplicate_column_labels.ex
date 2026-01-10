defmodule PyroManiac.Dsl.Verifiers.DataTable.NoDuplicateColumnLabels do
  @moduledoc """
  Ensures no column labels are duplicated for a given action in a data table.
  """
  use PyroManiac.Dsl.Verifiers

  alias PyroManiac.DataTable.{Action, Column}

  @impl true
  def verify(dsl) do
    module = Verifier.get_persisted(dsl, :module, nil)

    for %Action{} = action <- Verifier.get_entities(dsl, [:data_table]) do
      for {key, count} <- action.columns |> Map.values() |> count_columns() do
        case count do
          1 ->
            :ok

          count ->
            raise DslError.exception(
                    module: module,
                    path: [:data_table, :action, action.name],
                    message: "#{count} columns use the label #{inspect(key)}"
                  )
        end
      end
    end

    :ok
  end

  defp count_columns(columns, count \\ %{}) do
    Enum.reduce(columns, count, fn
      %Column{label: label}, acc ->
        Map.update(acc, label, 1, &(&1 + 1))
    end)
  end
end
