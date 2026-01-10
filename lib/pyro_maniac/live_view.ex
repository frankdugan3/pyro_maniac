if Code.ensure_loaded?(Phoenix.LiveView) && Code.ensure_loaded?(AshPhoenix) do
  defmodule PyroManiac.LiveView do
    @moduledoc """
    Phoenix LiveView components to automatically render PyroManiac DSL.
    """

    use Spark.Dsl,
      opt_schema: [
        endpoint: [
          type: {:behaviour, Phoenix.Endpoint},
          doc: "Your Phoenix endpoint",
          required: true
        ],
        router: [
          type: :module,
          doc: "Your Phoenix router",
          required: true
        ],
        gettext_backend: [
          type: {:behaviour, Gettext.Backend},
          doc: "Your Gettext backend",
          required: true
        ],
        theme: [
          type: {:spark, PyroManiac.Theme},
          doc: "Base theme to extend.",
          required: true
        ],
        static_paths: [
          type: {:or, [{:list, :string}, :mfa]},
          doc: "Your static file paths.",
          required: true
        ]
      ],
      default_extensions: [
        extensions: [PyroManiac.Theme.Dsl]
      ]

    alias PyroManiac.{DataTable, Form}

    @entity_namespaces %{
      DataTable.Action => "data_table",
      DataTable.Column => "data_table__column",
      Form.Action => "form",
      Form.Field => "form__field",
      Form.FieldGroup => "form__field_group",
      Form.Step => "form__step"
    }

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
    # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
    def handle_before_compile(_opts) do
      # static_paths =
      #   case opts[:static_paths] do
      #     {module, fun, []} -> apply(module, fun, [])
      #     paths when is_list(paths) -> paths
      #   end
      #
      # quote bind_quoted: [
      #         endpoint: opts[:endpoint],
      #         router: opts[:router],
      #         gettext_backend: opts[:gettext_backend],
      #         static_paths: static_paths
      #       ] do
      #   import PyroManiac.LiveView.Components
      #
      #   defmacro __using__(_opts) do
      #     quote do
      #       use Phoenix.LiveView
      #       use Gettext, backend: unquote(gettext_backend)
      #
      #       use Phoenix.VerifiedRoutes,
      #         endpoint: unquote(endpoint),
      #         router: unquote(router),
      #         statics: unquote(static_paths)
      #
      #       import PyroManiac.LiveView.Components
      #     end
      #   end
      # end
      quote do
        import Phoenix.Component

        alias PyroManiac.LiveView.Components
        alias PyroManiac.Theme.BaseClass
        alias PyroManiac.{DataTable, Form}
        alias Spark.Dsl.Extension

        @base_class (for %BaseClass{} = base_class <-
                           Extension.get_entities(__MODULE__, [:theme]),
                         {key, value} <- base_class_entries(base_class),
                         into: %{} do
                       {key, value}
                     end)

        defp base_class_entries(%BaseClass{name: name, prefixed: prefixed}) do
          [{Atom.to_string(name), prefixed}, {name, prefixed}]
        end

        def data_table(assigns) do
          assigns
          |> assign_new(:backend, fn -> __MODULE__ end)
          |> Components.data_table()
        end

        @base_class_for (for {entity, namespace} <- unquote(Macro.escape(@entity_namespaces)),
                             class <-
                               entity.__struct__() |> Map.keys() |> Enum.filter(&class_key?/1),
                             into: %{} do
                           key = base_class_key(class, namespace)
                           {{entity, class}, Map.fetch!(@base_class, key)}
                         end)

        defp class_key?(key), do: key |> Atom.to_string() |> String.match?(~r/_?class$/)

        defp base_class_key(class, namespace) do
          suffix = class |> Atom.to_string() |> String.replace(~r/_?class$/, "")
          if suffix == "", do: namespace, else: namespace <> "__" <> suffix
        end

        def base_class_for(%{__struct__: entity}, class),
          do: Map.fetch!(@base_class_for, {entity, class})

        def base_class_for(entity, class),
          do: Map.fetch!(@base_class_for, {entity, class})

        def base_class(key), do: Map.fetch!(@base_class, key)
      end
    end
  end
end
