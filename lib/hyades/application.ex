defmodule Hyades.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Hyades.Repo,
      # Start the Telemetry supervisor
      HyadesWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Hyades.PubSub},
      # Start the Endpoint (http/https)
      HyadesWeb.Endpoint,
      # Start a worker by calling: Hyades.Worker.start_link(arg)
      # {Hyades.Worker, arg}
      Hyades.Cron
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hyades.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    HyadesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
