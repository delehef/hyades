defmodule HyadesWeb.Router do
  use HyadesWeb, :router
  import HyadesWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:put_root_layout, html: {HyadesWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
  end

  pipeline :stripe_webhook do
    plug(:put_secure_browser_headers)
  end

  if Mix.env() == :dev do
    forward("/sent_emails", Bamboo.SentEmailViewerPlug)
  end

  scope "/" do
    pipe_through(:browser)
  end

  scope "/", HyadesWeb do
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/pricing", PageController, :pricing)
    get("/sample", PageController, :sample)
    get("/contact", PageController, :contact)
    get("/legal_notices", PageController, :legal_notices)
    get("/conditions", PageController, :conditions)
    get("/u/create", UserController, :signup)
  end

  scope "/u", HyadesWeb do
    pipe_through([:browser, :require_authenticated_user])

    get("/", UserController, :landing)
    delete("/", UserController, :logout)
    get("/settings", UserController, :settings)
    put("/settings", UserController, :update_settings)
    get("/last", UserController, :last_newsletter)
    get("/billing", UserController, :billing)
    delete("/delete", UserController, :delete)
  end

  # Github integration
  scope "/auth", HyadesWeb do
    pipe_through(:browser)

    get("/:provider", UserController, :request)
    get("/:provider/callback", UserController, :callback)
  end

  scope "/", HyadesWeb do
    pipe_through(:stripe_webhook)
    post("/stripe/hooks", StripeController, :webhooks)
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
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: HyadesWeb.Telemetry)
    end
  end
end
