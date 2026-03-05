defmodule PyroManiac.Dsl.Transformers.ValidatePage do
  @moduledoc false

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Page.TenantFrom

  @ash_resource_transformers Resource.Dsl.transformers()

  @impl true
  def after?(module) when module in @ash_resource_transformers, do: true

  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)

    with :ok <- validate_route(dsl, module) do
      tenant_configs = Transformer.get_entities(dsl, [:page])

      case Enum.find(tenant_configs, &match?(%TenantFrom{}, &1)) do
        nil -> {:ok, dsl}
        config -> validate_config(config, dsl)
      end
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

  defp validate_config(%TenantFrom{mode: :scope} = config, dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)

    if config.resource || config.label_field do
      Error.raise!(
        module: module,
        location: Entity.anno(config),
        path: [:page, :tenant_from, :scope],
        why: "tenant_from :scope must not specify `resource` or `label_field`",
        fix:
          "remove `resource` and `label_field` — scope mode derives the tenant from the Ash " <>
            "scope, no tenant resource is needed"
      )
    end

    validate_page_resource_multitenancy(dsl, module)
    {:ok, dsl}
  end

  defp validate_config(%TenantFrom{mode: mode} = config, dsl) when mode in [:select, :combobox] do
    module = Transformer.get_persisted(dsl, :module, nil)

    if !config.resource do
      Error.raise!(
        module: module,
        location: Entity.anno(config),
        path: [:page, :tenant_from, mode],
        why: "tenant_from :#{mode} requires a `resource` option",
        fix: "specify the tenant resource, e.g. `tenant_from :#{mode}, resource: MyApp.Location`"
      )
    end

    if !config.label_field do
      Error.raise!(
        module: module,
        location: Entity.anno(config),
        path: [:page, :tenant_from, mode],
        why: "tenant_from :#{mode} requires a `label_field` option",
        fix: "specify the field to use as display label, e.g. `label_field :name`"
      )
    end

    validate_tenant_resource(config, dsl, module)
    validate_page_resource_multitenancy(dsl, module)
    {:ok, dsl}
  end

  defp validate_tenant_resource(config, _dsl, module) do
    tenant_resource = config.resource

    ash_postgres_info = Module.concat([:AshPostgres, :DataLayer, :Info])

    if Code.ensure_loaded?(ash_postgres_info) do
      template = ash_postgres_info.manage_tenant_template(tenant_resource)

      if !template do
        Error.raise!(
          module: module,
          location: Entity.property_anno(config, :resource) || Entity.anno(config),
          path: [:page, :tenant_from, :resource],
          why:
            "tenant resource #{inspect(tenant_resource)} does not have a `manage_tenant` " <>
              "template configured",
          fix:
            "add `manage_tenant do template [...] end` to #{inspect(tenant_resource)}'s " <>
              "postgres section"
        )
      end
    end

    if !Resource.Info.field(tenant_resource, config.label_field) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(config, :label_field) || Entity.anno(config),
        path: [:page, :tenant_from, :label_field],
        why:
          "field #{inspect(config.label_field)} does not exist on tenant resource " <>
            "#{inspect(tenant_resource)}",
        suggestions: label_field_suggestions(config.label_field, tenant_resource)
      )
    end

    :ok
  end

  defp validate_page_resource_multitenancy(dsl, module) do
    resource = Transformer.get_persisted(dsl, :resource)

    if resource do
      strategy = Resource.Info.multitenancy_strategy(resource)

      if strategy != :context do
        Error.raise!(
          module: module,
          location: Transformer.get_section_anno(dsl, [:page]),
          path: [:page, :tenant_from],
          why:
            "tenant_from requires the page resource to use `multitenancy strategy: :context`, " <>
              "but #{inspect(resource)} has multitenancy strategy: #{inspect(strategy)}",
          fix:
            "set `multitenancy do strategy :context end` on #{inspect(resource)}, or remove " <>
              "`tenant_from` from this page"
        )
      end
    end

    :ok
  end

  defp label_field_suggestions(name, resource) do
    candidates =
      resource
      |> Resource.Info.public_attributes()
      |> Enum.map(& &1.name)

    Error.did_you_mean(name, candidates)
  end
end
