# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :hyades, :scopes,
  user: [
    default: true,
    module: Hyades.Users.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users
  ]

config :esbuild,
  version: "0.14.9",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "4.2.2",
  default: [
    args: ~w(
      --input=assets/css/app.scss
      --output=priv/static/assets/app.css
         ),
    cd: Path.expand("../", __DIR__)
  ]

config :hyades,
  ecto_repos: [Hyades.Repo]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ueberauth, Ueberauth,
  providers: [
    github:
      {Ueberauth.Strategy.Github,
       [default_scope: "user:email", send_redirect_uri: false, allow_private_emails: true]}
  ],
  base_path: "/auth"

config :hyades, Hyades.Cron,
  jobs: [
    cleanup: [
      schedule: "@weekly",
      task: {Hyades.Users, :clean_spam, []}
    ],
    newsletter: [
      schedule: "@weekly",
      task: {Hyades.Users, :send_all_newsletters, []}
    ]
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
