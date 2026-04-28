import Config

defmodule Helper do
  def from_env(key), do: System.get_env(key) || raise("#{key} missing")
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/hyades start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :hyades, HyadesWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :hyades, Hyades.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")
  config :hyades, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :hyades, HyadesWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :hyades, Hyades.Users.Mailer,
    adapter: Bamboo.MailgunAdapter,
    api_key: Helper.from_env("MAILGUN_API_KEY"),
    domain: Helper.from_env("MAILGUN_DOMAIN"),
    base_uri: Helper.from_env("MAILGUN_BASE_URI")

  config :hyades, Hyades.Github.Mailer,
    adapter: Bamboo.MailgunAdapter,
    api_key: Helper.from_env("MAILGUN_API_KEY"),
    domain: Helper.from_env("MAILGUN_DOMAIN"),
    base_uri: Helper.from_env("MAILGUN_BASE_URI")
end

config :stripity_stripe,
  api_key: Helper.from_env("STRIPE_API_KEY")

config :hyades,
  stripe_wh_signing_key: Helper.from_env("STRIPE_WH_SIGNING_KEY"),
  stripe_public_key: Helper.from_env("STRIPE_PUBLIC_KEY"),
  yearly_price: Helper.from_env("STRIPE_YEARLY_PRICE"),
  trial_length: 30

# Get these from your Github app settings
config :hyades,
  github_client_id: Helper.from_env("GITHUB_CLIENT_ID"),
  github_client_secret: Helper.from_env("GITHUB_CLIENT_SECRET")

config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: {:system, "GITHUB_CLIENT_ID"},
  client_secret: {:system, "GITHUB_CLIENT_SECRET"}
