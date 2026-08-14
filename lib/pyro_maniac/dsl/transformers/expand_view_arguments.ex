defmodule PyroManiac.Dsl.Transformers.ExpandViewArguments do
  @moduledoc """
  Resolves a view read action's public arguments into form fields so a renderer can offer controls for them.
  """

  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Dsl.FieldResolver

  alias PyroManiac.View.View

  @ash_resource_transformers Resource.Dsl.transformers()

  @impl true
  def after?(PyroManiac.Dsl.Transformers.ResolveViewResources), do: true
  def after?(module) when module in @ash_resource_transformers, do: true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    views = Transformer.get_entities(dsl, [:views])

    if Enum.any?(views, &match?(%View{}, &1)) do
      {:ok, expand(dsl, views)}
    else
      {:ok, dsl}
    end
  end

  defp expand(dsl, views) do
    context = %{
      extra_form_types: Transformer.get_option(dsl, [:forms], :extra_form_types, []),
      module: Transformer.get_persisted(dsl, :module, nil),
      path_root: [:views]
    }

    expanded = for %View{} = view <- views, do: expand_view(view, context)

    dsl =
      Transformer.remove_entity(dsl, [:views], fn
        %View{} -> true
        _ -> false
      end)

    Enum.reduce(expanded, dsl, &Transformer.add_entity(&2, [:views], &1, prepend: true))
  end

  defp expand_view(%View{} = view, context) do
    view
    |> Map.put(:__arguments__, arguments_for(view, context))
    |> Map.update!(:views, fn
      nested when is_list(nested) -> Enum.map(nested, &expand_view(&1, context))
      other -> other
    end)
  end

  defp expand_view(other, _context), do: other

  defp arguments_for(%View{type: :delegated}, _context), do: []
  defp arguments_for(%View{resource: nil}, _context), do: []

  defp arguments_for(%View{} = view, context) do
    action_name = read_action_name(view)

    case action_name && Ash.Resource.Info.action(view.resource, action_name) do
      %{type: :read, arguments: arguments} ->
        arguments
        |> Enum.filter(& &1.public?)
        |> Enum.map(&argument_field(&1, view, action_name, context))

      _ ->
        []
    end
  end

  defp read_action_name(%View{read_action: read_action}) when not is_nil(read_action),
    do: read_action

  defp read_action_name(%View{name: names}), do: names |> List.wrap() |> List.first()

  defp argument_field(argument, view, action_name, context) do
    [name: argument.name, label: default_label(argument.name), allow_nil?: argument.allow_nil?]
    |> put_description(argument.description)
    |> FieldResolver.new_field()
    |> FieldResolver.resolve(view.resource, action_name, context)
    |> Map.put(:allow_nil?, argument.allow_nil?)
  end

  defp put_description(opts, description) when is_binary(description) and description != "",
    do: Keyword.put(opts, :description, description)

  defp put_description(opts, _description), do: opts
end
