defmodule PyroManiac.Resource.Info do
  @moduledoc """
  Introspection helpers for the `PyroManiac.Resource` extension.
  """

  alias PyroManiac.Resource.Expose

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

  @doc """
  The exposed actions of a resource: one `PyroManiac.Resource.Expose` for each
  action, with expanded field lists (refer to `expand_field_list/2`).
  """
  @spec exposed(Spark.Dsl.t() | Ash.Resource.t()) :: [Expose.t()]
  def exposed(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:pyro_maniac])
    |> Enum.filter(&match?(%Expose{}, &1))
    |> Enum.map(fn expose ->
      %{
        expose
        | loads: expand_field_list(resource, expose.loads, :loads),
          filter: expand_field_list(resource, expose.filter, :filter),
          sort: expand_field_list(resource, expose.sort, :sort)
      }
    end)
  end

  @doc """
  Expands a field list of `expose` for an option (`:loads`, `:filter`, or
  `:sort`): `:*` gives the fields of `public_fields/2`; a relationship atom
  gives the relationship with `:*` of its resource (one level); a
  relationship with a field list is expanded with its resource.
  """
  @spec expand_field_list(Spark.Dsl.t() | Ash.Resource.t(), term(), atom()) :: list()
  def expand_field_list(resource, list, option \\ :loads) do
    list
    |> List.wrap()
    |> Enum.flat_map(&expand_item(resource, &1, option))
    |> Enum.uniq()
  end

  defp expand_item(resource, :*, option), do: public_fields(resource, option)

  defp expand_item(resource, {name, nested}, option) when is_atom(name) and is_list(nested) do
    case Ash.Resource.Info.relationship(resource, name) do
      %{destination: destination} -> [{name, expand_field_list(destination, nested, option)}]
      nil -> [{name, nested}]
    end
  end

  defp expand_item(resource, name, option) when is_atom(name) do
    case Ash.Resource.Info.relationship(resource, name) do
      %{destination: destination} -> [{name, public_fields(destination, option)}]
      nil -> [name]
    end
  end

  defp expand_item(_resource, item, _option), do: [item]

  @doc """
  The fields of `:*` for an option: the public attributes, calculations, and
  aggregates of the resource. For `:filter`, without the fields with
  `filterable? false`; for `:sort`, without the fields with `sortable?
  false`: Ash refuses them. To keep a field (for example a password) out of
  each filter and sort, also through RPC, set `filterable? false` and
  `sortable? false` on it.
  """
  @spec public_fields(Spark.Dsl.t() | Ash.Resource.t(), atom()) :: [atom()]
  def public_fields(resource, option \\ :loads) do
    (Ash.Resource.Info.public_attributes(resource) ++
       Ash.Resource.Info.public_calculations(resource) ++
       Ash.Resource.Info.public_aggregates(resource))
    |> Enum.filter(&usable?(&1, option))
    |> Enum.map(& &1.name)
  end

  @doc """
  Whether a field can be in an option: for `:filter`, not `filterable?
  false`; for `:sort`, not `sortable? false`.
  """
  @spec usable?(struct(), atom()) :: boolean()
  def usable?(field, :filter), do: Map.get(field, :filterable?, true) != false
  def usable?(field, :sort), do: Map.get(field, :sortable?, true) != false
  def usable?(_field, _option), do: true

  @doc "The `PyroManiac.Resource.Expose` of one action, or `nil` when the action is not exposed."
  @spec exposed(Spark.Dsl.t() | Ash.Resource.t(), atom()) :: Expose.t() | nil
  def exposed(resource, action) do
    if pyro_maniac_resource?(resource) do
      Enum.find(exposed(resource), &(&1.name == action))
    end
  end

  @doc "Whether an action of a resource is exposed."
  @spec exposed?(Spark.Dsl.t() | Ash.Resource.t(), atom()) :: boolean()
  def exposed?(resource, action), do: not is_nil(exposed(resource, action))

  @doc "Whether the resource has a `realtime` section."
  @spec realtime?(Spark.Dsl.t() | Ash.Resource.t()) :: boolean()
  def realtime?(resource) do
    pyro_maniac_resource?(resource) and
      Spark.Dsl.Extension.get_persisted(resource, :pyro_maniac_realtime?, false)
  end

  @doc "The `mode` of the `realtime` section, or `nil` without the section."
  @spec realtime_mode(Spark.Dsl.t() | Ash.Resource.t()) :: :validate | :auto | nil
  def realtime_mode(resource) do
    if realtime?(resource),
      do: Spark.Dsl.Extension.get_opt(resource, [:pyro_maniac, :realtime], :mode, :validate)
  end

  @doc "The `except` of the `realtime` section."
  @spec realtime_except(Spark.Dsl.t() | Ash.Resource.t()) :: [atom()]
  def realtime_except(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:pyro_maniac, :realtime], :except, [])
  end

  @doc """
  The `bulk` of the `realtime` section: the bulk actions and the events of
  `PyroManiac.Realtime.broadcast_bulk/3`.
  """
  @spec realtime_bulk(Spark.Dsl.t() | Ash.Resource.t()) :: [atom()]
  def realtime_bulk(resource) do
    if realtime?(resource),
      do: Spark.Dsl.Extension.get_opt(resource, [:pyro_maniac, :realtime], :bulk, []),
      else: []
  end

  @doc """
  Whether a publication with a static topic sends the notifications of an
  action. `PyroManiac.SubscriptionManager` subscribes only to static topics.
  """
  @spec published?(Spark.Dsl.t() | Ash.Resource.t(), Ash.Resource.Actions.action()) ::
          boolean()
  def published?(resource, action) do
    resource
    |> Spark.Dsl.Extension.get_entities([:pub_sub])
    |> Enum.filter(&static_topic?/1)
    |> Enum.any?(&covers?(&1, action))
  end

  defp static_topic?(%{topic: topic}), do: topic |> List.wrap() |> Enum.all?(&is_binary/1)
  defp static_topic?(_), do: false

  defp covers?(%Ash.Notifier.PubSub.Publication{action: name}, action) when not is_nil(name),
    do: name == action.name

  defp covers?(%Ash.Notifier.PubSub.Publication{type: type, except: except}, action),
    do: type == action.type and action.name not in List.wrap(except)

  defp covers?(_, _), do: false

  defp pyro_maniac_resource?(resource) when is_atom(resource) do
    Ash.Resource.Info.resource?(resource) and PyroManiac.Resource in Spark.extensions(resource)
  end

  defp pyro_maniac_resource?(_dsl), do: true
end
