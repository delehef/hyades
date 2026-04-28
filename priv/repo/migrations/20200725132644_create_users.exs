defmodule Hyades.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :string, null: false)
      add(:authenticated_at, :naive_datetime)

      add(:subscribed, :boolean, default: false)
      add(:stripe_customer_id, :string, default: "")
      add(:github_token, :string, default: "")

      add(:show_releases, :boolean, default: true)
      add(:show_releases_body, :boolean, default: true)
      add(:show_issues, :boolean, default: true)
      add(:show_issues_body, :boolean, default: false)
      add(:show_commits, :boolean, default: false)

      timestamps()
    end

    create(unique_index(:users, [:email]))

    create table(:users_tokens) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:token, :binary, null: false)
      add(:context, :string, null: false)
      add(:sent_to, :string)
      add(:authenticated_at, :naive_datetime)

      timestamps(updated_at: false)
    end

    create(index(:users_tokens, [:user_id]))
    create(unique_index(:users_tokens, [:context, :token]))
  end
end
