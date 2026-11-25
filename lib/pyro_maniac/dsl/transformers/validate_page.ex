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

    with :ok <- validate_route(dsl, module),
         :ok <- validate_filters(dsl, module),
         :ok <- validate_description(dsl, module) do
      {:ok, Transformer.persist(dsl, :page?, page?(dsl))}
    end
  end

  @doc """
  The module has a `page` section, so it is a page. Spark keeps a section in
  the DSL state only when the module uses it.
  """
  def page?(dsl), do: Map.has_key?(dsl, [:page])

  # The page has no record: its description is a text or implementations.
  defp validate_description(dsl, module) do
    for %PyroManiac.Description{kind: :expr} = entry <- Transformer.get_entities(dsl, [:page]) do
      Error.raise!(
        module: module,
        location: Entity.anno(entry),
        path: [:page, :description],
        why: "the page has no record, so its `description` is not an expression",
        fix: "use a text, or `description Renderer, implementation`"
      )
    end

    :ok
  end

  # A storage saves the filters that the user builds; sharing needs a
  # resource storage.
  defp validate_filters(dsl, module) do
    custom? = Transformer.get_option(dsl, [:page], :custom_filters?, false)
    storage = Transformer.get_option(dsl, [:page], :filter_storage)
    shared? = Transformer.get_option(dsl, [:page], :shared_filters?, false)

    cond do
      storage && not custom? ->
        filter_error(
          dsl,
          module,
          :filter_storage,
          "`filter_storage` saves the filters that the user builds, but `custom_filters?` is not `true`",
          "set `custom_filters? true`, or remove `filter_storage`"
        )

      storage && is_nil(Transformer.get_option(dsl, [:page], :delete_preset_confirm)) ->
        filter_error(
          dsl,
          module,
          :filter_storage,
          "the saved filters can be deleted, and the page does not say if the delete asks first",
          "set `delete_preset_confirm \"Delete the saved filter?\"`, or `delete_preset_confirm false`"
        )

      shared? and (is_nil(storage) or storage == :client) ->
        filter_error(
          dsl,
          module,
          :shared_filters?,
          "a shared filter is saved in a resource, so `filter_storage` names a resource with `PyroManiac.FilterPresets`",
          "set `filter_storage MyApp.FilterPreset`, or remove `shared_filters?`"
        )

      true ->
        :ok
    end
  end

  defp filter_error(dsl, module, option, why, fix) do
    Error.raise!(
      module: module,
      location: Transformer.get_opt_anno(dsl, [:page], option),
      path: [:page, option],
      why: why,
      fix: fix
    )
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
