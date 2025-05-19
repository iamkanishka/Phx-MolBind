defmodule PhxMolbind.Repo.Migrations.CreateMoleculeAndUser do
  use Ecto.Migration

  def change do
    create table(:molecule_optimizations) do
      add :algorithm, :string, null: false
      add :num_molecules, :integer, null: false
      add :property_name, :string, null: false
      add :minimize, :boolean, default: false, null: false
      add :min_similarity, :float, null: false
      add :particles, :integer, null: false
      add :iterations, :integer, null: false
      add :smiles, :text, null: false
      add :generated_molecules, :map, default: %{}
      add :user_id, :text, null: false

      timestamps()
    end
  end
end
