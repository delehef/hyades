defmodule HyadesWeb.UserController do
  use HyadesWeb, :controller
  require Logger

  import Pow.Plug

  alias Hyades.Users
  alias Hyades.Users.User

  ##
  ## Helper functions
  ##
  defp fail(conn, message) do
    user = current_user(conn)
    config = Pow.Plug.fetch_config(conn)
    if user.customer_id != "", do: Stripe.Customer.delete(user.customer_id)
    if Hyades.Repo.get_by(User, id: user.id), do: Pow.Operations.delete(user, config)

    conn
    |> put_flash(:error, "#{message}; your subscription has been cancelled")
    |> redirect(to: Routes.page_path(conn, :index))
  end

  ##
  ## General pages
  ##
  def landing(conn, _params) do
    user = current_user(conn)

    cond do
      user && !user.github_done ->
        redirect(conn, to: Routes.user_path(conn, :github_register))

      user && user.github_done ->
        redirect(conn, to: Routes.pow_registration_path(conn, :edit))

      user ->
        redirect(conn, to: Routes.pow_registration_path(conn, :edit))

      true ->
        redirect(conn, to: Routes.page_path(conn, :index))
    end
  end

  ##
  ## Github integration
  ##
  defp make_state(user), do: :crypto.hash(:sha256, user.customer_id) |> Base.encode16()

  def github_register(conn, _params) do
    user = current_user(conn)
    client_id = Application.get_env(:hyades, :github_client_id)
    redirect_uri = Routes.user_url(conn, :github_back)
    state = user |> make_state

    github_url =
      "https://github.com/login/oauth/authorize?client_id=#{client_id}&redirect_uri=#{redirect_uri}&state=#{state}"

    redirect(conn, external: github_url)
  end

  def github_back(conn, %{"code" => code, "state" => gh_state}) do
    user = current_user(conn)
    state = user |> make_state

    if state == gh_state do
      github_token_url = "https://github.com/login/oauth/access_token"
      headers = [Accept: "application/json"]

      options = [
        params: [
          client_id: Application.get_env(:hyades, :github_client_id),
          client_secret: Application.get_env(:hyades, :github_client_secret),
          code: code,
          state: state,
          redirect_uri: Routes.user_url(conn, :github_back)
        ]
      ]

      with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
             HTTPoison.post(github_token_url, "", headers, options),
           {:ok, %{"access_token" => token}} <- Jason.decode(body),
           {:ok, user} <- Users.register_stripe(user),
           {:ok, user} <- Users.validate_github(user, token) do
        Hyades.Users.send_new_newsletter(user, token)

        conn
        |> sync_user(user)
        |> put_flash(
          :info,
          "Your subscription has been successful. Your first newsletter will soon arrive!"
        )
        |> redirect(to: Routes.user_path(conn, :landing))
      else
        x ->
          Logger.error("while registering #{user.email}: #{inspect(x, pretty: true)}")
          fail(conn, "An error happened while authenticating with Github")
      end
    else
      Logger.error("differing states while registering #{user.email}")
      fail(conn, "An error happened while authenticating with Github")
    end
  end

  ##
  ## Stripe integration
  ##
  defp sync_user(conn, user), do: Pow.Plug.create(conn, user)

  def billing(conn, _params) do
    user = current_user(conn)

    with {:ok, _} <- Stripe.Customer.update(user.customer_id, %{email: user.email}),
         {:ok, portal} <-
           Stripe.BillingPortal.Session.create(%{
             customer: user.customer_id,
             return_url: Routes.pow_registration_url(conn, :edit)
           }) do
      redirect(conn, external: portal.url)
    else
      {:error, e} ->
        Logger.error("while #{user.email} accessed their portal: #{inspect(e)}")

        conn
        |> put_flash(
          :error,
          "An error occured while loading your billing portal; please contact the support"
        )
        |> redirect(to: Routes.pow_registration_path(conn, :edit))
    end
  end

  def delete(conn, _params) do
    user = current_user(conn)

    case Hyades.Users.kill_user(conn, user) do
      {:ok, _} ->
        conn
        |> Pow.Plug.delete()
        |> put_flash(:info, "Your subscription has been succesfully cancelled")
        |> redirect(to: Routes.page_path(conn, :index))

      e ->
        Logger.error("while removing #{user.email}: #{inspect(e, pretty: true)}")

        conn
        |> put_flash(
          :error,
          "An error occured while deleting your account; please contact the support"
        )
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  def last_newsletter(conn, _params) do
    user = current_user(conn)

    case Users.check_subscription(user) do
      true ->
        Task.async(fn -> Hyades.Users.send_newsletter(user) end)

        conn
        |> put_flash(:info, "You should soon receive your newsletter")
        |> redirect(to: Routes.page_path(conn, :index))

      e ->
        Logger.error("while sending a newsletter to #{user.email}: #{inspect(e, pretty: true)}")

        conn
        |> put_flash(:error, "It looks like your subscription is not valid anymore.")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end
end
