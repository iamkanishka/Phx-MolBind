
defmodule PhxMolbind.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :address, :string, null: false
      add :nonce, :string, null: false
      add :username, :string
      add :metadata, :map, default: %{}
      add :last_login_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:users, [:address])
  end
end
