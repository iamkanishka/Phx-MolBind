defmodule PhxMolbind.Repo.Migrations.CreateShareLinks do
  use Ecto.Migration

  # Rollback drops the table, which revokes every share link at once.
  def change do
    create table(:share_links) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # "run" or "collection"; target_id is polymorphic, so it has no FK.
      # Resolution re-checks that the target still exists.
      add :kind, :string, null: false
      add :target_id, :bigint, null: false
      # SHA-256 of the secret token. The token itself is never stored.
      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:share_links, [:token_hash])
    create index(:share_links, [:user_id])
    create index(:share_links, [:kind, :target_id])
  end
end
