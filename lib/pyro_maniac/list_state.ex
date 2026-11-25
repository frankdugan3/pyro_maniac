defmodule PyroManiac.ListState do
  @moduledoc """
  The state of a list view: its filter, sort, search, and page. Every
  renderer uses this one encoding: in the URL, in the filter presets
  (`PyroManiac.FilterPresets`), and in the client storage (`filter_storage
  :client`). The renderer shows the state and changes it (the chips, the
  filter builder, the sort controls, the pager); PyroManiac encodes,
  decodes, validates, and applies it.

  ## Values

  - `filter`: an Ash filter input in map form, with string keys:
    `%{"status" => %{"eq" => "active"}}`. Refer to `PyroManiac.FilterChips`.
  - `sort`: an Ash sort input string: `"-inserted_at,name"`. The prefix of a
    field is its order: none or `+` ascending, `-` descending, `++`
    ascending with `nil` first, `--` descending with `nil` last. A field of
    a relationship is a path: `"recipe.name"`.
  - `search`: the name of a `search` of the page. `inputs`: the values of
    its fields, with string keys. A field without a value uses its `value`.
  - `page`: the page number (from 1), or `after` / `before`: the keyset of
    a page. `limit`: the page size.

  ## URL parameters

  | Key  | Value               | Example                      |
  | ---- | ------------------- | ---------------------------- |
  | `f`  | `filter`, JSON      | `{"status":{"eq":"active"}}` |
  | `s`  | `sort`              | `-inserted_at,name`          |
  | `q`  | `search`            | `by_name`                    |
  | `qi` | `inputs`, JSON      | `{"name":"pale"}`            |
  | `p`  | `page`              | `2`                          |
  | `af` | `after`             | a keyset                     |
  | `bf` | `before`            | a keyset                     |
  | `ps` | `limit`             | `25`                         |

      iex> state = %PyroManiac.ListState{filter: %{"status" => %{"eq" => "active"}}, sort: "-name", page: 2}
      iex> PyroManiac.ListState.encode(state)
      %{"f" => ~s({"status":{"eq":"active"}}), "p" => "2", "s" => "-name"}
      iex> state |> PyroManiac.ListState.encode() |> PyroManiac.ListState.decode() == state
      true

  `encode/1` leaves out the empty values; `decode/1` leaves out the values
  that it cannot read. A renderer with several lists in one URL puts the
  parameters of each list under its own key (for example `v[orders]`).

  A new filter, sort, search, or page size goes back to the first page
  (`put/3`).

  ## Applying the state

  `query/3` restricts the filter and the sort to the exposed `filter` and
  `sort` of the read action (`PyroManiac.Surface`), adds the filter of the
  search, and gives them to `Ash.Query.filter_input/2` and
  `Ash.Query.sort_input/2`. Ash validates them; an invalid filter or sort
  is an error of the query. `validate/3` gives the errors for each value
  before the read, to show them next to the filter or the sort.
  `page_opts/2` gives the `page` option of `Ash.read/2`.
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Search.Search
  alias PyroManiac.Surface
  alias PyroManiac.View.View

  defstruct [:filter, :sort, :search, :page, :after, :before, :limit, inputs: %{}]

  @type t :: %__MODULE__{
          filter: map() | nil,
          sort: String.t() | nil,
          search: String.t() | nil,
          inputs: map(),
          page: pos_integer() | nil,
          after: String.t() | nil,
          before: String.t() | nil,
          limit: pos_integer() | nil
        }

  @type order :: :asc | :desc | :asc_nils_first | :desc_nils_last

  @position [:page, :after, :before]
  @resets [:filter, :sort, :search, :inputs, :limit]

  ## Encoding

  @doc "The URL parameters of a state (refer to the module documentation)."
  @spec encode(t()) :: %{String.t() => String.t()}
  def encode(%__MODULE__{} = state) do
    [
      {"f", json(state.filter)},
      {"s", state.sort},
      {"q", state.search},
      {"qi", json(state.inputs)},
      {"p", state.page && Integer.to_string(state.page)},
      {"af", state.after},
      {"bf", state.before},
      {"ps", state.limit && Integer.to_string(state.limit)}
    ]
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  @doc """
  The state of URL parameters. The values that it cannot read are left
  out.

      iex> PyroManiac.ListState.decode(%{"s" => "name", "p" => "x", "f" => "{"})
      %PyroManiac.ListState{sort: "name"}
  """
  @spec decode(map() | nil) :: t()
  def decode(params) when is_map(params) do
    %__MODULE__{
      filter: params |> Map.get("f") |> decode_json(),
      sort: params |> Map.get("s") |> string(),
      search: params |> Map.get("q") |> string(),
      inputs: decode_json(Map.get(params, "qi")) || %{},
      page: params |> Map.get("p") |> positive_integer(),
      after: params |> Map.get("af") |> string(),
      before: params |> Map.get("bf") |> string(),
      limit: params |> Map.get("ps") |> positive_integer()
    }
  end

  def decode(_params), do: %__MODULE__{}

  @doc """
  Sets a value of the state. A new `filter`, `sort`, `search`, `inputs`, or
  `limit` goes back to the first page. A new `page`, `after`, or `before`
  clears the two others: they are alternatives for the position.

      iex> state = %PyroManiac.ListState{page: 3, sort: "name"}
      iex> PyroManiac.ListState.put(state, :sort, "-name")
      %PyroManiac.ListState{sort: "-name"}
      iex> PyroManiac.ListState.put(state, :after, "g3Q")
      %PyroManiac.ListState{sort: "name", after: "g3Q"}
  """
  @spec put(t(), atom(), term()) :: t()
  def put(%__MODULE__{} = state, key, value) when key in @resets do
    state
    |> Map.put(key, normalize(key, value))
    |> Map.merge(%{page: nil, after: nil, before: nil})
  end

  def put(%__MODULE__{} = state, key, value) when key in @position do
    state
    |> Map.merge(%{page: nil, after: nil, before: nil})
    |> Map.put(key, value)
  end

  defp normalize(:filter, filter) when filter == %{}, do: nil
  defp normalize(:filter, filter) when is_map(filter), do: stringify(filter)
  defp normalize(:inputs, nil), do: %{}
  defp normalize(:inputs, inputs) when is_map(inputs), do: stringify(inputs)

  defp normalize(:search, search) when is_atom(search) and not is_nil(search),
    do: to_string(search)

  defp normalize(:sort, ""), do: nil
  defp normalize(_key, value), do: value

  ## Sort

  @doc """
  The fields and orders of a sort input.

      iex> PyroManiac.ListState.parse_sort("-inserted_at,name,--recipe.name")
      [{"inserted_at", :desc}, {"name", :asc}, {"recipe.name", :desc_nils_last}]
  """
  @spec parse_sort(String.t() | nil) :: [{String.t(), order()}]
  def parse_sort(nil), do: []

  def parse_sort(sort) when is_binary(sort) do
    sort
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn
      "++" <> field -> {field, :asc_nils_first}
      "--" <> field -> {field, :desc_nils_last}
      "+" <> field -> {field, :asc}
      "-" <> field -> {field, :desc}
      field -> {field, :asc}
    end)
  end

  @doc """
  The sort input of fields and orders, or `nil` without a field.

      iex> PyroManiac.ListState.encode_sort([{"inserted_at", :desc}, {:name, :asc}])
      "-inserted_at,name"
  """
  @spec encode_sort([{String.t() | atom(), order()}]) :: String.t() | nil
  def encode_sort([]), do: nil

  def encode_sort(sort) when is_list(sort) do
    Enum.map_join(sort, ",", fn {field, order} -> prefix(order) <> to_string(field) end)
  end

  defp prefix(:asc), do: ""
  defp prefix(:desc), do: "-"
  defp prefix(:asc_nils_first), do: "++"
  defp prefix(:desc_nils_last), do: "--"

  @doc """
  The order of a field in the sort of a state, or `nil` (not sorted). For
  example, for `aria-sort`.

      iex> PyroManiac.ListState.sort_order(%PyroManiac.ListState{sort: "-name"}, :name)
      :desc
  """
  @spec sort_order(t(), String.t() | atom()) :: order() | nil
  def sort_order(%__MODULE__{sort: sort}, field) do
    field = to_string(field)
    Enum.find_value(parse_sort(sort), fn {name, order} -> if name == field, do: order end)
  end

  @doc """
  The state after a click on the sort control of a field: ascending, then
  descending, then not sorted. Without `multi?: true`, the field replaces
  the sort; with it, the field keeps its position among the other fields
  (a new field goes last).

      iex> state = %PyroManiac.ListState{sort: "name"}
      iex> PyroManiac.ListState.toggle_sort(state, :name).sort
      "-name"
      iex> PyroManiac.ListState.toggle_sort(%PyroManiac.ListState{sort: "-name"}, :name).sort
      nil
      iex> PyroManiac.ListState.toggle_sort(state, :style, multi?: true).sort
      "name,style"
  """
  @spec toggle_sort(t(), String.t() | atom(), keyword()) :: t()
  def toggle_sort(%__MODULE__{} = state, field, opts \\ []) do
    field = to_string(field)
    next = next_order(sort_order(state, field))

    sort =
      if Keyword.get(opts, :multi?, false),
        do: multi_sort(parse_sort(state.sort), field, next),
        else: List.wrap(next && {field, next})

    put(state, :sort, encode_sort(sort))
  end

  defp next_order(nil), do: :asc
  defp next_order(order) when order in [:asc, :asc_nils_first], do: :desc
  defp next_order(_desc), do: nil

  defp multi_sort(sort, field, next) do
    cond do
      not List.keymember?(sort, field, 0) -> sort ++ [{field, next}]
      next -> List.keyreplace(sort, field, 0, {field, next})
      true -> List.keydelete(sort, field, 0)
    end
  end

  @doc """
  Whether the state is sorted by `attribute` ascending, and by nothing
  else. A `reorder?` view enables the reorder only then.

      iex> PyroManiac.ListState.sorted_by?(%PyroManiac.ListState{sort: "position"}, :position)
      true
      iex> PyroManiac.ListState.sorted_by?(%PyroManiac.ListState{sort: "position,name"}, :position)
      false
  """
  @spec sorted_by?(t(), atom() | String.t()) :: boolean()
  def sorted_by?(%__MODULE__{sort: sort}, attribute),
    do: parse_sort(sort) == [{to_string(attribute), :asc}]

  ## Search

  @doc """
  The filter input of a `search` with the values of its fields (string
  keys), or `nil` when every field is blank. A field without a value uses
  its `value`.

  The predicate of a field is `%{operator => value}` at the end of each
  `source` path, joined with `or`. When the operator is a calculation with
  arguments at the end of the path, the value is its first argument:
  `%{calculation => %{"eq" => true, "input" => %{argument => value}}}`. A
  field with `negated?: true` is `%{"not" => predicate}`. The predicates of
  the fields are joined with the `operator` of the search.
  """
  @spec search_filter(Search.t(), Ash.Resource.t() | nil, map()) :: map() | nil
  def search_filter(%Search{} = search, resource, inputs \\ %{}) do
    predicates =
      Enum.flat_map(search.fields, fn field ->
        value = field_value(field, inputs || %{})
        if blank?(value), do: [], else: [field_predicate(field, resource, value)]
      end)

    case predicates do
      [] -> nil
      [single] -> single
      many -> %{to_string(search.operator || :and) => many}
    end
  end

  defp field_value(field, inputs) do
    case Map.fetch(inputs, to_string(field.name)) do
      {:ok, value} -> value
      :error -> Map.get(inputs, field.name, field.value)
    end
  end

  # `negated?` negates the predicate of the field: `not (a or b)` keeps the
  # records for which no source matches.
  defp field_predicate(field, resource, value) do
    operator = field.operator || :contains

    predicate =
      case Enum.map(
             field.source || [field.name],
             &source_predicate(&1, resource, operator, value)
           ) do
        [single] -> single
        many -> %{"or" => many}
      end

    if field.negated?, do: %{"not" => predicate}, else: predicate
  end

  defp source_predicate(source, resource, operator, value) do
    path = List.wrap(source)
    leaf = %{to_string(operator) => leaf_value(destination(resource, path), operator, value)}

    path
    |> Enum.reverse()
    |> Enum.reduce(leaf, fn key, acc -> %{to_string(key) => acc} end)
  end

  defp destination(nil, _path), do: nil

  defp destination(resource, path) do
    Enum.reduce_while(path, resource, fn name, current ->
      case Ash.Resource.Info.relationship(current, name) do
        nil -> {:halt, current}
        relationship -> {:cont, relationship.destination}
      end
    end)
  end

  defp leaf_value(nil, _operator, value), do: value

  defp leaf_value(resource, operator, value) do
    case Ash.Resource.Info.calculation(resource, operator) do
      %{arguments: [%{name: argument} | _]} ->
        %{"eq" => true, "input" => %{to_string(argument) => value}}

      _calculation ->
        value
    end
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  @doc """
  The full filter input of a state on a page: the `filter`, and the filter
  of its `search`, joined with `and`. `nil` without either.
  """
  @spec filter(t(), module() | nil, Ash.Resource.t()) :: map() | nil
  def filter(%__MODULE__{} = state, page, resource) do
    search =
      with name when is_binary(name) <- state.search,
           %Search{} = search <- find_search(page, name) do
        search_filter(search, resource, state.inputs)
      else
        _no_search -> nil
      end

    case Enum.reject([state.filter, search], &(&1 in [nil, %{}])) do
      [] -> nil
      [filter] -> filter
      filters -> %{"and" => filters}
    end
  end

  defp find_search(nil, _name), do: nil

  defp find_search(page, name),
    do: Enum.find(PyroManiac.Info.searches(page), &(to_string(&1.name) == name))

  ## Applying

  @doc """
  Applies the filter and the sort of a state to a read query. The filter
  and the sort are restricted to the exposed `filter` and `sort` of the
  read action (the action of the query, or `opts[:action]`).

  Options:

  - `page`: the page module, for its searches.
  - `action`: the read action, when the query has none.
  """
  @spec query(Ash.Query.t(), t(), keyword()) :: Ash.Query.t()
  def query(%Ash.Query{resource: resource} = query, %__MODULE__{} = state, opts \\ []) do
    action = action_name(query, opts)

    filter =
      case filter(state, opts[:page], resource) do
        nil -> nil
        filter -> Surface.restrict_filter(resource, action, filter)
      end

    query = if filter in [nil, %{}], do: query, else: Ash.Query.filter_input(query, filter)

    case Surface.restrict_sort_input(resource, action, state.sort) do
      nil -> query
      sort -> Ash.Query.sort_input(query, sort)
    end
  end

  @doc """
  The errors of the filter and the sort of a state on a read action:
  `:ok`, or `{:error, errors}` with `{:filter | :sort, message}`. A value
  that the action does not expose is an error too: `query/3` drops it.
  The fields, the operators, and the sort orders are checked; the values
  are cast at the read, so an invalid value is an error of the read.
  Options: `page`.
  """
  @spec validate(t(), Ash.Resource.t(), atom(), keyword()) ::
          :ok | {:error, [{:filter | :sort, String.t()}]}
  def validate(%__MODULE__{} = state, resource, action, opts \\ []) do
    errors = filter_errors(state, resource, action, opts) ++ sort_errors(state, resource, action)
    if errors == [], do: :ok, else: {:error, errors}
  end

  defp filter_errors(state, resource, action, opts) do
    case filter(state, opts[:page], resource) do
      nil ->
        []

      filter ->
        restricted = Surface.restrict_filter(resource, action, filter)

        cond do
          restricted != filter ->
            [{:filter, "the filter uses a field that #{inspect(action)} does not expose"}]

          match?({:ok, _}, Ash.Filter.parse_input(resource, filter)) ->
            []

          true ->
            {:error, error} = Ash.Filter.parse_input(resource, filter)
            [{:filter, message(error)}]
        end
    end
  end

  defp sort_errors(%{sort: nil}, _resource, _action), do: []

  defp sort_errors(%{sort: sort}, resource, action) do
    restricted = Surface.restrict_sort_input(resource, action, sort)

    cond do
      restricted != Enum.map_join(String.split(sort, ",", trim: true), ",", &String.trim/1) ->
        [{:sort, "the sort uses a field that #{inspect(action)} does not expose"}]

      match?({:ok, _}, Ash.Sort.parse_input(resource, sort)) ->
        []

      true ->
        {:error, error} = Ash.Sort.parse_input(resource, sort)
        [{:sort, message(error)}]
    end
  end

  defp message(error) when is_exception(error), do: Exception.message(error)
  defp message(error), do: inspect(error)

  @doc """
  The `page` option of `Ash.read/2` for a state: the `limit` (else
  `default_limit`), and the `offset` of the page number or the keyset.

      iex> PyroManiac.ListState.page_opts(%PyroManiac.ListState{page: 3}, 25)
      [limit: 25, offset: 50]
      iex> PyroManiac.ListState.page_opts(%PyroManiac.ListState{after: "g3Q", limit: 10}, 25)
      [limit: 10, after: "g3Q"]
  """
  @spec page_opts(t(), pos_integer()) :: keyword()
  def page_opts(%__MODULE__{} = state, default_limit) do
    limit = state.limit || default_limit

    cond do
      state.after -> [limit: limit, after: state.after]
      state.before -> [limit: limit, before: state.before]
      state.page && state.page > 1 -> [limit: limit, offset: (state.page - 1) * limit]
      true -> [limit: limit]
    end
  end

  defp action_name(%Ash.Query{action: %{name: name}}, _opts), do: name

  defp action_name(_query, opts) do
    opts[:action] ||
      raise ArgumentError, "the query has no read action: give it, or the `action` option"
  end

  ## Presets

  @doc """
  The key of a page in the presets and the client storage: the name of its
  module.

      iex> PyroManiac.ListState.page_key(BreweryWeb.RecipePage)
      "BreweryWeb.RecipePage"
  """
  @spec page_key(module()) :: String.t()
  def page_key(page) when is_atom(page), do: inspect(page)

  @doc """
  The key of a view in the presets and the client storage: its action and
  its type (a page has one view of each), or `nil` for each list view of
  the page.

      iex> PyroManiac.ListState.view_key(%PyroManiac.View.View{name: [:read], type: :data_table})
      "read:data_table"
  """
  @spec view_key(View.t() | nil) :: String.t() | nil
  def view_key(nil), do: nil
  def view_key(%View{name: name, type: type}), do: "#{hd(List.wrap(name))}:#{type}"

  @doc """
  The key of the presets of a page and a view in the client storage
  (`filter_storage :client`, for example `localStorage`). The value is a
  JSON list of presets: the attributes of `PyroManiac.FilterPresets` with
  string keys (`name`, `view`, `filter`, `sort`, `search`, `inputs`,
  `interactive?`).

      iex> PyroManiac.ListState.storage_key(BreweryWeb.RecipePage, nil)
      "pyro_maniac:filters:BreweryWeb.RecipePage"
  """
  @spec storage_key(module(), View.t() | nil) :: String.t()
  def storage_key(page, view) do
    Enum.join(["pyro_maniac", "filters", page_key(page)] ++ List.wrap(view_key(view)), ":")
  end

  @doc """
  The preset attributes of a state: `filter`, `sort`, `search`, and
  `inputs`. The page position is not part of a preset.

      iex> PyroManiac.ListState.to_preset(%PyroManiac.ListState{sort: "-name", page: 2})
      %{filter: %{}, sort: "-name", search: nil, inputs: %{}}
  """
  @spec to_preset(t()) :: map()
  def to_preset(%__MODULE__{} = state) do
    %{
      filter: stringify(state.filter || %{}),
      sort: state.sort,
      search: state.search,
      inputs: stringify(state.inputs || %{})
    }
  end

  @doc """
  The state of a preset: a record of a `PyroManiac.FilterPresets` resource,
  or a map with atom or string keys (the client storage).

      iex> PyroManiac.ListState.from_preset(%{"sort" => "name", "filter" => %{}})
      %PyroManiac.ListState{sort: "name"}
  """
  @spec from_preset(map()) :: t()
  def from_preset(preset) when is_map(preset) do
    %__MODULE__{
      filter: normalize(:filter, preset_value(preset, :filter) || %{}),
      sort: normalize(:sort, preset_value(preset, :sort)),
      search: preset_value(preset, :search),
      inputs: normalize(:inputs, preset_value(preset, :inputs))
    }
  end

  defp preset_value(preset, key),
    do: Map.get(preset, key, Map.get(preset, Atom.to_string(key)))

  ## Helpers

  defp json(nil), do: nil
  defp json(map) when map == %{}, do: nil
  defp json(map), do: map |> stringify() |> JSON.encode!()

  defp decode_json(value) when is_binary(value) and value != "" do
    case JSON.decode(value) do
      {:ok, map} when is_map(map) and map_size(map) > 0 -> map
      _other -> nil
    end
  end

  defp decode_json(_value), do: nil

  # String keys, and strings for the atoms that are not `nil` or booleans, so
  # that a state is the same after a round trip through JSON.
  defp stringify(map) when is_map(map) and not is_struct(map),
    do: Map.new(map, fn {key, value} -> {to_string(key), stringify(value)} end)

  defp stringify(list) when is_list(list), do: Enum.map(list, &stringify/1)

  defp stringify(value) when is_atom(value) and value not in [nil, true, false],
    do: to_string(value)

  defp stringify(value), do: value

  defp string(value) when is_binary(value) and value != "", do: value
  defp string(_value), do: nil

  defp positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _other -> nil
    end
  end

  defp positive_integer(value) when is_integer(value) and value > 0, do: value
  defp positive_integer(_value), do: nil
end
