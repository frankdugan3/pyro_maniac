defmodule PyroManiac.Resource.Info do
  @moduledoc """
  Introspection helpers for the `PyroManiac.Resource` extension.
  """

  @doc "Returns the default label field for record display."
  @spec default_label(Spark.Dsl.t() | Ash.Resource.t()) :: atom()
  def default_label(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:pyro_maniac], :default_label, nil)
  end

  @doc "Returns the default label value for a given record, rendered through Presenter."
  @spec record_label(Ash.Resource.t(), Ash.Resource.Record.t(), any()) :: String.t()
  def record_label(resource, record, scope \\ nil) do
    field = default_label(resource)
    value = field && Map.get(record, field)

    if value do
      PyroManiac.Presenter.present(value, scope)
    else
      to_string(record.id)
    end
  end
end
