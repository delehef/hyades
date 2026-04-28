defmodule Hyades.Users.User do
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:authenticated_at, :naive_datetime, virtual: true)

    field(:subscribed, :boolean, default: true)
    field(:stripe_customer_id, :string, default: "")
    field(:github_token, :string, default: "")

    field(:show_releases, :boolean, default: true)
    field(:show_releases_body, :boolean, default: true)
    field(:show_issues, :boolean, default: true)
    field(:show_issues_body, :boolean, default: false)
    field(:show_commits, :boolean, default: false)

    timestamps()
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :email,
      :authenticated_at,
      :subscribed,
      :stripe_customer_id,
      :github_token,
      :show_releases,
      :show_releases_body,
      :show_issues,
      :show_issues_body,
      :show_commits
    ])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Hyades.Repo)
    |> unique_constraint(:email)
  end
end
