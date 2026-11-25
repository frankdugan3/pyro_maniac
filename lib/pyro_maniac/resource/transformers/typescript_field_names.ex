defmodule PyroManiac.Resource.Transformers.TypescriptFieldNames do
  @moduledoc false

  # AshTypescript refuses a field name with `?` (it is not a TypeScript
  # identifier). For a resource with `AshTypescript.Resource`, each public
  # field `name?` gets the client name `is_name` (`isName` with the camel
  # case formatter) in `typescript field_names`, unless it has one. The same
  # rule for every resource of PyroManiac, so each renderer and client sees
  # the same names.

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @persist_formatted_fields AshTypescript.Resource.Transformers.PersistFormattedFields

  @impl true
  def after?(PyroManiac.FilterPresets.Transformers.Setup), do: true
  def after?(_), do: false

  @impl true
  def before?(@persist_formatted_fields), do: true
  def before?(_), do: false

  @impl true
  def transform(dsl) do
    if Code.ensure_loaded?(AshTypescript.Resource) and
         AshTypescript.Resource in Transformer.get_persisted(dsl, :extensions, []) do
      {:ok, put_field_names(dsl)}
    else
      {:ok, dsl}
    end
  end

  defp put_field_names(dsl) do
    written = Transformer.get_option(dsl, [:typescript], :field_names) || []
    formatter = AshTypescript.Rpc.output_field_formatter()

    added =
      for field <- question_fields(dsl), not Keyword.has_key?(written, field) do
        {field, client_name(field, formatter)}
      end

    case added do
      [] -> dsl
      added -> Transformer.set_option(dsl, [:typescript], :field_names, written ++ added)
    end
  end

  @doc false
  # `late?` gives `is_late`, `is_active?` gives `is_active`, in the format of
  # the client.
  def client_name(field, formatter) do
    base = field |> Atom.to_string() |> String.trim_trailing("?")
    name = if String.starts_with?(base, "is_"), do: base, else: "is_" <> base
    AshTypescript.FieldFormatter.format_field_name(name, formatter)
  end

  defp question_fields(dsl) do
    [
      Ash.Resource.Info.public_attributes(dsl),
      Ash.Resource.Info.public_calculations(dsl),
      Ash.Resource.Info.public_aggregates(dsl)
    ]
    |> Enum.concat()
    |> Enum.map(& &1.name)
    |> Enum.filter(&String.ends_with?(Atom.to_string(&1), "?"))
    |> Enum.uniq()
  end
end
