defmodule HyadesWeb.Pow.Routes do
  use Pow.Phoenix.Routes
  alias HyadesWeb.Router.Helpers, as: Routes

  @impl true
  def after_sign_in_path(conn), do: Routes.user_path(conn, :landing)

  @impl true
  def after_sign_out_path(conn), do: Routes.page_path(conn, :index)

  @impl true
  def after_registration_path(conn), do: Routes.user_path(conn, :github_register)
end
