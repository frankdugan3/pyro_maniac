defmodule PyroManiac.Link do
  @moduledoc """
  The links between the pages. A node that shows related records (a column
  or a field of a relationship, a `combobox` in view mode, a read-only
  relationship `field`, the records of `related`) navigates to another page
  with `link_to` (`PyroManiac.LinkTo`):

  - a **single link** opens the single view of a record: on a relationship
    to one record, and on each record of a relationship to many records;
  - a **list link** opens a list view of all the related records, filtered
    by the relationship (a relationship to many records only), for example
    the full table of the batches of a recipe.

  A node without `link_to` has no link. The link shows the `default_label`
  of the record. The record comes from an authorized read, so the user can
  read it. The renderer checks only that the user can open the target page.

  The pages are not compile-time dependencies: `resolve/2` finds the view at
  runtime, and a verifier checks each link after everything compiles.
  """
  @moduledoc group: "PyroManiac"

  alias Ash.Resource.Relationships.{BelongsTo, HasMany, HasOne, ManyToMany}
  alias PyroManiac.LinkTo

  @typedoc "A path of fields from a resource."
  @type path :: [atom()]

  @typedoc "A resolved link: the page and its view."
  @type resolved :: %{page: module(), view: PyroManiac.View.View.t()}

  @doc """
  The path of the record of a link: the longest start of `source` that ends
  at a relationship. `nil` when no segment is a relationship.

      iex> PyroManiac.Link.record_path(Brewery.Batch, [:recipe, :name])
      [:recipe]

      iex> PyroManiac.Link.record_path(Brewery.Batch, [:recipe])
      [:recipe]

      iex> PyroManiac.Link.record_path(Brewery.Batch, [:batch_number])
      nil
  """
  @spec record_path(Ash.Resource.t(), path()) :: path() | nil
  def record_path(resource, source) do
    source
    |> List.wrap()
    |> Enum.reduce_while({resource, [], nil}, fn name, {current, walked, found} ->
      case Ash.Resource.Info.relationship(current, name) do
        %{destination: destination} ->
          walked = walked ++ [name]
          {:cont, {destination, walked, walked}}

        nil ->
          {:halt, {current, walked, found}}
      end
    end)
    |> elem(2)
  end

  @doc "The destination resource of the record at `record_path`."
  @spec destination(Ash.Resource.t(), path()) :: Ash.Resource.t()
  def destination(resource, record_path),
    do: PyroManiac.Info.resource_by_path(resource, record_path)

  @doc "The last relationship of `record_path`."
  @spec relationship(Ash.Resource.t(), path()) :: struct()
  def relationship(resource, record_path) do
    resource
    |> PyroManiac.Info.resource_by_path(Enum.drop(record_path, -1))
    |> Ash.Resource.Info.relationship(List.last(record_path))
  end

  @doc "Whether the last relationship of `record_path` has many records."
  @spec many?(Ash.Resource.t(), path()) :: boolean()
  def many?(resource, record_path),
    do: match?(%{cardinality: :many}, relationship(resource, record_path))

  @doc """
  The paths that a link to the record at `record_path` loads, from
  `resource`: the record and its label.

      iex> PyroManiac.Link.label_paths(Brewery.Batch, [:recipe])
      [[:recipe], [:recipe, :name]]
  """
  @spec label_paths(Ash.Resource.t(), path()) :: [path()]
  def label_paths(resource, record_path) do
    destination = destination(resource, record_path)
    [record_path | Enum.map(label(destination), &(record_path ++ &1))]
  end

  # The links of a node ---------------------------------------------------

  @doc """
  The link of a node: its `link_to`, or `nil` without one. A node has one
  `link_to`.
  """
  @spec link([LinkTo.t()] | LinkTo.t() | nil) :: LinkTo.t() | nil
  def link(links), do: links |> List.wrap() |> List.first()

  @doc """
  Finds the view of a link. `kind` is `:single` (the single view of one
  record) or `:list` (a list view of all the related records).

  - `:single`: the `:card` view named `single_view`, else the primary single
    view of the page.
  - `:list`: the list view named `list_view`, else the primary list view of
    the page. A name with many list views takes the primary one.

  Gives `{:ok, resolved}` or `{:error, reason}`.
  """
  @spec resolve(LinkTo.t(), :single | :list) :: {:ok, resolved()} | {:error, String.t()}
  def resolve(%LinkTo{page: page} = link, kind) when kind in [:single, :list] do
    if Code.ensure_loaded?(page) and Spark.Dsl.is?(page, PyroManiac) do
      link |> find_view(kind) |> found(page)
    else
      {:error, "#{inspect(page)} is not a PyroManiac page"}
    end
  end

  defp find_view(%LinkTo{page: page, single_view: nil}, :single),
    do: primary(PyroManiac.Info.primary_single_view(page), "single view")

  defp find_view(%LinkTo{page: page, list_view: nil}, :list),
    do: primary(PyroManiac.Info.primary_list_view(page), "list view")

  defp find_view(%LinkTo{page: page, single_view: name}, :single),
    do: named(page, :single, name, "single view (`:card`)")

  defp find_view(%LinkTo{page: page, list_view: name}, :list),
    do: named(page, :list, name, "list view")

  defp primary(nil, kind), do: {:error, "has no primary #{kind}"}
  defp primary(view, _kind), do: {:ok, view}

  defp named(page, kind, name, label) do
    case PyroManiac.Info.named_views(page, kind, name) do
      [] ->
        {:error, "has no #{label} #{inspect(name)}"}

      [view] ->
        {:ok, view}

      views ->
        primary = PyroManiac.Info.primary_list_view(page)

        if primary in views,
          do: {:ok, primary},
          else:
            {:error,
             "has many #{label}s #{inspect(name)} (#{inspect(Enum.map(views, & &1.type))}), " <>
               "and none is primary"}
    end
  end

  defp found({:ok, view}, page), do: {:ok, %{page: page, view: view}}
  defp found({:error, reason}, page), do: {:error, "#{inspect(page)} " <> reason}

  # The list filter -------------------------------------------------------

  @doc """
  How a list link filters the list of the destination by the last
  relationship of `record_path`: `{filter_path, source_attribute}`. The list
  shows the records whose `filter_path` equals the `source_attribute` of the
  record at the start of the relationship. A `many_to_many` uses its reverse
  relationship on the destination. `nil` when there is none.

      iex> PyroManiac.Link.list_filter_path(Brewery.Recipe, [:batches])
      {[:recipe_id], :id}

      iex> PyroManiac.Link.list_filter_path(Brewery.Batch, [:recipe])
      {[:id], :recipe_id}
  """
  @spec list_filter_path(Ash.Resource.t(), path()) :: {path(), atom()} | nil
  def list_filter_path(resource, record_path) do
    case relationship(resource, record_path) do
      %struct{} = relationship when struct in [BelongsTo, HasOne, HasMany] ->
        {[relationship.destination_attribute], relationship.source_attribute}

      %ManyToMany{} = relationship ->
        case reverse(relationship) do
          nil ->
            nil

          reverse ->
            {[reverse.name, reverse.destination_attribute], relationship.source_attribute}
        end

      _ ->
        nil
    end
  end

  defp reverse(%ManyToMany{} = relationship) do
    relationship.destination
    |> Ash.Resource.Info.relationships()
    |> Enum.find(fn candidate ->
      match?(%ManyToMany{}, candidate) and candidate.destination == relationship.source and
        candidate.through == relationship.through
    end)
  end

  @doc """
  The filter input of a list link from the record that shows the
  relationship (the record at the start of the last relationship of
  `record_path`). `nil` when the relationship has no list filter.
  """
  @spec list_filter(Ash.Resource.t(), path(), struct()) :: map() | nil
  def list_filter(resource, record_path, record) do
    case list_filter_path(resource, record_path) do
      nil ->
        nil

      {filter_path, source_attribute} ->
        value = Map.get(record, source_attribute)

        filter_path
        |> Enum.reverse()
        |> Enum.reduce(%{"eq" => value}, fn key, acc -> %{to_string(key) => acc} end)
    end
  end

  # Helpers ---------------------------------------------------------------

  defp label(resource) do
    case PyroManiac.Resource.Info.default_label(resource) do
      nil -> []
      label -> [[label]]
    end
  end
end
