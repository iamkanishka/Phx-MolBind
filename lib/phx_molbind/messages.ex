defmodule PhxMolbind.Messages do
  @moduledoc """
  The Messages context: a single shared "research chat" lobby.

  Real-time delivery is via `Phoenix.PubSub` on the `"chat:lobby"` topic —
  every connected LiveView subscribes on mount and broadcasts get pushed to
  everyone currently in the room. Messages are also persisted so the
  history is there when someone joins later.
  """

  import Ecto.Query, warn: false

  alias PhxMolbind.Repo
  alias PhxMolbind.Messages.{Message, Reaction}

  @topic "chat:lobby"
  # Everything a rendered message needs, loaded in one pass (no N+1).
  @preloads [:user, :reactions, reply_to: :user]

  @doc "Returns the most recent `limit` messages, oldest first, with the sender preloaded."
  def list_recent_messages(limit \\ 50) do
    Message
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload(^@preloads)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Creates a message on behalf of `user_id` and broadcasts it to everyone
  subscribed to the lobby.
  """
  def create_message(attrs, user_id) do
    %Message{}
    |> Message.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message = Repo.preload(message, @preloads)
        Phoenix.PubSub.broadcast(PhxMolbind.PubSub, @topic, {:new_message, message})
        {:ok, message}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc "Emoji reactions available in the UI, as `[{emoji, accessible_name}]`."
  def reaction_emojis, do: Reaction.emojis()

  @doc """
  Toggles the user's reaction on a message and broadcasts the updated message
  so every open chat re-renders it. Returns `{:ok, message}`,
  `{:error, :invalid_emoji}` or `{:error, :not_found}`.
  """
  def toggle_reaction(user_id, message_id, emoji) do
    cond do
      emoji not in Enum.map(Reaction.emojis(), &elem(&1, 0)) ->
        {:error, :invalid_emoji}

      is_nil(Repo.get(Message, message_id)) ->
        {:error, :not_found}

      true ->
        case Repo.get_by(Reaction, message_id: message_id, user_id: user_id, emoji: emoji) do
          nil ->
            %Reaction{}
            |> Reaction.changeset(%{message_id: message_id, user_id: user_id, emoji: emoji})
            |> Repo.insert()

          reaction ->
            Repo.delete(reaction)
        end

        message = get_message(message_id)
        Phoenix.PubSub.broadcast(PhxMolbind.PubSub, @topic, {:message_updated, message})
        {:ok, message}
    end
  end

  @doc """
  Posts a molecule card. `smiles` must come from a record the caller has
  already verified the user owns (a run candidate, a saved item, ...): it is
  never taken from client input. `caption` is the message text.
  """
  def share_molecule(user_id, smiles, caption \\ "Shared a molecule") do
    %Message{}
    |> Message.molecule_changeset(%{"body" => caption, "user_id" => user_id}, smiles)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message = Repo.preload(message, @preloads)
        Phoenix.PubSub.broadcast(PhxMolbind.PubSub, @topic, {:new_message, message})
        {:ok, message}

      error ->
        error
    end
  end

  @doc "Fetches one message (sender preloaded), or nil."
  def get_message(id), do: Message |> Repo.get(id) |> Repo.preload(@preloads)

  @doc """
  Edits the body of a message the user wrote. Other users' messages behave
  exactly like missing ones. Broadcasts `{:message_updated, message}`.
  """
  def update_message(user_id, id, body) do
    case Repo.get_by(Message, id: id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      message ->
        with {:ok, updated} <-
               message |> Message.edit_changeset(%{"body" => body}) |> Repo.update() do
          updated = Repo.preload(updated, @preloads)
          Phoenix.PubSub.broadcast(PhxMolbind.PubSub, @topic, {:message_updated, updated})
          {:ok, updated}
        end
    end
  end

  @doc """
  Deletes a message the user wrote. Broadcasts `{:message_deleted, id}`.
  """
  def delete_message(user_id, id) do
    case Repo.get_by(Message, id: id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      message ->
        with {:ok, deleted} <- Repo.delete(message) do
          Phoenix.PubSub.broadcast(PhxMolbind.PubSub, @topic, {:message_deleted, deleted.id})
          {:ok, deleted}
        end
    end
  end

  @doc "Up to `limit` messages older than `message`, oldest first."
  def list_older_messages(%Message{} = message, limit \\ 50) do
    Message
    |> where(
      [m],
      m.inserted_at < ^message.inserted_at or
        (m.inserted_at == ^message.inserted_at and m.id < ^message.id)
    )
    |> order_by([m], desc: m.inserted_at, desc: m.id)
    |> limit(^limit)
    |> preload(^@preloads)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc "Whether any message is older than `message`."
  def older_exists?(%Message{} = message) do
    Repo.exists?(
      from m in Message,
        where:
          m.inserted_at < ^message.inserted_at or
            (m.inserted_at == ^message.inserted_at and m.id < ^message.id)
    )
  end

  @doc "Subscribes the calling process to new lobby messages."
  def subscribe do
    Phoenix.PubSub.subscribe(PhxMolbind.PubSub, @topic)
  end
end
