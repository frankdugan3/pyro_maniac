defmodule PyroManiac.DataLoader do
  @moduledoc """
  Shared data loading logic for PyroManiac components.

  Provides `load_list/3` and `load_record/3` to centralize Ash query
  construction, filtering, sorting, pagination, and result normalization.
  """

  @type load_result :: %{
          entries: list(),
          error: term() | nil,
          page: Ash.Page.Offset.t() | Ash.Page.Keyset.t() | nil
        }

  @doc """
  Load a list of records for an index view.

  ## Opts

  - `:scope` — Ash scope (required)
  - `:action_name` — read action name (default: primary read)
  - `:arguments` — map of action arguments passed to `Ash.Query.for_read/4`
  - `:sort` — Ash sort list
  - `:loads` — fields to load on the query
  - `:filter` — filter map passed to `Ash.Query.filter_input/2` — pulled from URL params or scoped by callers (e.g. `%{vendor_id: id}` or `%{"name" => %{"contains" => "ipa"}}`)
  - `:page_params` — map of pagination params (`"offset"`, `"limit"`, `"after"`, `"before"`)
  - `:pagination_config` — action pagination struct/map
  - `:default_page_size` — DSL default page size override
  """
  @spec load_list(module(), atom(), map()) :: load_result()
  def load_list(resource, action_name, opts \\ %{}) do
    scope = opts[:scope]
    arguments = opts[:arguments] || %{}
    filter = opts[:filter]
    sort = opts[:sort] || []
    loads = opts[:loads] || []
    aggregates = opts[:aggregates] || []
    page_params = opts[:page_params] || %{}
    pagination_config = opts[:pagination_config]
    default_page_size = opts[:default_page_size]

    action = Ash.Resource.Info.action(resource, action_name)
    resolved_pagination = pagination_config || (action && action.pagination)

    query =
      resource
      |> Ash.Query.for_read(action_name, arguments, scope: scope)
      |> maybe_apply_filter(filter)
      |> maybe_apply_sort(sort)
      |> maybe_apply_loads(loads)
      |> maybe_apply_aggregates(aggregates)

    query
    |> execute_read(resolved_pagination, page_params, default_page_size, scope)
    |> normalize_result()
  end

  defp execute_read(query, %{offset?: true} = pagination, page_params, default_page_size, scope) do
    Ash.read(query,
      page: build_page_opts(page_params, pagination, default_page_size),
      scope: scope
    )
  end

  defp execute_read(query, %{keyset?: true} = pagination, page_params, default_page_size, scope) do
    Ash.read(query,
      page: build_page_opts(page_params, pagination, default_page_size),
      scope: scope
    )
  end

  defp execute_read(query, _pagination, _page_params, _default_page_size, scope) do
    Ash.read(query, scope: scope)
  end

  defp normalize_result({:ok, %Ash.Page.Offset{} = page}),
    do: %{entries: page.results, error: nil, page: page}

  defp normalize_result({:ok, %Ash.Page.Keyset{} = page}),
    do: %{entries: page.results, error: nil, page: page}

  defp normalize_result({:ok, entries}) when is_list(entries),
    do: %{entries: entries, error: nil, page: nil}

  defp normalize_result({:error, error}), do: %{entries: [], error: error, page: nil}

  @doc """
  Load a single record by primary key.
  """
  @spec load_record(module(), term(), term()) :: struct() | nil
  def load_record(resource, id, scope) do
    [pk_field | _] = Ash.Resource.Info.primary_key(resource)
    filter = %{pk_field => id}
    label_loads = PyroManiac.Info.default_label_load(resource)

    resource
    |> Ash.Query.filter_input(filter)
    |> Ash.Query.load(label_loads)
    |> Ash.read_one(scope: scope)
    |> case do
      {:ok, record} -> record
      {:error, _} -> nil
    end
  end

  @doc """
  Execute an Ash create/update/destroy action.

  ## Opts

  - `:scope` — Ash scope
  """
  @spec run_action(module(), atom(), map(), map()) :: {:ok, struct()} | {:error, term()}
  def run_action(resource, action_name, params, opts \\ %{}) do
    scope = opts[:scope]
    action = Ash.Resource.Info.action(resource, action_name)

    case action.type do
      :create ->
        resource
        |> Ash.Changeset.for_create(action_name, params, scope: scope)
        |> Ash.create()

      :update ->
        record = params[:__record__] || raise "run_action :update requires :__record__ in params"
        attrs = Map.delete(params, :__record__)

        record
        |> Ash.Changeset.for_update(action_name, attrs, scope: scope)
        |> Ash.update()

      :destroy ->
        record = params[:__record__] || raise "run_action :destroy requires :__record__ in params"

        record
        |> Ash.Changeset.for_destroy(action_name, %{}, scope: scope)
        |> Ash.destroy()
    end
  end

  defp maybe_apply_filter(query, nil), do: query
  defp maybe_apply_filter(query, filter) when filter == %{}, do: query
  defp maybe_apply_filter(query, filter), do: Ash.Query.filter_input(query, filter)

  defp maybe_apply_sort(query, []), do: query
  defp maybe_apply_sort(query, sort), do: Ash.Query.sort(query, sort)

  defp maybe_apply_loads(query, []), do: query
  defp maybe_apply_loads(query, loads), do: Ash.Query.load(query, loads)

  defp maybe_apply_aggregates(query, []), do: query

  defp maybe_apply_aggregates(query, aggregates) do
    Enum.reduce(aggregates, query, fn agg, q ->
      Map.update!(q, :aggregates, &Map.put(&1, agg.name, agg))
    end)
  end

  defp build_page_opts(page_params, pagination_config, dsl_default_page_size) do
    default_limit =
      dsl_default_page_size ||
        get_pagination_field(pagination_config, :default_limit, 25)

    limit = parse_int(page_params["limit"]) || default_limit

    opts = [limit: limit]

    opts =
      if page_params["after"] || page_params["before"] do
        opts
      else
        offset = parse_int(page_params["offset"]) || 0
        Keyword.put(opts, :offset, offset)
      end

    opts =
      if page_params["after"] do
        Keyword.put(opts, :after, page_params["after"])
      else
        opts
      end

    opts =
      if page_params["before"] do
        Keyword.put(opts, :before, page_params["before"])
      else
        opts
      end

    if get_pagination_field(pagination_config, :countable) do
      Keyword.put(opts, :count, true)
    else
      opts
    end
  end

  defp get_pagination_field(config, field, default),
    do: get_pagination_field(config, field) || default

  defp get_pagination_field(config, field) when is_struct(config), do: Map.get(config, field)
  defp get_pagination_field(config, field) when is_map(config), do: Map.get(config, field)

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
end
