defmodule PyroManiac.Dsl.Transformers.ValidateRenders do
  @moduledoc false

  # The content of each node (`render`, `description`, the `label` of a
  # column; refer to `PyroManiac.Content`): at most one text or expression,
  # and one implementation for each renderer. An input of a form takes
  # `render Renderer, implementation` only. A view and the page have no
  # record, so no expression. The verifier of each renderer checks that a
  # node with implementations has one for that renderer, or a text or an
  # expression.

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Form.{Combobox, Field, Input, Select, Tree}
  alias PyroManiac.View.View

  @keys [:render, :description, :label]
  @inputs [Field, Select, Combobox, Input]

  @impl true
  def after?(PyroManiac.Dsl.Transformers.ExpandFormActions), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module, nil)
    page = Transformer.get_entities(dsl, [:page])
    description = for %PyroManiac.Description{} = entry <- page, do: entry

    validate_entries(:description, description, "the page", page_anno(description), false, module)

    for entity <- entities(dsl), key <- @keys, entries = content(entity, key), entries != [] do
      validate_entity(entity, key, entries, module)
    end

    {:ok, dsl}
  end

  defp entities(dsl) do
    views = for %View{} = view <- Transformer.get_entities(dsl, [:views]), do: view
    forms = Transformer.get_entities(dsl, [:forms])

    page =
      for %PyroManiac.Page.ExtraAction{} = action <- Transformer.get_entities(dsl, [:page]),
          do: action

    Enum.flat_map(views, fn view ->
      [view | view.columns || []] ++ Tree.all(view.fields || []) ++ (view.extra_actions || [])
    end) ++
      Enum.flat_map(forms, &[&1 | Tree.all(&1.fields || [])]) ++ page
  end

  defp content(entity, key) do
    case Map.get(entity, key) do
      [%{kind: _} | _] = entries -> entries
      _ -> []
    end
  end

  defp validate_entity(%module{} = entity, key, entries, dsl_module) do
    label = "#{inspect(module)} #{inspect(Map.get(entity, :name))}"

    if key == :render and module in @inputs do
      for %{kind: kind} = entry <- entries, kind in [:text, :expr] do
        Error.raise!(
          module: dsl_module,
          location: Entity.anno(entry) || Entity.anno(entity),
          path: [:render],
          why:
            "#{label} is an input: its `render` is an implementation for one renderer, " <>
              "not a text or an expression",
          fix: "use `render Renderer, implementation`"
        )
      end
    end

    expressions? = not match?(%View{}, entity)
    validate_entries(key, entries, label, Entity.anno(entity), expressions?, dsl_module)
  end

  defp validate_entries(key, entries, label, anno, expressions?, module) do
    portable = Enum.filter(entries, &(&1.kind in [:text, :expr]))

    if length(portable) > 1 do
      Error.raise!(
        module: module,
        location: Entity.anno(Enum.at(portable, 1)) || anno,
        path: [key],
        why: "#{label} has more than one text or expression for `#{key}`",
        fix: "keep one; add `#{key} Renderer, implementation` for a renderer"
      )
    end

    if not expressions? do
      for %{kind: :expr} = entry <- entries do
        Error.raise!(
          module: module,
          location: Entity.anno(entry) || anno,
          path: [key],
          why: "#{label} has no record, so its `#{key}` is not an expression",
          fix: "use a text, or `#{key} Renderer, implementation`"
        )
      end
    end

    for {renderer, [_, second | _]} <-
          entries |> Enum.filter(&(&1.kind == :impl)) |> Enum.group_by(& &1.renderer) do
      Error.raise!(
        module: module,
        location: Entity.anno(second) || anno,
        path: [key],
        why:
          "#{label} has more than one `#{key}` for #{inspect(renderer)}. One " <>
            "implementation renders the whole node",
        fix: "keep one `#{key}` for each renderer"
      )
    end
  end

  defp page_anno([first | _]), do: Entity.anno(first)
  defp page_anno([]), do: nil
end
