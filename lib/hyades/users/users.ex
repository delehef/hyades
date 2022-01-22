defmodule Hyades.Users.Mailer do
  use Bamboo.Mailer, otp_app: :hyades
end

defmodule Hyades.Users do
  import Ecto.Query
  import Bamboo.Email
  import Bamboo.Phoenix
  use Bamboo.Phoenix, view: HyadesWeb.EmailView

  require Logger

  use Pow.Ecto.Context,
    repo: Hyades.Repo,
    user: Hyades.Users.User

  def register_stripe(user) do
    if user.customer_id == "" do
      with {:ok, customer} <- Stripe.Customer.create(%{email: user.email}),
           {:ok, _subscription} <-
      Stripe.Subscription.create(%{
            customer: customer,
            items: [%{price: Application.get_env(:hyades, :yearly_price)}],
            trial_period_days: Application.get_env(:hyades, :trial_length)
                                 }),
      {:ok, user} <-
      Ecto.Changeset.change(user, customer_id: customer.id) |> Hyades.Repo.update() do
        {:ok, user}
      else
        {:error, e} ->
          Logger.error("unable to register #{}: #{inspect(e, pretty: true)}")
        Hyades.Repo.delete(user)
        {:error, "Unable to create a Stripe customer"}
      end
    else
      {:ok, user}
    end
  end

  def validate_github(user, token) do
    Ecto.Changeset.change(user, %{github_done: true, github_token: token})
    |> Hyades.Repo.update()
  end

  def kill_user(conn, user) do
    config = Pow.Plug.fetch_config(conn)

    with {:ok, _} <- Stripe.Customer.delete(user.customer_id),
         {:ok, _} <- Pow.Operations.delete(user, config) do
      {:ok, nil}
    end
  end

  def send_newsletter(user) do
    if check_subscription(user) do
      email = user.email

      settings = %{
        show_issues: user.show_issues,
        show_issues_body: user.show_issues_body,
        show_releases: user.show_releases,
        show_releases_body: user.show_releases_body,
        show_commits: user.show_commits
      }

      Hyades.Github.Client.REST.get(user.github_token, settings)
      |> Hyades.Github.Email.newsletter(email)
      |> Hyades.Github.Mailer.deliver_now!()
    else
      Logger.error("#{user.email} does not appear to be subscribed anymore")
    end
  end

  def send_new_newsletter(user, token) do
    if check_subscription(user) do
      Task.async(fn ->
        settings = %{
          show_issues: user.show_issues,
          show_issues_body: user.show_issues_body,
          show_releases: user.show_releases,
          show_releases_body: user.show_releases_body,
          show_commits: user.show_commits
        }

        Hyades.Github.Client.REST.get(token, settings)
        |> Hyades.Github.Email.newsletter(user.email)
        |> Hyades.Github.Mailer.deliver_now!()
      end)

      {:ok, "sent"}
    else
      {:error, "not_subscribed"}
    end
  end

  def send_all_newsletters do
    Hyades.Repo.all(Hyades.Users.User)
    |> Enum.each(fn user ->
      if user.github_token == "" do
        Logger.error("#{user.email} has no github token; skipping")
      else
        try do
          send_newsletter(user)
        rescue
          e ->
            Logger.error("while sending newsletter to #{user.email}: #{inspect(e, pretty: true)}")
        end
      end
    end)
  end

  def clean_spam do
    users = Hyades.Repo.all(Ecto.Query.from u in Hyades.Users.User, where: u.github_token == "")

    for user <- users do
      with {:ok, _} <- Stripe.Customer.delete(user.customer_id),
           {:ok, deleted_user} <- Hyades.Repo.delete(user) do
        Logger.info("Removing #{deleted_user.email}/#{deleted_user.customer_id}")
      else
        e -> Logger.error("While removing #{user.email}/#{user.customer_id}: #{inspect(e, pretty: true)}")
      end
    end
  end

  def check_subscription(user) do
    user.subscribed
  end

  def subscribe(user) do
    Logger.info("#{user.email} is now subscribed")

    Ecto.Changeset.change(user, subscribed: true)
    |> Hyades.Repo.update()
  end

  def unsubscribe(user) do
    Logger.info("#{user.email} is now unsubscribed")

    Ecto.Changeset.change(user, subscribed: false)
    |> Hyades.Repo.update()
  end

  def end_trial(user) do
    new_email()
    |> Bamboo.Email.from("Hyades<contact@hyades.info>")
    |> put_header("Reply-To", "contact@hyades.info")
    |> to(user.email)
    |> subject("Hyades trial will soon end")
    |> put_html_layout({HyadesWeb.LayoutView, "email.html"})
    |> render(:trial_end)
    |> Hyades.Users.Mailer.deliver_later()
  end

  def payment_failed(user) do
    email =
      new_email()
      |> Bamboo.Email.from("Hyades<contact@hyades.info>")
      |> put_header("Reply-To", "contact@hyades.info")
      |> to(user.email)
      |> subject("Payment failed")
      |> put_html_layout({HyadesWeb.LayoutView, "email.html"})
      |> render(:payment_failed)
      |> Hyades.Users.Mailer.deliver_now()

    case email do
      {:ok, _} ->
        Logger.info("BAMBOO: email sent")

      {:error, e} ->
        Logger.error("BAMBOO: #{e}")
    end
  end

  def get_by_customer_id(customer_id) do
    Hyades.Repo.get_by(Hyades.Users.User, customer_id: customer_id)
  end
end
