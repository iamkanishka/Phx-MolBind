defmodule PhxMolbind.Repo.Migrations.AddReviewStatusToCollectionItems do
  use Ecto.Migration

  # Rollback drops the column and with it any review statuses users have set.
  def change do
    alter table(:collection_items) do
      add :review_status, :string, null: false, default: "unreviewed"
    end

    create index(:collection_items, [:collection_id, :review_status])
  end
end
