# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"


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
    newsletter: [
      schedule: "@weekly",
      task: {Hyades.Users, :send_all_newsletters, []}
    ]
  ]
