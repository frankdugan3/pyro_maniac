defmodule PyroManiac.Theme.Dsl.Transformers.ApplyTheme do
  @moduledoc """
  Apply prefix to all base classes.
  """
  use PyroManiac.Dsl.Transformers

  alias PyroManiac.Theme.BaseClass
  alias Spark.Dsl.Extension
  alias Spark.Dsl.Transformer

  @impl true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    case Transformer.get_persisted(dsl, :theme) do
      nil ->
        base_class_names =
          Transformer.get_option(
            dsl,
            [:theme],
            :base_class_names,
            BaseClass.default_base_class_names()
          )

        dsl = Transformer.set_option(dsl, [:theme], :base_class_names, base_class_names)
        {:ok, dsl}

      theme ->
        {:ok, merge_theme(dsl, theme)}
    end
  end

  defp merge_theme(dsl, theme) do
    base_class_names =
      Transformer.get_option(
        dsl,
        [:theme],
        :base_class_names,
        Extension.get_opt(
          theme,
          [:theme],
          :base_class_names,
          BaseClass.default_base_class_names()
        )
      )

    dsl = Transformer.set_option(dsl, [:theme], :base_class_names, base_class_names)

    theme_base_classes =
      for %BaseClass{} = base_class <- Extension.get_entities(theme, [:theme]) do
        base_class
      end

    base_classes =
      for %BaseClass{} = base_class <- Transformer.get_entities(dsl, [:theme]) do
        base_class
      end

    dsl =
      Transformer.remove_entity(dsl, [:theme], fn
        %BaseClass{} -> true
        _ -> false
      end)

    dsl = Enum.reduce(theme_base_classes, dsl, &Transformer.add_entity(&2, [:theme], &1))

    Enum.reduce(base_classes, dsl, &Transformer.replace_entity(&2, [:theme], &1))
  end
end
