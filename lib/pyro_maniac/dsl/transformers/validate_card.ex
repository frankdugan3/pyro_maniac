defmodule PyroManiac.Dsl.Transformers.ValidateCard do
  @moduledoc false

  # The `:card` views of a page (the single views): one record, in its record
  # tree. A card is on the resource of its page. Sets the `__tree__` of each
  # grid with `card? true` (the tree of the primary card). The tree of each
  # view is resolved by `ExpandFormActions`.

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.View.View

  @runs_after [
    PyroManiac.Dsl.Transformers.ResolveViewResources,
    PyroManiac.Dsl.Transformers.ExpandViewArguments,
    PyroManiac.Dsl.Transformers.ValidateViews,
    PyroManiac.Dsl.Transformers.ExpandFormActions
  ]

  @impl true
  def after?(module) when module in @runs_after, do: true
  def after?(_), do: false

  @impl true
  def before?(PyroManiac.Dsl.Transformers.ValidateSurface), do: true
  def before?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    resource = Transformer.get_persisted(dsl, :resource, nil)
    views = Transformer.get_entities(dsl, [:views])

    cards = Enum.filter(views, &match?(%View{type: :card}, &1))

    for card <- cards do
      path = [:views, :view, view_name(card), :card]
      validate_resource(card, resource, path, module)
      validate_no_list_entities(card, path, module)
    end

    {:ok, expand_grids(dsl, views, grid_card(cards), module)}
  end

  # The card of a grid with `card? true`: the primary card, else the only
  # card.
  defp grid_card(cards) do
    case Enum.find(cards, & &1.primary?) do
      nil -> if match?([_], cards), do: hd(cards)
      card -> card
    end
  end

  # A grid with `card? true` shows the card of the page: the nodes of its
  # tree before `tabs`, without `related` and `attachments`.
  defp expand_grids(dsl, views, card, module) do
    views
    |> Enum.filter(&match?(%View{type: :grid, card?: true}, &1))
    |> Enum.reduce(dsl, fn grid, dsl ->
      path = [:views, :view, view_name(grid), :grid, :card?]

      cond do
        is_nil(card) ->
          Error.raise!(
            module: module,
            location: Entity.property_anno(grid, :card?) || Entity.anno(grid),
            path: path,
            why: "the grid has `card? true`, but the page has no primary `:card` view",
            fix:
              "set `primary? true` on a `:card` view of the page, or give the grid its own " <>
                "record tree"
          )

        grid.fields != [] ->
          Error.raise!(
            module: module,
            location: Entity.property_anno(grid, :card?) || Entity.anno(grid),
            path: path,
            why:
              "the grid has `card? true` and its own nodes. It shows the card of the page, so " <>
                "its nodes would not show",
            fix: "remove the nodes of the grid, or remove `card? true`"
          )

        true ->
          expanded = %{grid | __tree__: PyroManiac.Card.grid_tree(card.__tree__)}
          Transformer.replace_entity(dsl, [:views], expanded, &(&1 == grid))
      end
    end)
  end

  defp validate_resource(%View{resource: view_resource} = card, resource, path, module) do
    if view_resource && view_resource != resource do
      Error.raise!(
        module: module,
        location: Entity.property_anno(card, :resource) || Entity.anno(card),
        path: path,
        why:
          "the `:card` view is on #{inspect(view_resource)}, but the page is on " <>
            inspect(resource),
        fix: "remove `resource`. A card shows a record of the resource of its page"
      )
    end
  end

  defp validate_no_list_entities(card, path, module) do
    if card.columns != [] do
      Error.raise!(
        module: module,
        location: Entity.anno(card),
        path: path,
        why: "a `:card` view has no columns: it shows one record",
        fix: "put the values in the record tree of the card (`section`, `field`)"
      )
    end
  end

  defp view_name(%View{name: [name | _]}), do: name
  defp view_name(_view), do: :view
end
