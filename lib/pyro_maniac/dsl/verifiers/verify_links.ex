defmodule PyroManiac.Dsl.Verifiers.VerifyLinks do
  @moduledoc false

  # The links of a page (`link_to`) and the pages of `related ... delegate_to`.
  # The pages are not compile-time dependencies, so this is a verifier: it
  # runs after everything compiles.
  #
  # - A `link_to` is on a node of a relationship: the link opens its records.
  # - The page of a link is a PyroManiac page on the destination of the
  #   relationship, and it has the views of the link (`single_view`,
  #   `list_view`, or the primary views).
  # - `list_view` is for a relationship to many records.
  # - The read action of a list view exposes the filter of the relationship.
  # - A `delegate_to` of `related` names a page on the destination.

  use PyroManiac.Dsl.Verifiers

  alias PyroManiac.Card
  alias PyroManiac.Dsl.Error
  alias PyroManiac.Link

  @impl true
  def verify(dsl) do
    module = Verifier.get_persisted(dsl, :module)

    dsl
    |> Card.links()
    |> Enum.reduce_while(:ok, fn link, :ok ->
      case verify_link(link, module) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp verify_link(%{destination: nil} = link, module) do
    error(
      link,
      module,
      "the source #{inspect(link[:source])} has no relationship, so there is no record " <>
        "to link to",
      "show a relationship (for example `column :recipe`, or `source [:recipe, :name]`), " <>
        "or remove `link_to`"
    )
  end

  defp verify_link(%{kind: :delegate, page: page} = link, module),
    do: verify_page(link, page, module, delegate_fix())

  defp verify_link(%{kind: kind} = link, module) do
    with :ok <- verify_page(link, link.link.page, module, link_fix()),
         :ok <- verify_list_view_option(link, module),
         {:ok, resolved} <- resolve(link, kind, module) do
      verify_filter(link, resolved, module)
    end
  end

  defp verify_page(link, page, module, fix) do
    cond do
      not (Code.ensure_loaded?(page) and Spark.Dsl.is?(page, PyroManiac)) ->
        error(link, module, "#{inspect(page)} is not a PyroManiac page", fix)

      PyroManiac.Info.resource(page) != link.destination ->
        error(
          link,
          module,
          "#{inspect(page)} shows #{inspect(PyroManiac.Info.resource(page))}, but the " <>
            "relationship goes to #{inspect(link.destination)}",
          fix
        )

      true ->
        :ok
    end
  end

  # A relationship to one record has no list of records.
  defp verify_list_view_option(%{kind: :single, link: %{list_view: name}} = link, module)
       when not is_nil(name) do
    if Link.many?(link.resource, link.record_path) do
      :ok
    else
      error(
        link,
        module,
        "`list_view #{inspect(name)}` is for a relationship to many records, but " <>
          "#{inspect(List.last(link.record_path))} goes to one record",
        "remove `list_view`. The link opens the single view of the record"
      )
    end
  end

  defp verify_list_view_option(_link, _module), do: :ok

  defp resolve(link, kind, module) do
    case Link.resolve(link.link, kind) do
      {:ok, resolved} -> {:ok, resolved}
      {:error, reason} -> error(link, module, reason, link_fix())
    end
  end

  # A list link filters the list view by the relationship. Its read action
  # exposes that filter.
  defp verify_filter(%{kind: :single}, _resolved, _module), do: :ok

  defp verify_filter(link, resolved, module) do
    case Link.list_filter_path(link.resource, link.record_path) do
      nil ->
        error(
          link,
          module,
          "the list of #{inspect(link.destination)} cannot be filtered by the relationship " <>
            "#{inspect(List.last(link.record_path))}: a `many_to_many` needs the reverse " <>
            "`many_to_many` on #{inspect(link.destination)}",
          "add the reverse relationship, or remove `link_to`"
        )

      {filter_path, _source_attribute} ->
        verify_exposed_filter(link, resolved, filter_path, module)
    end
  end

  defp verify_exposed_filter(link, %{page: page, view: view}, filter_path, module) do
    target = PyroManiac.Info.resource(page)
    action = view.read_action || hd(view.name)

    filter =
      case PyroManiac.Resource.Info.exposed(target, action) do
        nil -> []
        expose -> expose.filter || []
      end

    if PyroManiac.Surface.covered?(filter_path, filter) do
      :ok
    else
      error(
        link,
        module,
        "the link filters the #{inspect(view.type)} view of #{inspect(page)} by " <>
          "#{inspect(PyroManiac.Surface.from_paths([filter_path]))}, but it is not in " <>
          "`filter` of `expose #{inspect(action)}` on #{inspect(target)}",
        "add it to `filter` of `expose #{inspect(action)}` in #{inspect(target)}"
      )
    end
  end

  defp error(link, module, why, fix) do
    {:error,
     Error.build(
       module: module,
       location: location(link),
       path: link.origin,
       why: why,
       fix: fix
     )}
  end

  defp location(%{link: %PyroManiac.LinkTo{} = link_to}), do: Entity.anno(link_to)

  defp location(%{entity: entity, kind: :delegate}),
    do: Entity.property_anno(entity, :delegate_to) || Entity.anno(entity)

  defp location(%{entity: entity}), do: Entity.anno(entity)

  defp link_fix,
    do: "name a page of the destination, and its views (`single_view`, `list_view`)"

  defp delegate_fix, do: "name a page on the destination of the relationship"
end
