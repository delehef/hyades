defmodule Hyades.Users.Mailer do
  use Bamboo.Mailer, otp_app: :hyades
end

defmodule Hyades.Users do
  import Bamboo.Email
  import Bamboo.Phoenix
  import Ecto.Query
  alias Hyades.Github.Mailer
  alias Hyades.Repo
  alias Hyades.Users.{User, UserToken}
  use Bamboo.Phoenix, view: HyadesWeb.EmailView

  require Logger

  ## Database getters

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.
  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_by_customer_id(stripe_customer_id),
    do: Repo.get_by(User, stripe_customer_id: stripe_customer_id)

  def get_by_email(email), do: Repo.get_by(User, email: email)

  def user_exists?(email), do: Repo.exists?(Ecto.Query.from(u in User, where: u.email == ^email))

  def delete_user(id), do: Repo.delete_all(Ecto.Query.from(u in User, where: u.id == ^id))

  def create_or_fetch!(%Ueberauth.Auth{} = auth) do
    email = auth.info.email

    if user_exists?(email) do
      user = get_by_email(email)
      {:existing, Repo.update!(User.changeset(user, %{github_token: auth.credentials.token}))}
    else
      {:new, register_user(auth)}
    end
  end

  @doc """
  Registers a user.
  """
  def register_user(%Ueberauth.Auth{} = auth) do
    {:ok, stripe_customer_id} = register_on_stripe(auth.info.email)

    attrs = %{
      email: auth.info.email,
      github_token: auth.credentials.token,
      stripe_customer_id: stripe_customer_id
    }

    user =
      %User{}
      |> User.changeset(attrs)
      |> Repo.insert!()

    send_new_newsletter(user, auth.credentials.token)
    user
  end

  # defp make_github_state(user), do: :crypto.hash(:sha256, user.stripe_customer_id) |> Base.encode16()

  # def fetch_github_token(user, code) do
  #   state = make_github_state(user)
  #   github_token_url = "https://github.com/login/oauth/access_token"
  #   headers = [Accept: "application/json"]

  #   options = [
  #     params: [
  #       client_id: Application.get_env(:hyades, :github_client_id),
  #       client_secret: Application.get_env(:hyades, :github_client_secret),
  #       code: code,
  #       state: state,
  #       # redirect_uri: github_callback(conn)
  #     ]
  #   ]

  #   with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
  #          HTTPoison.post(github_token_url, "", headers, options),
  #        {:ok, %{"access_token" => token}} <- Jason.decode(body),
  #        {:ok, _} <- Repo.update(Ecto.Changeset.change(user, %{github_token: token})) do
  #     {:ok, token}
  #   end
  # end

  def register_on_stripe(email) do
    with {:ok, customer} <- Stripe.Customer.create(%{email: email}),
         {:ok, _subscription} <-
           Stripe.Subscription.create(%{
             customer: customer,
             items: [%{price: Application.get_env(:hyades, :yearly_price)}],
             trial_period_days: Application.get_env(:hyades, :trial_length)
           }) do
      {:ok, customer.id}
    else
      {:error, e} ->
        Logger.error("unable to register #{email}: #{inspect(e, pretty: true)}")
        {:error, e}
    end
  end

  def kill_user(user) do
    {:ok, _} = Stripe.Customer.delete(user.stripe_customer_id)
    delete_user(user.id)
  end

  def send_newsletter(user) do
    if check_subscription(user) do
      settings = %{
        show_issues: user.show_issues,
        show_issues_body: user.show_issues_body,
        show_releases: user.show_releases,
        show_releases_body: user.show_releases_body,
        show_commits: user.show_commits
      }

      Hyades.Github.Client.REST.get(user.github_token, settings)
      |> Hyades.Github.Email.newsletter(user.email)
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
    Repo.all(User)
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
    users = Repo.all(Ecto.Query.from(u in User, where: u.github_token == ""))

    for user <- users do
      with {:ok, _} <- Stripe.Customer.delete(user.stripe_customer_id),
           {:ok, deleted_user} <- Repo.delete(user) do
        Logger.info("Removing #{deleted_user.email}/#{deleted_user.stripe_customer_id}")
      else
        e ->
          Logger.error(
            "While removing #{user.email}/#{user.stripe_customer_id}: #{inspect(e, pretty: true)}"
          )
      end
    end
  end

  def check_subscription(user) do
    user.subscribed
  end

  def subscribe(user) do
    Logger.info("#{user.email} is now subscribed")

    Ecto.Changeset.change(user, subscribed: true)
    |> Repo.update()
  end

  def unsubscribe(user) do
    Logger.info("#{user.email} is now unsubscribed")

    Ecto.Changeset.change(user, subscribed: false)
    |> Repo.update()
  end

  def end_trial(user) do
    new_email()
    |> Bamboo.Email.from("Hyades<contact@hyades.info>")
    |> put_header("Reply-To", "contact@hyades.info")
    |> to(user.email)
    |> subject("Hyades trial will soon end")
    |> put_html_layout({HyadesWeb.EmailView, "email.html"})
    |> render(:trial_end)
    |> Mailer.deliver_later()
  end

  def payment_failed(user) do
    email =
      new_email()
      |> Bamboo.Email.from("Hyades<contact@hyades.info>")
      |> put_header("Reply-To", "contact@hyades.info")
      |> to(user.email)
      |> subject("Payment failed")
      |> put_html_layout({HyadesWeb.EmailView, "email.html"})
      |> render(:payment_failed)
      |> Mailer.deliver_now()

    case email do
      {:ok, _} ->
        Logger.info("BAMBOO: email sent")

      {:error, e} ->
        Logger.error("BAMBOO: #{e}")
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(Ecto.Query.from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(
          Ecto.Query.from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id))
        )

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(
               Ecto.Query.from(UserToken, where: [user_id: ^user.id, context: ^context])
             ) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end
end
