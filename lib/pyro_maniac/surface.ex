defmodule PyroManiac.Surface do
  @moduledoc """
  The surface of a resource: what a PyroManiac page can use. Refer to
  `PyroManiac.Resource.Expose`.

  A field list (`loads`, `filter`, `sort`) is a list of atoms and
  `{relationship, field_list}` tuples. This module works with the **paths** of
  a field list: `[:name, contacts: [:email]]` gives `[[:name], [:contacts,
  :email]]`.

  A path is **covered** by a field list when it is one of the paths of the
  list, or the start of one of them. Thus `[:contacts]` (the relationship) is
  covered by `contacts: [:email]`. This is the `allowed_loads` rule of
  AshTypescript.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Resource.Expose

  @type path :: [atom()]
  @type field_list :: [atom() | {atom(), field_list()}]

  @doc """
  The paths of a field list or an Ash load statement. A load with arguments
  (`{calculation, %{...}}`, or a keyword of arguments) gives the path of the
  field only.

      iex> PyroManiac.Surface.paths([:name, contacts: [:email, phone: [:number]]])
      [[:name], [:contacts, :email], [:contacts, :phone, :number]]

      iex> PyroManiac.Surface.paths([:contacts, total: %{currency: :usd}])
      [[:contacts], [:total]]
  """
  @spec paths(term()) :: [path()]
  def paths(list), do: list |> List.wrap() |> Enum.flat_map(&item_paths/1) |> Enum.uniq()

  defp item_paths(name) when is_atom(name), do: [[name]]

  defp item_paths({name, nested}) when is_atom(name) and is_list(nested) do
    if nested != [] and Enum.all?(nested, &field_item?/1) do
      nested |> paths() |> Enum.map(&[name | &1])
    else
      [[name]]
    end
  end

  defp item_paths({name, _args}) when is_atom(name), do: [[name]]
  defp item_paths(_), do: []

  defp field_item?(name) when is_atom(name), do: true
  defp field_item?({name, nested}) when is_atom(name) and is_list(nested), do: true
  defp field_item?(_), do: false

  @doc """
  Builds a field list from paths. The inverse of `paths/1`.

      iex> PyroManiac.Surface.from_paths([[:name], [:contacts, :email], [:contacts], [:code]])
      [:code, :name, contacts: [:email]]
  """
  @spec from_paths([path()]) :: field_list()
  def from_paths(paths) do
    paths
    |> Enum.reject(&(&1 == []))
    |> Enum.group_by(&hd/1, &tl/1)
    |> Enum.map(fn {name, tails} ->
      case Enum.reject(tails, &(&1 == [])) do
        [] -> name
        nested -> {name, from_paths(nested)}
      end
    end)
    |> Enum.sort_by(fn
      name when is_atom(name) -> {0, name}
      {name, _} -> {1, name}
    end)
  end

  @doc """
  Whether a field list covers a path.

      iex> PyroManiac.Surface.covered?([:contacts], [contacts: [:email]])
      true

      iex> PyroManiac.Surface.covered?([:contacts, :phone], [contacts: [:email]])
      false
  """
  @spec covered?(path(), field_list() | [path()]) :: boolean()
  def covered?(path, list) do
    list
    |> to_paths()
    |> Enum.any?(&List.starts_with?(&1, path))
  end

  @doc "The paths of `required` that `list` does not cover."
  @spec uncovered([path()], field_list() | [path()]) :: [path()]
  def uncovered(required, list) do
    exposed = to_paths(list)
    Enum.reject(required, fn path -> Enum.any?(exposed, &List.starts_with?(&1, path)) end)
  end

  defp to_paths([[_ | _] | _] = paths), do: paths
  defp to_paths(list), do: paths(list)

  @doc """
  The first field of each path of a field list.

      iex> PyroManiac.Surface.top_level([:name, contacts: [:email]])
      [:name, :contacts]
  """
  @spec top_level(field_list()) :: [atom()]
  def top_level(list), do: list |> paths() |> Enum.map(&hd/1) |> Enum.uniq()

  @doc "The `expose` entity of an action of a resource, or `nil`."
  @spec exposed(Ash.Resource.t(), atom()) :: Expose.t() | nil
  def exposed(resource, action), do: PyroManiac.Resource.Info.exposed(resource, action)

  @doc """
  Removes the sort keys that the exposed `sort` of the action does not cover.
  Use it for a sort that a user selects. A sort is a list of `{field,
  direction}` or of fields; a key can be a string. A sort that is not a list
  is returned unchanged.
  """
  @spec restrict_sort(Ash.Resource.t(), atom(), term()) :: term()
  def restrict_sort(resource, action, sort) when is_list(sort) do
    exposed = exposed_list(resource, action, :sort)

    Enum.filter(sort, fn
      {key, _direction} -> key_covered?(key, exposed)
      key -> key_covered?(key, exposed)
    end)
  end

  def restrict_sort(_resource, _action, sort), do: sort

  @doc """
  Removes the entries of an Ash sort input string (`"name,-employee.code"`)
  that the exposed `sort` of the action does not cover. Use it for the sort
  that a user selects, before `Ash.Sort.parse_input/2`: after it, a sort on a
  relationship field is an expression, without its path. Returns `nil` when
  no entry stays.
  """
  @spec restrict_sort_input(Ash.Resource.t(), atom(), String.t() | nil) :: String.t() | nil
  def restrict_sort_input(_resource, _action, nil), do: nil

  def restrict_sort_input(resource, action, input) when is_binary(input) do
    exposed = resource |> exposed_list(action, :sort) |> paths()

    input
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(fn entry ->
      path =
        entry
        |> String.replace(~r/^[+-]+/, "")
        |> String.split(".")
        |> Enum.map(&to_existing_atom/1)

      not Enum.member?(path, nil) and path in exposed
    end)
    |> case do
      [] -> nil
      entries -> Enum.join(entries, ",")
    end
  end

  def restrict_sort_input(_resource, _action, input), do: input

  @doc """
  Removes the predicates of a filter input that the exposed `filter` of the
  action does not cover. Use it for a filter that a user selects. `and`,
  `or`, and `not` are kept, with their content restricted. A field key can
  be an atom or a string; a relationship key is followed into its map.
  """
  @spec restrict_filter(Ash.Resource.t(), atom(), term()) :: term()
  def restrict_filter(resource, action, filter) do
    exposed = exposed_list(resource, action, :filter) |> paths()
    do_restrict_filter(filter, [], exposed)
  end

  @boolean_keys ~w(and or)
  defp do_restrict_filter(filter, prefix, exposed) when is_map(filter) do
    filter
    |> Enum.flat_map(fn {key, value} ->
      key_string = to_string(key)

      cond do
        key_string in @boolean_keys and is_list(value) ->
          [{key, Enum.map(value, &do_restrict_filter(&1, prefix, exposed))}]

        key_string == "not" ->
          [{key, do_restrict_filter(value, prefix, exposed)}]

        true ->
          restrict_field(key, value, prefix, exposed)
      end
    end)
    |> Map.new()
  end

  defp do_restrict_filter(filter, _prefix, _exposed), do: filter

  defp restrict_field(key, value, prefix, exposed) do
    case to_existing_atom(key) do
      nil ->
        []

      name ->
        path = prefix ++ [name]

        cond do
          path in exposed ->
            [{key, value}]

          is_map(value) and Enum.any?(exposed, &List.starts_with?(&1, path)) ->
            [{key, do_restrict_filter(value, path, exposed)}]

          true ->
            []
        end
    end
  end

  defp key_covered?(key, exposed) do
    case to_existing_atom(key) do
      nil -> false
      name -> [name] in paths(exposed)
    end
  end

  defp exposed_list(resource, action, key) do
    case exposed(resource, action) do
      nil -> []
      expose -> Map.get(expose, key) || []
    end
  end

  defp to_existing_atom(key) when is_atom(key), do: key

  defp to_existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp to_existing_atom(_), do: nil
end
