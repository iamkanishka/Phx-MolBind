defmodule PhxMolbind.MessagesTest do
  use PhxMolbind.DataCase, async: true

  alias PhxMolbind.Messages

  import PhxMolbind.AccountsFixtures

  describe "create_message/2" do
    test "persists a message and broadcasts it to lobby subscribers" do
      user = user_fixture()
      Messages.subscribe()

      assert {:ok, message} = Messages.create_message(%{"body" => "hello"}, user.id)
      assert message.body == "hello"
      assert message.user.id == user.id
      assert_receive {:new_message, ^message}
    end

    test "rejects a blank body" do
      user = user_fixture()
      assert {:error, changeset} = Messages.create_message(%{"body" => ""}, user.id)
      assert %{body: [_]} = errors_on(changeset)
    end

    test "trims surrounding whitespace" do
      user = user_fixture()
      assert {:ok, message} = Messages.create_message(%{"body" => "  hi there  "}, user.id)
      assert message.body == "hi there"
    end
  end

  describe "list_recent_messages/1" do
    test "returns messages oldest-first, capped at the given limit" do
      user = user_fixture()

      for i <- 1..3 do
        {:ok, _} = Messages.create_message(%{"body" => "message #{i}"}, user.id)
      end

      messages = Messages.list_recent_messages(2)
      assert length(messages) == 2
      assert Enum.map(messages, & &1.body) == ["message 2", "message 3"]
    end
  end
end

defmodule PhxMolbind.MessagesEditDeleteTest do
  use PhxMolbind.DataCase, async: true

  alias PhxMolbind.Messages
  import PhxMolbind.AccountsFixtures

  setup do
    %{user: user_fixture(), other: user_fixture()}
  end

  test "authors can edit; the message is marked edited and broadcast", %{user: user} do
    {:ok, m} = Messages.create_message(%{"body" => "first"}, user.id)
    Messages.subscribe()

    assert {:ok, updated} = Messages.update_message(user.id, m.id, "  second ")
    assert updated.body == "second"
    assert updated.edited_at
    assert_receive {:message_updated, %{id: id}} when id == m.id
  end

  test "edits are validated", %{user: user} do
    {:ok, m} = Messages.create_message(%{"body" => "first"}, user.id)
    assert {:error, %Ecto.Changeset{}} = Messages.update_message(user.id, m.id, "   ")

    assert {:error, %Ecto.Changeset{}} =
             Messages.update_message(user.id, m.id, String.duplicate("a", 2001))

    assert Messages.get_message(m.id).body == "first"
  end

  test "other users cannot edit or delete someone else's message", %{user: user, other: other} do
    {:ok, m} = Messages.create_message(%{"body" => "mine"}, user.id)

    assert {:error, :not_found} = Messages.update_message(other.id, m.id, "hijacked")
    assert {:error, :not_found} = Messages.delete_message(other.id, m.id)
    assert Messages.get_message(m.id).body == "mine"
  end

  test "authors can delete; the deletion is broadcast", %{user: user} do
    {:ok, m} = Messages.create_message(%{"body" => "bye"}, user.id)
    Messages.subscribe()

    assert {:ok, _} = Messages.delete_message(user.id, m.id)
    assert Messages.get_message(m.id) == nil
    assert_receive {:message_deleted, id} when id == m.id
  end

  test "list_older_messages pages backwards from a message", %{user: user} do
    ms = for i <- 1..5, do: elem(Messages.create_message(%{"body" => "m#{i}"}, user.id), 1)
    newest_three = Enum.drop(ms, 2)
    oldest_loaded = hd(newest_three)

    assert Messages.older_exists?(oldest_loaded)
    assert Enum.map(Messages.list_older_messages(oldest_loaded, 10), & &1.body) == ["m1", "m2"]
    assert Enum.map(Messages.list_older_messages(oldest_loaded, 1), & &1.body) == ["m2"]
    refute Messages.older_exists?(hd(ms))
  end
end

defmodule PhxMolbind.MessagesRepliesReactionsTest do
  use PhxMolbind.DataCase, async: true

  alias PhxMolbind.{Messages, Repo}
  alias PhxMolbind.Messages.Reaction
  import PhxMolbind.AccountsFixtures

  setup do
    %{user: user_fixture(), other: user_fixture()}
  end

  describe "replies" do
    test "a reply references its parent and loads it with the sender", %{user: user, other: other} do
      {:ok, parent} = Messages.create_message(%{"body" => "question?"}, user.id)

      {:ok, reply} =
        Messages.create_message(%{"body" => "answer", "reply_to_id" => parent.id}, other.id)

      assert reply.reply_to.id == parent.id
      assert reply.reply_to.user.id == user.id
      assert Messages.get_message(reply.id).reply_to.body == "question?"
    end

    test "replying to a message that does not exist is rejected", %{user: user} do
      assert {:error, cs} =
               Messages.create_message(%{"body" => "orphan", "reply_to_id" => 0}, user.id)

      assert %{reply_to: [_]} = errors_on(cs)
    end

    test "deleting the parent keeps the reply, without a quote", %{user: user, other: other} do
      {:ok, parent} = Messages.create_message(%{"body" => "parent"}, user.id)

      {:ok, reply} =
        Messages.create_message(%{"body" => "child", "reply_to_id" => parent.id}, other.id)

      {:ok, _} = Messages.delete_message(user.id, parent.id)
      assert %{body: "child", reply_to: nil, reply_to_id: nil} = Messages.get_message(reply.id)
    end
  end

  describe "reactions" do
    setup %{user: user} do
      {:ok, message} = Messages.create_message(%{"body" => "react to me"}, user.id)
      %{message: message}
    end

    test "toggle adds then removes, per user and per emoji", %{
      user: user,
      other: other,
      message: m
    } do
      assert {:ok, %{reactions: [%{emoji: "👍"}]}} = Messages.toggle_reaction(user.id, m.id, "👍")
      assert {:ok, %{reactions: reactions}} = Messages.toggle_reaction(other.id, m.id, "👍")
      assert length(reactions) == 2
      assert {:ok, %{reactions: [%{user_id: uid}]}} = Messages.toggle_reaction(user.id, m.id, "👍")
      assert uid == other.id

      assert {:ok, %{reactions: reactions}} = Messages.toggle_reaction(other.id, m.id, "🧪")
      assert Enum.sort(Enum.map(reactions, & &1.emoji)) == Enum.sort(["👍", "🧪"])
    end

    test "only whitelisted emoji are accepted", %{user: user, message: m} do
      assert {:error, :invalid_emoji} = Messages.toggle_reaction(user.id, m.id, "💩")
      assert {:error, :invalid_emoji} = Messages.toggle_reaction(user.id, m.id, "<script>")
      assert Repo.aggregate(Reaction, :count) == 0
    end

    test "unknown messages are rejected", %{user: user} do
      assert {:error, :not_found} = Messages.toggle_reaction(user.id, 0, "👍")
    end

    test "the database allows each user one reaction per emoji per message", %{
      user: user,
      message: m
    } do
      attrs = %{message_id: m.id, user_id: user.id, emoji: "👍"}
      assert {:ok, _} = %Reaction{} |> Reaction.changeset(attrs) |> Repo.insert()
      assert {:error, cs} = %Reaction{} |> Reaction.changeset(attrs) |> Repo.insert()
      assert %{message_id: [_]} = errors_on(cs)
    end

    test "updates are broadcast so every client re-renders", %{user: user, message: m} do
      Messages.subscribe()
      {:ok, _} = Messages.toggle_reaction(user.id, m.id, "🎉")
      assert_receive {:message_updated, %{id: id, reactions: [%{emoji: "🎉"}]}} when id == m.id
    end

    test "deleting the message deletes its reactions", %{user: user, message: m} do
      {:ok, _} = Messages.toggle_reaction(user.id, m.id, "👍")
      {:ok, _} = Messages.delete_message(user.id, m.id)
      assert Repo.aggregate(Reaction, :count) == 0
    end
  end

  describe "molecule cards" do
    test "share_molecule creates a card and broadcasts it", %{user: user} do
      Messages.subscribe()
      assert {:ok, m} = Messages.share_molecule(user.id, "CCO", "look at this")
      assert m.smiles == "CCO" and m.body == "look at this"
      assert_receive {:new_message, %{smiles: "CCO"}}
    end

    test "malformed or oversized SMILES are rejected", %{user: user} do
      assert {:error, cs} = Messages.share_molecule(user.id, "<script>alert(1)</script>")
      assert %{smiles: [_]} = errors_on(cs)
      assert {:error, _} = Messages.share_molecule(user.id, String.duplicate("C", 501))
      assert {:error, _} = Messages.share_molecule(user.id, "")
    end

    test "ordinary messages cannot be turned into cards by passing smiles", %{user: user} do
      {:ok, m} = Messages.create_message(%{"body" => "sneaky", "smiles" => "CCO"}, user.id)
      assert m.smiles == nil
    end
  end
end
