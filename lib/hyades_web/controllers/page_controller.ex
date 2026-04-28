defmodule HyadesWeb.PageController do
  use HyadesWeb, :controller

  def index(conn, _params), do: render(conn, "index.html")
  def sample(conn, _), do: render(conn, "sample.html")
  def pricing(conn, _), do: render(conn, "pricing.html")
  def contact(conn, _), do: render(conn, "contact.html")
  def legal_notices(conn, _), do: render(conn, "legal_notices.html")
  def conditions(conn, _), do: render(conn, "conditions.html")
end
