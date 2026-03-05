defmodule PyroManiac.MixProject do
  @moduledoc false
  use Mix.Project

  @source_url "https://github.com/frankdugan3/pyro_maniac"
  @version "0.1.0"
  @description """
  Extensible, declarative, framework-agnostic UI DSL for Ash Framework resources.
  """

  @elixir_requirement "~> 1.19"

  def project do
    [
      aliases: aliases(),
      app: :pyro_maniac,
      compilers: [:yecc] ++ Mix.compilers(),
      consolidate_protocols: Mix.env() not in [:dev, :test],
      deps: deps(),
      description: @description,
      dialyzer: [
        plt_add_apps: [:ash, :spark, :ecto, :mix, :ex_unit],
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      docs: &docs/0,
      elixir: @elixir_requirement,
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "PyroManiac",
      package: package(),
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      test_paths: ["test"],
      usage_rules: usage_rules(),
      version: @version
    ]
  end

  defp usage_rules do
    [
      file: "CLAUDE.md",
      usage_rules: [{~r/.*/, link: :markdown}]
    ]
  end

  def cli do
    [preferred_envs: [docs: :docs, "docs.watch": :docs, "test.setup": :test, "test.watch": :test]]
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

      "documentation/dsls/DSL-PyroManiac.Resource.md" = path ->
        {String.to_atom(path),
         [title: "Resource", search_data: Spark.Docs.search_data_for(PyroManiac.Resource)]}

      "documentation/dsls/DSL-PyroManiac.KanBan.md" = path ->
        {String.to_atom(path),
         [title: "KanBan", search_data: Spark.Docs.search_data_for(PyroManiac.KanBan)]}

      "documentation/dsls/DSL-PyroManiac.Navigation.md" = path ->
        {String.to_atom(path),
         [
           title: "Navigation",
           search_data: Spark.Docs.search_data_for(PyroManiac.Navigation.Dsl)
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
        Macros: &(&1[:type] == :macro),
        "DSL Schemas": &(&1[:type] == :dsl_schema)
      ],
      nest_modules_by_prefix: [
        PyroManiac.Dsl,
        PyroManiac.Form,
        PyroManiac.Page,
        PyroManiac.Search,
        PyroManiac.View,
        PyroManiac.KanBan,
        PyroManiac.Navigation,
        PyroManiac.Resource
      ]
    ]
  end

  defp package do
    [
      name: :pyro_maniac,
      maintainers: ["Frank Polasek Dugan III"],
      licenses: ["MIT"],
      links: %{GitHub: @source_url},
      files: ~w(
        lib documentation
        README* CHANGELOG* LICENSE*
        usage-rules.md usage-rules
        mix.exs .formatter.exs
      )
    ]
  end

  defp groups_for_modules do
    [
      PyroManiac: [~r/^PyroManiac(?!\.(KanBan|Navigation|Resource))/],
      "PyroManiac.Resource": [~r/^PyroManiac\.Resource/],
      "PyroManiac.KanBan": [~r/^PyroManiac\.KanBan/],
      "PyroManiac.Navigation": [~r/^PyroManiac\.Navigation/]
    ]
  end

  def application do
    opts = [extra_applications: [:logger, :postgrex]]

    if Mix.env() == :dev do
      Keyword.put(opts, :mod, {Brewery.Application, []})
    else
      opts
    end
  end

  defp deps do
    [
      # Code quality tooling
      {:credo, ">= 0.0.0", only: [:dev, :test, :docs], runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:doctor, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_check, ">= 0.0.0", only: :dev, runtime: false},
      {:usage_rules, ">= 0.0.0", only: :dev},
      {:mix_audit, ">= 0.0.0", only: :dev, runtime: false},
      {:mix_test_watch, ">= 0.0.0", only: :test, runtime: false},
      # Build tooling
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false},
      {:mix_watch_docs, ">= 0.0.0", only: :docs, runtime: false},
      {:makeup, ">= 0.0.0", only: :docs},
      {:makeup_eex, ">= 0.0.0", only: :docs},
      {:makeup_html, ">= 0.0.0", only: :docs},
      {:makeup_elixir, ">= 0.0.0", only: :docs},
      {:git_ops, ">= 0.0.0", only: :dev},
      # Core deps
      {:ash, "~> 3.20"},
      {:spark, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      # Optional deps
      {:ash_storage, github: "ash-project/ash_storage", branch: "main", optional: true},
      {:igniter, "~> 0.6", optional: true}
    ]
  end

  @extensions "PyroManiac.Dsl,PyroManiac.Resource,PyroManiac.Navigation.Dsl,PyroManiac.KanBan"
  defp aliases do
    [
      usage: "usage_rules.sync --yes",
      docs: [
        # "pyro_maniac.install --scribe documentation/topics/advanced/manual-installation.md",
        "spark.cheat_sheets",
        "docs",
        "spark.replace_doc_links"
      ],
      update: ["deps.update --all", "usage"],
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
      "test.setup": [
        "ash_postgres.drop --quiet",
        "ash_postgres.create --quiet",
        "ash_postgres.generate_migrations --auto-name",
        "ash_postgres.migrate"
      ],
      setup: [
        "deps.get",
        "compile",
        "spark.formatter",
        "ash_postgres.drop --quiet",
        "ash_postgres.create --quiet",
        "ash_postgres.generate_migrations --auto-name",
        "ash_postgres.migrate",
        "run priv/repo/seeds.exs",
        "assets.setup",
        "assets.build"
      ],
      "assets.build": ["esbuild pyro_maniac"],
      "assets.setup": ["esbuild.install --if-missing", "tailwind.install --if-missing"]
    ]
  end
end
