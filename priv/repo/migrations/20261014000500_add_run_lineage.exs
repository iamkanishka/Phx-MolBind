defmodule PhxMolbind.Repo.Migrations.AddRunLineage do
  use Ecto.Migration

  # Rollback drops the two columns: runs remain, but their recorded
  # derivation links are lost.
  def change do
    alter table(:molecule_optimizations) do
      # The run whose candidate this run started from. Server-verified at
      # creation (see Molecules.verified_parent/3); never inferred later.
      # Deleting the parent keeps the child, with the link cleared.
      add :parent_run_id, references(:molecule_optimizations, on_delete: :nilify_all)
      add :parent_candidate_index, :integer
    end

    create index(:molecule_optimizations, [:parent_run_id])
  end
end
