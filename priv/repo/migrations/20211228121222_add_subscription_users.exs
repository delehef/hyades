defmodule Hyades.Repo.Migrations.AddSubscriptionUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :subscribed, :boolean
      remove :stripe_done
      remove :billing_name
    end
  end
end
