defmodule Hyades.Users do
  require Logger

  import Ecto.Query

  use Pow.Ecto.Context,
    repo: Hyades.Repo,
    user: Hyades.Users.User

  @impl true
  def create(params) do
    case pow_create(params) do
      {:ok, user} ->
        register_stripe(user)
      {:error, e} ->
        Logger.error "Unable to register #{params["email"]} -- #{inspect e, pretty: true}"
        {:error, e}
    end
  end

  def register_stripe(user) do
    with {:ok, customer} <- Stripe.Customer.create(%{email: user.email, name: user.billing_name}),
         {:ok, user} <- Ecto.Changeset.change(user, customer_id: customer.id) |> Hyades.Repo.update do
      {:ok, user}
    else
      {:error, e} ->
        Logger.error("unable to register #{}: #{inspect e, pretty: true}")
      Hyades.Repo.delete(user)
      {:error, "Unable to create a Stripe customer"}
    end
  end

  def validate_stripe(user) do
    Ecto.Changeset.change(user, stripe_done: true)
    |> Hyades.Repo.update
  end

  def validate_github(user, token) do
    Ecto.Changeset.change(user, %{github_done: true, github_token: token})
    |> Hyades.Repo.update
  end

  def kill_user(conn, user) do
    config = Pow.Plug.fetch_config(conn)
    with {:ok, _} <- Stripe.Customer.delete(user.customer_id),
         {:ok, _} <- Pow.Operations.delete(user, config) do
      {:ok, nil}
    end
  end

  def send_newsletter(user) do
    case check_subscription(user) do
      true ->
        email = user.email
        settings = %{show_issues: user.show_issues, show_issues_body: user.show_issues_body,
                     show_releases: user.show_releases, show_releases_body: user.show_releases_body,
                     show_commits: user.show_commits}
        Hyades.Github.Client.REST.get(user.github_token, settings)
        |> Hyades.Github.Email.newsletter(email)
        |> Hyades.Github.Mailer.deliver_now()
      e ->
        Logger.error "in send_newsletter to #{user.email}: #{inspect e, pretty: true}"
    end
  end

  def send_new_newsletter(user, token) do
    case check_subscription(user) do
      true ->
        Task.async(fn ->
          settings = %{show_issues: user.show_issues, show_issues_body: user.show_issues_body,
                       show_releases: user.show_releases, show_releases_body: user.show_releases_body,
                       show_commits: user.show_commits}
          Hyades.Github.Client.REST.get(token, settings)
          |> Hyades.Github.Email.newsletter(user.email)
          |> Hyades.Github.Mailer.deliver_now()
        end)
        {:ok, "sent"}
      _ ->
    end
  end

  def send_all_newsletters do
    Hyades.Repo.all(Hyades.Users.User)
    |> Enum.each(fn user ->
      unless user.github_token == "" do
        try do
          send_newsletter(user)
        rescue
          e ->
            Logger.error "while sending newsletter to #{user.email}: #{inspect e, pretty: true}"
        end
      else
        Logger.error "#{user.email} has no github token; skipping"
      end
    end)
  end


  def check_subscription(user) do
    with {:ok, subscriptions_active} <- Stripe.Subscription.list(%{customer: user.customer_id, status: "active"}),
         {:ok, subscriptions_trial} <- Stripe.Subscription.list(%{customer: user.customer_id, status: "trialing"}) do
      !(Enum.empty?(subscriptions_active.data) && Enum.empty?(subscriptions_trial.data))
    else
      false
    end
  end
end
