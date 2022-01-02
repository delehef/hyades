defmodule HyadesWeb.PageController do
  use HyadesWeb, :controller

  import Pow.Plug

  def index(conn, _params) do
    if current_user(conn) do
      redirect(conn, to: Routes.user_path(conn, :landing))
    else
      render(conn, "index.html")
    end
  end

  def sample(conn, _), do: render(conn, "sample.html")
  def pricing(conn, _), do: render(conn, "pricing.html")
  def contact(conn, _), do: render(conn, "contact.html")
  def legal_notices(conn, _), do: render(conn, "legal_notices.html")
  def conditions(conn, _), do: render(conn, "conditions.html")
end
