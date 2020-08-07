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
    if user.customer_id != "", do: Stripe.Customer.delete user.customer_id
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
      user && !user.stripe_done ->
        redirect(conn, to: Routes.user_path(conn, :stripe_register))
      user && user.stripe_done && !user.github_done ->
        redirect(conn, to: Routes.user_path(conn, :github_register))
      user && user.stripe_done && user.github_done->
        redirect(conn, to: Routes.pow_registration_path(conn, :edit))
      true ->
        redirect(conn, to: Routes.page_path(conn, :index))
    end
  end

  ##
  ## Github integration
  ##
  defp make_state(user), do: :crypto.hash(:sha256, user.customer_id) |> Base.encode16
  def github_register(conn, _params) do
    user = current_user(conn)
    client_id = Application.get_env(:hyades, :github_client_id)
    redirect_uri = Routes.user_url(conn, :github_back)
    IO.puts redirect_uri
    state = user |> make_state
    github_url = "https://github.com/login/oauth/authorize?client_id=#{client_id}&redirect_uri=#{redirect_uri}&state=#{state}"
    redirect(conn, external: github_url)
  end

  def github_back(conn, %{"code" => code, "state" => gh_state}) do
    user = current_user(conn)
    state = user |> make_state

    unless state != gh_state do
      github_token_url = "https://github.com/login/oauth/access_token"
      headers = ["Accept": "application/json"]
      options = [params: [client_id: Application.get_env(:hyades, :github_client_id),
                          client_secret: Application.get_env(:hyades, :github_client_secret),
                          code: code, state: state, redirect_uri: Routes.user_url(conn, :github_back)]]
      with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.post(github_token_url, "", headers, options),
           {:ok, %{"access_token" => token}} <- Jason.decode(body),
           {:ok, new_user} <- Users.validate_github(user, token) do
        Hyades.Users.send_new_newsletter(user, token)
        conn
        |> sync_user(new_user)
        |> put_flash(:info, "Your subscription has been successful. Your first newsletter should soon arrive!")
        |> redirect(to: Routes.user_path(conn, :landing))
      else
        x ->
          Logger.error "while registering #{user.email}: #{inspect(x, pretty: true)}"
        fail(conn, "An error happened while authenticating with Github")
      end
    else
      Logger.error "differing states while registering #{user.email}"
      fail(conn, "An error happened while authenticating with Github")
    end
  end



  ##
  ## Stripe integration
  ##
  # If the user has already subscribed, just redirect them to their homepage.
  # Otherwise, make them subscribe.
  def stripe_register(conn, _params) do
    render(conn, "plans.html", pk: Application.get_env(:hyades, :stripe_public_key))
  end

  # AJAX-ed from the subscription page.
  # Returns the Stripe Session corresponding to the chosen plan.
  def stripe_plans(conn, %{"type" => type}) do
    price = case type do
              "monthly" -> Application.get_env(:hyades, :monthly_price)
              "yearly" -> Application.get_env(:hyades, :yearly_price)
            end

    with {:ok, session} <- Stripe.Session.create(
           %{payment_method_types: ["card"],
             customer: current_user(conn).customer_id,
             mode: "subscription",
             line_items: [%{price: price, quantity: 1}],
             subscription_data: %{trial_from_plan: true},
             success_url: Routes.user_url(conn, :stripe_success),
             cancel_url: Routes.page_url(conn, :index)}) do
      json(conn, %{id: session.id})
    end
  end

  defp sync_user(conn, user), do: Pow.Plug.create(conn, user)
  def stripe_success(conn, _params) do
    user = current_user(conn)
    case Users.validate_stripe(user) do
      {:ok, new_user} ->
        conn
        |> sync_user(new_user)
        |> redirect(to: Routes.user_path(conn, :landing))
      {:error, e} ->
        Logger.error "While subscribing #{user.email}: #{inspect(e)}"
        fail(conn, "An error happened during the payment process")
    end
  end

  # Called if the user cancel the subscription in the Stripe popup.
  # If the user still exists in the database, remove it.
  # In any case, unlog it, display a flash, then go back home
  def stripe_cancel(conn, _params) do
    user = current_user(conn)
    Logger.warn "#{user.email} has cancelled their payment process"
    fail(conn, "An error happened during the payment process")
  end

  def billing(conn, _params) do
    user = current_user(conn)
    with {:ok, _} <- Stripe.Customer.update(user.customer_id, %{email: user.email}),
         {:ok, portal} <- Stripe.BillingPortal.Session.create(%{
               customer: user.customer_id,
               return_url: Routes.pow_registration_url(conn, :edit)}) do
      redirect(conn, external: portal.url)
    else {:error, e} ->
        Logger.error "while #{user.email} accessed their portal: #{inspect(e)}"
      conn
      |> put_flash(:error, "An error occured while loading your billing portal; please contact the support")
      |> redirect(to: Routes.pow_registration_path(conn, :edit))
    end
  end

  def delete(conn, _params) do
    user = current_user(conn)
    with {:ok, _} <- Hyades.Users.kill_user(conn, user) do
      conn
      |> Pow.Plug.delete
      |> put_flash(:info, "Your subscription has been succesfully cancelled")
      |> redirect(to: Routes.page_path(conn, :index))
    else
      e ->
        Logger.error "while removing #{user.email}: #{inspect e, pretty: true}"
      conn
      |> put_flash(:error, "An error occured while deleting your account; please contact the support")
      |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  def last_newsletter(conn, _params) do
    user = current_user(conn)
    with {:ok, subscriptions} <- Stripe.Subscription.list(%{customer: user.customer_id, status: "active"}) do
      Task.async(fn -> Hyades.Users.send_newsletter(user) end)
      conn
      |> put_flash(:info, "You should soon receive your newsletter")
      |> redirect(to: Routes.page_path(conn, :index))
    else
      e ->
        Logger.error "while sending a newsletter to #{user.email}: #{inspect e, pretty: true}"
      conn
      |> put_flash(:error, "It looks like your subscription is not valid anymore.")
      |> redirect(to: Routes.page_path(conn, :index))
    end
  end
end
