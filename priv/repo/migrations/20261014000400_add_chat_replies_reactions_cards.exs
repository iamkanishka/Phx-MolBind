defmodule PhxMolbind.Repo.Migrations.AddChatRepliesReactionsCards do
  use Ecto.Migration

  # Rollback drops reactions and the two new message columns (reply links and
  # shared-molecule SMILES); message bodies themselves are kept.
  def change do
    alter table(:messages) do
      # Deleting the parent keeps the reply, just without a quote.
      add :reply_to_id, references(:messages, on_delete: :nilify_all)
      # Set only by trusted server code when sharing a molecule card.
      add :smiles, :text
    end

    create index(:messages, [:reply_to_id])

    create table(:message_reactions) do
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :emoji, :string, null: false

      timestamps(updated_at: false)
    end

    create unique_index(:message_reactions, [:message_id, :user_id, :emoji])
    create index(:message_reactions, [:user_id])
  end
end
