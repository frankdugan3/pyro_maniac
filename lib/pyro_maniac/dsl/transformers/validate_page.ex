defmodule PyroManiac.Dsl.Transformers.ValidatePage do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error

  @ash_resource_transformers Resource.Dsl.transformers()

  @impl true
  def after?(module) when module in @ash_resource_transformers, do: true

  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)

    with :ok <- validate_route(dsl, module) do
      {:ok, dsl}
    end
  end

  defp validate_route(dsl, module) do
    case Transformer.get_option(dsl, [:page], :route) do
      nil ->
        :ok

      route when is_binary(route) ->
        if String.starts_with?(route, "/") do
          :ok
        else
          Error.raise!(
            module: module,
            location: Transformer.get_opt_anno(dsl, [:page], :route),
            path: [:page, :route],
            why: "route must start with `/`, got: #{inspect(route)}",
            fix: "prefix the route with `/`, e.g. `route \"/recipes\"`"
          )
        end
    end
  end
end
