defmodule PhxMolbindWeb.MessagesLive.ChatTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PhxMolbind.AccountsFixtures

  alias PhxMolbind.Messages

  setup :register_and_log_in_user

  test "renders existing messages on mount", %{conn: conn, user: user} do
    {:ok, _msg} = Messages.create_message(%{"body" => "already here"}, user.id)

    {:ok, _view, html} = live(conn, ~p"/message")
    assert html =~ "already here"
  end

  test "sending a message renders it for the sender", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/message")

    view
    |> form("#chat-form", message: %{body: "hello lobby"})
    |> render_submit()

    # The sender sees their message via the PubSub broadcast, which is
    # handled right after the submit event; render/1 waits for it.
    assert render(view) =~ "hello lobby"
  end

  test "a message from another connected client shows up via PubSub", %{conn: conn, user: user} do
    other = user_fixture()
    {:ok, view, _html} = live(conn, ~p"/message")

    {:ok, _message} = Messages.create_message(%{"body" => "from someone else"}, other.id)

    assert render(view) =~ "from someone else"
    refute user.id == other.id
  end

  test "submitting a blank message is a no-op", %{conn: conn} do
    {:ok, view, html_before} = live(conn, ~p"/message")

    html_after =
      view
      |> form("#chat-form", message: %{body: "   "})
      |> render_submit()

    assert html_before =~ "Drug Discovery Chat"
    assert html_after =~ "Drug Discovery Chat"
  end
end

defmodule PhxMolbindWeb.MessagesLive.ChatEditDeleteTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PhxMolbind.AccountsFixtures

  alias PhxMolbind.Messages

  setup :register_and_log_in_user

  test "only the author sees Edit/Delete controls", %{conn: conn, user: user} do
    other = user_fixture()
    {:ok, _} = Messages.create_message(%{"body" => "mine"}, user.id)
    {:ok, theirs} = Messages.create_message(%{"body" => "theirs"}, other.id)

    {:ok, view, html} = live(conn, ~p"/message")
    assert html =~ ~s(phx-click="edit")

    # Reply and reactions are for everyone; edit/delete only for the author.
    refute html =~ ~r/phx-click="(edit|ask_delete)"[^>]*phx-value-id="#{theirs.id}"/

    # Forged event for someone else's message changes nothing.
    render_click(view, "edit", %{"id" => to_string(theirs.id)})
    refute render(view) =~ ~s(id="edit-#{theirs.id}")
  end

  test "editing updates the message and marks it edited", %{conn: conn, user: user} do
    {:ok, m} = Messages.create_message(%{"body" => "before"}, user.id)
    {:ok, view, _} = live(conn, ~p"/message")

    assert render_click(view, "edit", %{"id" => to_string(m.id)}) =~ ~s(id="edit-#{m.id}")

    html = render_submit(view, "save_edit", %{"message_id" => to_string(m.id), "body" => "after"})
    assert html =~ "after"
    assert html =~ "(edited)"
    refute html =~ "before"
  end

  test "deleting asks first, then removes the message for everyone", %{conn: conn, user: user} do
    {:ok, m} = Messages.create_message(%{"body" => "ephemeral-zq81"}, user.id)
    {:ok, view, _} = live(conn, ~p"/message")

    assert render_click(view, "ask_delete", %{"id" => to_string(m.id)}) =~ "Delete this message?"
    assert Messages.get_message(m.id)

    render_click(view, "delete", %{"id" => to_string(m.id)})
    refute render(view) =~ "ephemeral-zq81"
    assert Messages.get_message(m.id) == nil
  end

  test "cannot delete another user's message", %{conn: conn} do
    other = user_fixture()
    {:ok, theirs} = Messages.create_message(%{"body" => "theirs"}, other.id)
    {:ok, view, _} = live(conn, ~p"/message")

    assert render_click(view, "delete", %{"id" => to_string(theirs.id)}) =~
             "That message could not be found."

    assert Messages.get_message(theirs.id)
  end

  test "load older appears only when there is more history", %{conn: conn, user: user} do
    for i <- 1..55, do: Messages.create_message(%{"body" => "msg #{i}"}, user.id)
    {:ok, view, html} = live(conn, ~p"/message")
    assert html =~ "Load older messages"

    html = render_click(view, "load_older", %{})
    assert html =~ "msg 1<"
    refute html =~ "Load older messages"
  end
end

defmodule PhxMolbindWeb.MessagesLive.ChatRepliesReactionsCardsTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PhxMolbind.AccountsFixtures

  alias PhxMolbind.{Collections, Messages}
  alias PhxMolbind.Molecules.Molecules

  setup :register_and_log_in_user

  test "replying quotes the parent, shows a cancelable bar, and clears after sending", %{
    conn: conn,
    user: user
  } do
    other = user_fixture()

    {:ok, parent} =
      Messages.create_message(%{"body" => "which property should I optimise?"}, other.id)

    {:ok, view, _} = live(conn, ~p"/message")

    html = render_click(view, "reply", %{"id" => to_string(parent.id)})
    assert html =~ ~s(id="reply-bar")
    assert html =~ "which property should I optimise?"

    html = render_click(view, "cancel_reply", %{})
    refute html =~ ~s(id="reply-bar")

    render_click(view, "reply", %{"id" => to_string(parent.id)})
    view |> form("#chat-form", message: %{body: "QED is a good start"}) |> render_submit()
    html = render(view)

    assert html =~ "QED is a good start"
    assert html =~ "Replying to"
    refute html =~ ~s(id="reply-bar")

    assert [%{reply_to_id: id}] =
             Enum.filter(Messages.list_recent_messages(10), &(&1.user_id == user.id))

    assert id == parent.id
  end

  test "reactions toggle, count, and expose pressed state", %{conn: conn, user: user} do
    {:ok, m} = Messages.create_message(%{"body" => "great result"}, user.id)
    {:ok, view, _html} = live(conn, ~p"/message")

    # Every selector is scoped to this test's own message: the lobby topic is
    # global, so concurrently running tests can broadcast other messages here.
    button = ~s(#messages-#{m.id} button[phx-click="react"][phx-value-emoji="👍"])
    assert view |> element(button) |> render() =~ ~s(aria-pressed="false")

    view |> element(button) |> render_click()
    _ = render(view)
    pressed = view |> element(button) |> render()
    assert pressed =~ ~s(aria-pressed="true")
    assert pressed =~ "thumbs up, 1 reaction"

    view |> element(button) |> render_click()
    _ = render(view)
    assert view |> element(button) |> render() =~ "React with thumbs up"
    assert Messages.get_message(m.id).reactions == []
  end

  test "an unlisted emoji is rejected without crashing", %{conn: conn, user: user} do
    {:ok, m} = Messages.create_message(%{"body" => "hi"}, user.id)
    {:ok, view, _} = live(conn, ~p"/message")
    html = render_click(view, "react", %{"id" => to_string(m.id), "emoji" => "💩"})
    assert html =~ "That reaction could not be saved."
  end

  test "a shared molecule renders as a card with actions", %{conn: conn, user: user} do
    {:ok, _} = Messages.share_molecule(user.id, "CCN", "check this out")
    {:ok, _view, html} = live(conn, ~p"/message")
    assert html =~ "check this out"
    assert html =~ ~r/id="msg-card-\d+"/
    assert html =~ "Open in generator"
    assert html =~ "/model?smiles=CCN"
    assert html =~ "no properties are attached"
  end

  test "sharing a run candidate posts the server-side structure", %{conn: conn, user: user} do
    {:ok, run} =
      Molecules.create_history(
        %{
          algorithm: "CMA-ES",
          num_molecules: 1,
          property_name: "QED",
          minimize: false,
          min_similarity: 0.5,
          particles: 10,
          iterations: 2,
          smiles: "CCO",
          generated_molecules: %{"molecules" => [%{"structure" => "CCN", "score" => 0.4}]}
        },
        user.id
      )

    {:ok, view, _} = live(conn, ~p"/history/#{run.id}")
    html = render_click(view, "share_candidate", %{"index" => "0"})
    assert html =~ "Shared to the chat lobby."
    assert [%{smiles: "CCN"}] = Enum.filter(Messages.list_recent_messages(10), & &1.smiles)

    # An out-of-range index shares nothing.
    html = render_click(view, "share_candidate", %{"index" => "9"})
    assert html =~ "could not be shared"
    assert length(Enum.filter(Messages.list_recent_messages(10), & &1.smiles)) == 1
  end

  test "sharing from a collection only works for that collection's own items", %{
    conn: conn,
    user: user
  } do
    {:ok, c} = Collections.create_collection(user.id, %{name: "Mine"})
    {:ok, item} = Collections.add_item(user.id, c.id, %{smiles: "CCC"})
    other = user_fixture()
    {:ok, oc} = Collections.create_collection(other.id, %{name: "Theirs"})
    {:ok, theirs} = Collections.add_item(other.id, oc.id, %{smiles: "NNN"})

    {:ok, view, _} = live(conn, ~p"/collections/#{c.id}")

    assert render_click(view, "share_item", %{"id" => to_string(item.id)}) =~
             "Shared to the chat lobby."

    assert render_click(view, "share_item", %{"id" => to_string(theirs.id)}) =~
             "could not be shared"

    assert [%{smiles: "CCC"}] = Enum.filter(Messages.list_recent_messages(10), & &1.smiles)
  end
end
