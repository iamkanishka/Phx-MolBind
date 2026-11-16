defmodule PhxMolbind.Messages.Reaction do
  @moduledoc "One user's emoji reaction to one message (at most once per emoji)."
  use Ecto.Schema
  import Ecto.Changeset

  # Emoji -> accessible name. A fixed set keeps storage bounded and the UI
  # labelled; arbitrary client-supplied strings are rejected.
  @emojis [{"👍", "thumbs up"}, {"❤️", "heart"}, {"🎉", "celebration"}, {"🧪", "test tube"}]

  schema "message_reactions" do
    field :emoji, :string
    belongs_to :message, PhxMolbind.Messages.Message
    belongs_to :user, PhxMolbind.Accounts.User

    timestamps(updated_at: false)
  end

  def emojis, do: @emojis

  @doc false
  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:emoji, :message_id, :user_id])
    |> validate_required([:emoji, :message_id, :user_id])
    |> validate_inclusion(:emoji, Enum.map(@emojis, &elem(&1, 0)))
    |> assoc_constraint(:message)
    |> unique_constraint([:message_id, :user_id, :emoji])
  end
end
