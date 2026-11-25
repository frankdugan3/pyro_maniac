defmodule PyroManiac.Dsl.Transformers.ValidatePrimaryViews do
  @moduledoc false

  # The primary views of a page (`primary? true`): a link to the page opens
  # them. A page has one primary single view (a `:card`), and at most one
  # primary list-only view. A `:card` that is the only primary view is also
  # the primary list view. Only list and single views are primary. The
  # persister `Views` lifts them to `:__primary_single_view__`
  # and `:__primary_list_view__`.
  #
  # Each card and grid is designed: a card has `form` or sections, a grid
  # has sections or `card? true`.
  #
  # Runs last, so that the other errors of a page show first.

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.View.View

  @impl true
  def after?(_module), do: true

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    views = for %View{} = view <- Transformer.get_entities(dsl, [:views]), do: view

    validate_types(views, module)

    primary = Enum.filter(views, & &1.primary?)
    {single, list} = Enum.split_with(primary, &(&1.type in View.single_types()))

    validate_one(single, "single view (`:card`)", module)
    validate_one(list, "list view", module)
    validate_single(dsl, single, list, module)
    Enum.each(views, &validate_designed(&1, module))
    PyroManiac.Dsl.Transformers.LiftViewActions.validate_used(dsl)

    {:ok, dsl}
  end

  defp validate_types(views, module) do
    for %View{primary?: true, type: type} = view <- views,
        type not in (View.single_types() ++ View.list_types()) do
      Error.raise!(
        module: module,
        location: Entity.property_anno(view, :primary?) || Entity.anno(view),
        path: [:views, :view, view_name(view), :primary?],
        why:
          "a #{inspect(type)} view is not a primary view. The primary views are a single " <>
            "view (#{inspect(View.single_types())}) and a list view " <>
            "(#{inspect(View.list_types() -- View.single_types())})",
        fix: "set `primary? true` on a single view or a list view"
      )
    end
  end

  defp validate_designed(%View{type: :card, __tree__: []} = view, module) do
    Error.raise!(
      module: module,
      location: Entity.anno(view),
      path: [:views, :view, view_name(view), :card],
      why:
        "the `:card` view has no record tree. Each view is designed: the card shows its " <>
          "nodes in view mode, and the form of each action that it names",
      fix:
        "add the nodes of the card (`section`, `field`, ...), and `action :update` for an " <>
          "editable card"
    )
  end

  defp validate_designed(%View{type: :grid, card?: false, __tree__: []} = view, module) do
    Error.raise!(
      module: module,
      location: Entity.anno(view),
      path: [:views, :view, view_name(view), :grid],
      why: "the `:grid` view has no record tree. Each view is designed",
      fix:
        "add the nodes of the grid (`section`, `field`, ...), or `card? true` to show the primary card of the page"
    )
  end

  defp validate_designed(_view, _module), do: :ok

  defp validate_one([_, second | _], kind, module) do
    Error.raise!(
      module: module,
      location: Entity.property_anno(second, :primary?) || Entity.anno(second),
      path: [:views, :view, view_name(second), :primary?],
      why: "a page has one primary #{kind}",
      fix: "remove `primary? true` from all but one of them"
    )
  end

  defp validate_one(_views, _kind, _module), do: :ok

  defp validate_single(_dsl, [_single], _list, _module), do: :ok

  defp validate_single(dsl, [], list, module) do
    cards = for %View{type: :card} = view <- Transformer.get_entities(dsl, [:views]), do: view

    why =
      case list do
        [] ->
          "a page has a primary single view: a link to the page opens it"

        [view | _] ->
          "the primary list view #{inspect(view_name(view))} needs a primary single view: " <>
            "a link to one record of the page opens it"
      end

    fix =
      case cards do
        [] -> "add a `:card` view with `primary? true` and its record tree"
        _ -> "set `primary? true` on a `:card` view"
      end

    Error.raise!(
      module: module,
      location: location(list, cards),
      path: [:views],
      why: why,
      fix: fix
    )
  end

  defp location([view | _], _cards), do: Entity.anno(view)
  defp location([], [card | _]), do: Entity.anno(card)
  defp location([], []), do: nil

  defp view_name(%View{name: [name | _]}), do: name
  defp view_name(_view), do: :view
end
