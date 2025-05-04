defmodule PhxMolbind.Repo.Migrations.CreateMolecule do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :address, :string, null: false
      add :last_login_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:users, [:address])

    create table(:molecule_optimizations) do
      add :algorithm, :string, null: false
      add :num_molecules, :integer, null: false
      add :property_name, :string, null: false
      add :minimize, :boolean, default: false, null: false
      add :min_similarity, :float, null: false
      add :particles, :integer, null: false
      add :iterations, :integer, null: false
      add :smi, :text, null: false
      add :generated_molecules, :map, default: %{}
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:molecule_optimizations, [:user_id])
  end
end
