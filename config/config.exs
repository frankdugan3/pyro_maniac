import Config

config :ash, :custom_expressions, [PyroManiac.KanBan.Expressions.FractionalKeyBetween]

config :spark, :formatter,
  remove_parens?: true,
  "PyroManiac.Navigation": [],
  PyroManiac: [
    section_order: [
      :form,
      :data_table
    ]
  ],
  "Ash.Resource": [
    section_order: [
      :resource,
      :authentication,
      :pub_sub,
      :attributes,
      :identities,
      :relationships,
      :aggregates,
      :calculations,
      :validations,
      :changes,
      :actions,
      :code_interface,
      :policies
    ]
  ]

if Mix.env() == :dev do
  config :logger, level: :debug

  config :git_ops,
    mix_project: Mix.Project.get!(),
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/frankdugan3/pyro_maniac",
    types: [
      tidbit: [
        hidden?: true
      ],
      important: [
        header: "Important Changes"
      ]
    ],
    manage_mix_version?: true,
    manage_readme_version: ["README.md", "documentation/tutorials/get-started.md"],
    version_tag_prefix: "v"
end

if Mix.env() == :test do
  config :logger, level: :warning

  config :ash, :validate_domain_config_inclusion?, false
  config :ash, :validate_domain_resource_inclusion?, false

  config :pyro_maniac, ash_domains: [Brewery.Domain]
  config :pyro_maniac, ecto_repos: [Brewery.Repo]

  config :pyro_maniac, Brewery.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "pyro_maniac_#{Mix.env()}",
    pool_size: System.schedulers_online() * 2,
    pool: Ecto.Adapters.SQL.Sandbox

  config :mix_test_watch,
    clear: true,
    tasks: [
      "test",
      "credo"
    ]
end
