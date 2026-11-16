defmodule PhxMolbind.Repo.Migrations.CreateCollections do
  use Ecto.Migration

  # Rollback: `mix ecto.rollback` drops both tables. Collections and their
  # saved candidates are user-created data, so take a backup first if any
  # exist. Generation runs (molecule_optimizations) are never touched.
  def change do
    create table(:collections) do
      add :name, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:collections, [:user_id, :name])

    create table(:collection_items) do
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      # Denormalised owner so every query can be scoped by user_id directly.
      # The context guarantees it always equals the collection's owner.
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :smiles, :text, null: false
      add :score, :float
      add :property_name, :string
      # Provenance only. Deleting the run keeps the saved candidate.
      add :source_run_id, references(:molecule_optimizations, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:collection_items, [:collection_id, :smiles])
    create index(:collection_items, [:user_id])
    create index(:collection_items, [:source_run_id])
  end
end
