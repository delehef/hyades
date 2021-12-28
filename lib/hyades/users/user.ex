defmodule Hyades.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema

  use Pow.Extension.Ecto.Schema,
    extensions: [PowResetPassword]

  import Ecto.Changeset

  schema "users" do
    pow_user_fields()
    field(:billing_name, :string, default: "")

    field(:customer_id, :string, default: "")
    field(:github_token, :string, default: "")

    field(:stripe_done, :boolean, default: false)
    field(:github_done, :boolean, default: false)

    field(:show_releases, :boolean, default: true)
    field(:show_releases_body, :boolean, default: true)

    field(:show_issues, :boolean, default: true)
    field(:show_issues_body, :boolean, default: false)

    field(:show_commits, :boolean, default: false)

    timestamps()
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:email, max: 500)
    |> cast(attrs, [
      :show_releases,
      :show_releases_body,
      :show_issues,
      :show_issues_body,
      :show_commits,
      :billing_name
    ])
    |> validate_required(:billing_name)
  end
end
