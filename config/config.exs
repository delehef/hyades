# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :esbuild,
  version: "0.14.9",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.0.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.scss
      --output=../priv/static/assets/app.css
      --postcss
    ),
    cd: Path.expand("../assets", __DIR__)
  ]


config :hyades,
  ecto_repos: [Hyades.Repo]

# Configures the endpoint
config :hyades, HyadesWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "vunk92g1sfoVjMiL5BlBWvjXM1A8+Y0UtJ7qwZmyv58WQm6YWmay5G1jGeQQzXyC",
  render_errors: [view: HyadesWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Hyades.PubSub,
  live_view: [signing_salt: "bWE18m54"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :hyades, :pow,
  user: Hyades.Users.User,
  users_context: Hyades.Users,
  repo: Hyades.Repo,
  web_module: HyadesWeb,
  mailer_backend: HyadesWeb.Pow.Mailer,
  extensions: [PowResetPassword],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  routes_backend: HyadesWeb.Pow.Routes,
  web_mailer_module: HyadesWeb,
  messages_backend: HyadesWeb.Pow.Messages

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
