defmodule HyadesWeb.UserController do
  use HyadesWeb, :controller
  require Logger

  alias Hyades.Users
  alias Hyades.Users.User

  plug(Ueberauth)

  ##
  ## General pages
  ##
  def landing(conn, _params) do
    user = conn.assigns.current_scope.user

    cond do
      user && (user.github_token == "" || user.stripe_customer_id == "") ->
        redirect(conn, to: ~p"/")

      user ->
        redirect(conn, to: ~p"/u/settings")
    end
  end

  ##
  ## Github integration
  ##
  def callback(%{assigns: %{ueberauth_failure: %Ueberauth.Failure{} = failure}} = conn, _params) do
    Logger.error("GH authentication failed: #{inspect(failure)}")

    conn
    |> put_flash(:error, "Failed to authenticate")
    |> redirect(to: ~p"/")
  end

  def callback(%{assigns: %{ueberauth_auth: %Ueberauth.Auth{} = auth}} = conn, _params) do
    {state, user} = Users.create_or_fetch!(auth)
    HyadesWeb.UserAuth.log_in_user(conn, user)

    case state do
      :existing ->
        conn

      :new ->
        conn
        |> put_flash(
          :info,
          "Your subscription has been successful. Your first newsletter will soon arrive!"
        )
    end
    |> redirect(to: ~p"/u/settings")
  end

  def logout(conn, _params) do
    conn
    |> HyadesWeb.UserAuth.log_out_user()
    |> put_flash(:info, "You have been logged out")
    |> redirect(to: ~p"/u")
  end

  def settings(%{assigns: %{current_scope: %{user: user}}} = conn, _params) do
    user = Users.get_user!(user.id)
    render(conn, :settings, changeset: User.changeset(user, %{}))
  end

  def update_settings(conn, %{"user" => user_params}) do
    user = Users.get_user!(conn.assigns.current_scope.user.id)

    case Users.update_user(user, user_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Settings updated successfully.")
        |> redirect(to: ~p"/u/settings")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, user: user, changeset: changeset)
    end
  end

  # def callback(conn, %{"code" => code, "state" => gh_state}) do
  #   user = nil

  #   with {:ok, github_token} <- User.fetch_github_token(user),
  #        {:ok, user} <- Users.register_stripe(user) do

  #     conn
  #     |> put_flash(
  #       :info,
  #       "Your subscription has been successful. Your first newsletter will soon arrive!"
  #     )
  #     |> redirect(to: ~p"/u")
  #   else
  #     x ->
  #       Logger.error("while registering #{user.email}: #{inspect(x, pretty: true)}")
  #       fail(conn, "An error happened while authenticating with Github")
  #   end
  # end

  ##
  ## Stripe integration
  ##
  def billing(conn, _params) do
    user = conn.assigns.current_scope.user

    with {:ok, _} <- Stripe.Customer.update(user.stripe_customer_id, %{email: user.email}),
         {:ok, portal} <-
           Stripe.BillingPortal.Session.create(%{
             customer: user.stripe_customer_id,
             return_url: Phoenix.VerifiedRoutes.url(conn, ~p"/u")
           }) do
      redirect(conn, external: portal.url)
    else
      {:error, e} ->
        Logger.error("while #{user.email} accessed their portal: #{inspect(e)}")

        conn
        |> put_flash(
          :error,
          "An error occurred while loading your billing portal; please contact the support"
        )
        |> redirect(to: ~p"/u/settings")
    end
  end

  def delete(conn, _params) do
    user = conn.assigns.current_scope.user
    Hyades.Users.kill_user(user)

    conn
    |> HyadesWeb.UserAuth.log_out_user()
    |> put_flash(:info, "Your subscription has been successfully cancelled")
    |> redirect(to: ~p"/")
  end

  def last_newsletter(conn, _params) do
    user = conn.assigns.current_scope.user

    case Users.check_subscription(user) do
      true ->
        Task.async(fn -> Hyades.Users.send_newsletter(user) end)

        conn
        |> put_flash(:info, "You should soon receive your newsletter")
        |> redirect(to: ~p"/u/settings")

      e ->
        Logger.error("while sending a newsletter to #{user.email}: #{inspect(e, pretty: true)}")

        conn
        |> put_flash(:error, "It looks like your subscription is not valid anymore.")
        |> redirect(to: ~p"/u/settings")
    end
  end
end
