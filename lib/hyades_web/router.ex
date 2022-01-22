defmodule HyadesWeb.Router do
  use HyadesWeb, :router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router, extensions: [PowResetPassword]
  use PowAssent.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :skip_csrf_protection do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated, error_handler: Pow.Phoenix.PlugErrorHandler
  end

  pipeline :stripe_webhook do
    plug :put_secure_browser_headers
  end

  if Mix.env == :dev do
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
  end

  scope "/" do
    pipe_through :browser
    pow_routes()
    pow_extension_routes()
    pow_assent_routes()
  end

   scope "/" do
    pipe_through :skip_csrf_protection

    pow_assent_authorization_post_callback_routes()
  end


  scope "/", HyadesWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/pricing", PageController, :pricing
    get "/sample", PageController, :sample
    get "/contact", PageController, :contact
    get "/legal_notices", PageController, :legal_notices
    get "/conditions", PageController, :conditions
  end

  scope "/u", HyadesWeb do
    pipe_through [:browser, :protected]

    get "/", UserController, :landing
    get "/account", UserController, :account
    get "/last", UserController, :last_newsletter
    get "/billing", UserController, :billing
    delete "/delete", UserController, :delete
  end
  # Github integration
  scope "/auth/", HyadesWeb do
    pipe_through [:browser, :protected]
    get "/github_authorize", UserController, :github_register
    get "/github_back", UserController, :github_back
  end

  scope "/", HyadesWeb do
    pipe_through :stripe_webhook
    post "/stripe/hooks", StripeController, :webhooks
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: HyadesWeb.Telemetry
    end
  end
end
