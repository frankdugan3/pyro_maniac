defmodule PyroManiac.MixProject do
  @moduledoc false
  use Mix.Project

  alias PyroManiac.Dsl

  @source_url "https://github.com/frankdugan3/pyro_maniac"
  @version "0.1.0"
  @description """
  Extensible, declarative UI for Ash Framework. Built-in support for Phoenix LiveView and Hologram.
  """
  def project do
    [
      app: :pyro_maniac,
      version: @version,
      description: @description,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: &docs/0,
      test_paths: ["test"],
      name: "PyroManiac",
      source_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,
      aliases: aliases(),
      compilers: [:yecc] ++ Mix.compilers(),
      # compilers: [:yecc, :phoenix_live_view] ++ Mix.compilers() ++ [:hologram],
      dialyzer: [plt_add_apps: [:ash, :spark, :ecto, :mix]]
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.watch": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp extras do
    "documentation/**/*.md"
    |> Path.wildcard()
    |> Enum.map(fn
      "documentation/dsls/DSL-PyroManiac.md" = path ->
        {String.to_atom(path),
         [
           title: "PyroManiac",
           search_data: Spark.Docs.search_data_for(PyroManiac.Dsl)
         ]}

      path ->
        title =
          path
          |> Path.basename(".md")
          |> String.split(~r/[-_]/)
          |> Enum.map_join(" ", &String.capitalize/1)

        {String.to_atom(path),
         [
           title: title,
           default: title == "Get Started"
         ]}
    end)
  end

  defp groups_for_extras do
    [
      Tutorials: [
        "documentation/tutorials/get-started.md",
        ~r'documentation/tutorials'
      ],
      DSL: [
        ~r'documentation/dsls'
      ]
    ]
  end

  defp docs do
    [
      main: "about",
      source_ref: "v#{@version}",
      output: "doc",
      source_url: @source_url,
      extra_section: "GUIDES",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules(),
      groups_for_docs: [
        Macros: &(&1[:type] == :macro)
      ],
      nest_modules_by_prefix: [
        Dsl
      ]
    ]
  end

  defp package do
    [
      name: :pyro_maniac,
      maintainers: ["Frank Dugan III"],
      licenses: ["MIT"],
      links: %{GitHub: @source_url},
      files:
        ~w(lib documentation) ++
          ~w(README* CHANGELOG* LICENSE* usage-rules.md mix.exs .formatter.exs)
    ]
  end

  defp groups_for_modules do
    [
      Core: [
        PyroManiac,
        PyroManiac.Enum,
        PyroManiac.Helpers,
        PyroManiac.Info
      ],
      "DSL Structs": [
        ~r/PyroManiac.Dsl/
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Dev tooling
      {:credo, ">= 0.0.0", only: [:test, :dev], runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:doctor, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_check, "~> 0.15",
       [env: :prod, hex: "ex_check", only: :dev, runtime: false, repo: "hexpm"]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:git_ops, "~> 2.6", only: :dev},
      {:mix_audit, ">= 0.0.0", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.10", only: [:dev, :test], runtime: false},
      # Core dependencies
      {:ash, "~> 3.0"},
      {:igniter, "~> 0.6", optional: true},
      {:spark, "~> 2.0"},
      {:ash_phoenix, "~> 2.0", optional: true},
      {:phoenix_live_view, "~> 1.1", optional: true}
      # {:hologram, "~> 0.5", optional: true}
    ]
  end

  @extensions "PyroManiac.Dsl,PyroManiac.Theme.Dsl"
  defp aliases do
    [
      docs: [
        # "pyro_maniac.install --scribe documentation/topics/advanced/manual-installation.md",
        "spark.cheat_sheets",
        "docs",
        "spark.replace_doc_links"
      ],
      update: ["deps.update --all"],
      format: ["format --migrate"],
      "spark.cheat_sheets": "spark.cheat_sheets --extensions #{@extensions}",
      "spark.formatter": [
        "spark.formatter --extensions #{@extensions}",
        "format"
      ],
      # until we hit 1.0, we will ensure no major release!
      release: [
        "spark.formatter",
        "git_ops.release --no-major"
      ],
      publish: [
        "hex.publish"
      ],
      setup: [
        "deps.get",
        "compile",
        "docs"
      ]
    ]
  end
end
