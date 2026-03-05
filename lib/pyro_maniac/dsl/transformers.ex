defmodule PyroManiac.Dsl.Transformers do
  @moduledoc false

  @doc """
  Get the Ash resource actions for an PyroManiac DSL.
  """
  def get_resource_actions(dsl) do
    dsl
    |> Spark.Dsl.Transformer.get_persisted(:resource)
    |> Ash.Resource.Info.actions()
  end

  @doc """
  Get the type of a Ash resource field for an PyroManiac DSL. Used to determine how to render it in the UI.
  """
  def resource_field_type(resource, field_name) do
    resource
    |> Ash.Resource.Info.field(field_name)
    |> case do
      %Ash.Resource.Attribute{} -> :attribute
      %Ash.Resource.Aggregate{} -> :aggregate
      %Ash.Resource.Calculation{} -> :calculation
      %Ash.Resource.Relationships.HasOne{} -> :has_one
      %Ash.Resource.Relationships.BelongsTo{} -> :belongs_to
      %Ash.Resource.Relationships.HasMany{} -> :has_many
      %Ash.Resource.Relationships.ManyToMany{} -> :many_to_many
    end
  end

  @doc """
  Inherit a value from another enitity by name.
  """
  def inherit_pyro_config(dsl, kind, entity_name, key, default \\ nil)

  def inherit_pyro_config(dsl, path, entity_name, key, default) when is_list(path) do
    dsl
    |> Spark.Dsl.Transformer.get_entities(path)
    |> Enum.find(&(&1.name == entity_name))
    |> get_nested(List.wrap(key), default)
  end

  def inherit_pyro_config(dsl, kind, entity_name, key, default) when kind in [:forms] do
    inherit_pyro_config(dsl, [:forms], entity_name, key, default)
  end

  def inherit_pyro_config(dsl, kind, entity_name, key, default) when kind in [:data_tables] do
    inherit_pyro_config(dsl, [:data_tables], entity_name, key, default)
  end

  def inherit_pyro_config(dsl, kind, entity_name, key, default) when kind in [:cards] do
    inherit_pyro_config(dsl, [:cards], entity_name, key, default)
  end

  @doc """
  Safely get nested values from maps or keyword lists that may be `nil` or an otherwise non-map value at any point. Great for accessing nested assigns in a template.

  ## Examples

      iex> get_nested(nil, [:one, :two, :three])
      nil

      iex> get_nested(%{one: nil}, [:one, :two, :three])
      nil

      iex> get_nested(%{one: %{two: %{three: 3}}}, [:one, :two, :three])
      3

      iex> get_nested(%{one: %{two: [three: 3]}}, [:one, :two, :three])
      3

      iex> get_nested([one: :nope], [:one, :two, :three])
      nil

      iex> get_nested([one: :nope], [:one, :two, :three], :default)
      :default
  """
  def get_nested(value, keys, default \\ nil)
  def get_nested(value, [], _), do: value
  def get_nested(%{} = map, [key], default), do: Map.get(map, key, default)

  def get_nested(%{} = map, [key | keys], default),
    do: get_nested(Map.get(map, key), keys, default)

  def get_nested([_ | _] = keyword, [key], default), do: Keyword.get(keyword, key, default)

  def get_nested([_ | _] = keyword, [key | keys], default),
    do: get_nested(Keyword.get(keyword, key), keys, default)

  def get_nested(_, _, default), do: default

  @doc """
  Extract a default humanized label from an entity name.
  """
  def default_label(%{name: name}), do: default_label(name)
  def default_label(name) when is_atom(name), do: default_label(Atom.to_string(name))

  def default_label(name) when is_binary(name),
    do: name |> String.split("_") |> Enum.map_join(" ", &String.capitalize/1)

  @doc """
  Preserve path context when merging nested entities.
  """
  def maybe_append_path(root, []), do: root
  def maybe_append_path(root, path) when not is_nil(path), do: root ++ List.wrap(path)

  defmacro __using__(_env) do
    quote do
      use Spark.Dsl.Transformer

      import unquote(__MODULE__)

      alias Ash.Resource
      alias Spark.Dsl.Entity
      alias Spark.Dsl.Transformer
      alias Spark.Error.DslError
    end
  end
end
