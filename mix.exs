defmodule PyroManiac.MixProject do
  @moduledoc false
  use Mix.Project

  @source_url "https://github.com/frankdugan3/pyro_maniac"
  @version "0.1.0"
  @description """
  Extensible, declarative, framework-agnostic UI DSL for Ash Framework resources.
  """

  @elixir_requirement "~> 1.20"

  def project do
    [
      aliases: aliases(),
      app: :pyro_maniac,
      compilers: [:yecc] ++ Mix.compilers(),
      consolidate_protocols: Mix.env() not in [:dev, :test],
      deps: deps(),
      description: @description,
      dialyzer: [plt_add_apps: [:ash, :spark, :ecto, :mix, :ex_unit]],
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

  # The order of the sidebar. Other guides follow, in file order.
  @guides [
    "documentation/about.md",
    "documentation/suite.md",
    "ROADMAP.md",
    "documentation/tutorials/get-started.md",
    "documentation/tutorials/surface.md",
    "documentation/tutorials/pages.md",
    "documentation/tutorials/views.md",
    "documentation/tutorials/record-layout.md",
    "documentation/tutorials/navigation.md",
    "documentation/tutorials/decorations.md",
    "documentation/tutorials/policies.md",
    "documentation/tutorials/custom-renders.md",
    "documentation/renderers/renderer-overview.md",
    "documentation/renderers/renderer-pages.md",
    "documentation/renderers/renderer-filters-and-sorts.md",
    "documentation/renderers/renderer-views.md",
    "documentation/renderers/renderer-actions.md",
    "documentation/renderers/renderer-record-tree.md",
    "documentation/renderers/renderer-navigation.md",
    "documentation/renderers/renderer-decorations.md",
    "documentation/renderers/renderer-custom-renders.md"
  ]

  defp extras do
    Enum.uniq(@guides ++ Path.wildcard("documentation/**/*.md"))
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

      "documentation/dsls/DSL-PyroManiac.KanBan.Lanes.md" = path ->
        {String.to_atom(path),
         [
           title: "KanBan Lanes",
           search_data: Spark.Docs.search_data_for(PyroManiac.KanBan.Lanes)
         ]}

      "documentation/dsls/DSL-PyroManiac.Ordering.md" = path ->
        {String.to_atom(path),
         [title: "Ordering", search_data: Spark.Docs.search_data_for(PyroManiac.Ordering)]}

      "documentation/dsls/DSL-PyroManiac.FilterPresets.md" = path ->
        {String.to_atom(path),
         [
           title: "Filter Presets",
           search_data: Spark.Docs.search_data_for(PyroManiac.FilterPresets)
         ]}

      "documentation/dsls/DSL-PyroManiac.Domain.Typescript.md" = path ->
        {String.to_atom(path),
         [
           title: "Domain TypeScript",
           search_data: Spark.Docs.search_data_for(PyroManiac.Domain.Typescript)
         ]}

      "documentation/dsls/DSL-PyroManiac.Navigation.md" = path ->
        {String.to_atom(path),
         [
           title: "Navigation",
           search_data: Spark.Docs.search_data_for(PyroManiac.Navigation.Dsl)
         ]}

      "ROADMAP.md" = path ->
        {String.to_atom(path), [title: "Roadmap"]}

      path ->
        title =
          path
          |> Path.basename(".md")
          |> String.replace_prefix("renderer-", "")
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
      Tutorials: [~r'documentation/tutorials'],
      Renderers: [~r'documentation/renderers/'],
      Plans: [~r'documentation/plans/'],
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
      ],
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  # A figure (an inline SVG in a guide) opens large: click it, or focus it and
  # press Enter. Escape, a click, or the close button closes it.
  defp before_closing_body_tag(:html) do
    ~S"""
    <style>
    #content figure > svg{width:100%;height:auto;cursor:zoom-in}
    #content figure > svg:focus-visible{outline:2px solid var(--link-color,#2563eb);outline-offset:4px}
    .pm-zoom{position:fixed;inset:0;z-index:1000;display:flex;flex-direction:column;gap:8px;padding:16px;background:var(--background,Canvas);color:var(--textBody,CanvasText);cursor:zoom-out}
    .pm-zoom > svg{flex:1;width:100%;min-height:0}
    .pm-zoom > figcaption{text-align:center;font-size:.9em}
    .pm-zoom-close{position:absolute;top:8px;right:12px;font-size:28px;line-height:1;background:none;border:0;color:inherit;cursor:pointer}
    </style>
    <script>
    (() => {
      const sel = "#content figure > svg";
      const init = () => document.querySelectorAll(sel).forEach((svg) => {
        if (svg.hasAttribute("tabindex")) return;
        const title = svg.querySelector("title");
        svg.setAttribute("tabindex", "0");
        svg.setAttribute("role", "button");
        svg.setAttribute("aria-label", "Enlarge the figure" + (title ? ": " + title.textContent : ""));
        svg.removeAttribute("aria-labelledby");
      });
      const open = (svg) => {
        const overlay = document.createElement("div");
        const close = document.createElement("button");
        const copy = svg.cloneNode(true);
        const caption = svg.closest("figure").querySelector("figcaption");
        const title = svg.querySelector("title");
        overlay.className = "pm-zoom";
        overlay.setAttribute("role", "dialog");
        overlay.setAttribute("aria-modal", "true");
        overlay.setAttribute("aria-label", title ? title.textContent : "Figure");
        close.type = "button";
        close.className = "pm-zoom-close";
        close.setAttribute("aria-label", "Close");
        close.textContent = "×";
        ["tabindex", "aria-label"].forEach((a) => copy.removeAttribute(a));
        copy.setAttribute("role", "img");
        copy.querySelectorAll("[id]").forEach((e) => e.removeAttribute("id"));
        overlay.append(close, copy);
        if (caption) overlay.append(caption.cloneNode(true));
        const shut = () => {
          overlay.remove();
          document.removeEventListener("keydown", key, true);
          svg.focus();
        };
        const key = (e) => {
          if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); shut(); }
          else if (e.key === "Tab") { e.preventDefault(); close.focus(); }
        };
        overlay.addEventListener("click", shut);
        document.addEventListener("keydown", key, true);
        document.body.append(overlay);
        close.focus();
      };
      document.addEventListener("click", (e) => {
        const svg = e.target.closest && e.target.closest(sel);
        if (svg) open(svg);
      });
      document.addEventListener("keydown", (e) => {
        if ((e.key === "Enter" || e.key === " ") && e.target.matches && e.target.matches(sel)) {
          e.preventDefault();
          open(e.target);
        }
      });
      window.addEventListener("exdoc:loaded", init);
      if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
      else init();
    })();
    </script>
    """
  end

  defp before_closing_body_tag(_format), do: ""

  defp package do
    [
      name: :pyro_maniac,
      maintainers: ["Frank Polasek Dugan III"],
      licenses: ["MIT"],
      links: %{GitHub: @source_url},
      files: ~w(
        lib documentation
        README* CHANGELOG* LICENSE* ROADMAP*
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
      # The SAT solver of the Ash policies in the tests
      {:picosat_elixir, "~> 0.2", only: :test},
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
      {:phoenix, "~> 1.8"},
      # Optional deps
      {:ash_storage, github: "ash-project/ash_storage", branch: "main", optional: true},
      {:ash_typescript, "~> 0.19", optional: true},
      {:igniter, "~> 0.6", optional: true, override: true}
    ]
  end

  @extensions "PyroManiac.Dsl,PyroManiac.Resource,PyroManiac.Navigation.Dsl,PyroManiac.KanBan,PyroManiac.KanBan.Lanes,PyroManiac.Domain.Typescript,PyroManiac.Ordering,PyroManiac.FilterPresets"
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
