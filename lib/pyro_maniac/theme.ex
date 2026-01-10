defmodule PyroManiac.Theme do
  @moduledoc """
  Define a theme for PyroManiac UI components.
  """

  use Spark.Dsl,
    opt_schema: [
      theme: [
        type: {:spark, PyroManiac.Theme},
        doc: "Extend an existing theme."
      ]
    ],
    default_extensions: [extensions: [PyroManiac.Theme.Dsl]]

  @type t :: module

  @doc false
  @impl Spark.Dsl
  def handle_opts(opts) do
    quote bind_quoted: [theme: opts[:theme]] do
      @persist {:theme, theme}
    end
  end

  @doc false
  @impl Spark.Dsl
  def handle_before_compile(_opts) do
    quote do
      @doc """
      List all the base class names required in a theme.

      ## Examples

          iex> base_class_names() |> Enum.find(& &1 == :form)
          :form
      """
      def base_class_names,
        do: Spark.Dsl.Extension.get_opt(__MODULE__, [:theme], :base_class_names, [])
    end
  end
end
