defmodule PhxMolbind.Repo.Migrations.AddEditedAtToMessages do
  use Ecto.Migration

  # Rollback drops the column; edited messages keep their (edited) body but
  # lose the "edited" marker.
  def change do
    alter table(:messages) do
      add :edited_at, :utc_datetime_usec
    end
  end
end
