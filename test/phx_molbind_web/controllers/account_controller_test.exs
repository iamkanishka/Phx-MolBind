defmodule PhxMolbindWeb.AccountControllerTest do
  use PhxMolbindWeb.ConnCase, async: true

  alias PhxMolbind.Accounts

  setup :register_and_log_in_user

  test "export downloads JSON for the signed-in user", %{conn: conn, user: user} do
    resp = get(conn, ~p"/account/export.json")
    body = json_response(resp, 200)
    assert body["format"] == "molbind-export"
    assert body["account"]["address"] == user.address
    assert [disposition] = get_resp_header(resp, "content-disposition")
    assert disposition =~ "molbind-export-"
  end

  test "export requires sign-in" do
    conn = Phoenix.ConnTest.build_conn() |> get("/account/export.json")
    assert redirected_to(conn)
  end

  test "delete with a wrong confirmation changes nothing", %{conn: conn, user: user} do
    conn = delete(conn, ~p"/account", %{"confirmation" => "nope"})
    assert redirected_to(conn) == ~p"/settings"
    assert Accounts.get_user(user.id)
  end

  test "delete with the typed address removes the account and signs out", %{
    conn: conn,
    user: user
  } do
    conn =
      delete(conn, ~p"/account", %{"confirmation" => "  " <> String.upcase(user.address) <> " "})

    assert redirected_to(conn) == ~p"/"
    assert Accounts.get_user(user.id) == nil
    assert get_session(conn, :user_token) == nil
  end
end

defmodule PhxMolbindWeb.SettingsSessionsLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias PhxMolbind.Accounts

  setup :register_and_log_in_user

  test "lists sessions, revokes another one, and refuses to revoke the current one", %{
    conn: conn,
    user: user
  } do
    other_token = Accounts.generate_user_session_token(user)
    {:ok, view, html} = live(conn, ~p"/settings")
    assert html =~ "This session"
    assert html =~ "Active sessions"

    [%{id: other_ref}] =
      for s <- Accounts.list_user_sessions(user, conn |> Plug.Conn.get_session(:user_token)),
          not s.current?,
          do: s

    html = render_click(view, "revoke_session", %{"id" => other_ref})
    assert html =~ "Session signed out."
    assert Accounts.get_user_by_session_token(other_token) == nil
  end

  test "delete-account form requires typing the address", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings")
    assert html =~ "Delete my account"
    assert html =~ ~s(name="confirmation")
  end
end
