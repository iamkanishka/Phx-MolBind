defmodule PhxMolbindWeb.RouterAuthTest do
  use PhxMolbindWeb.ConnCase, async: true

  import PhxMolbind.AccountsFixtures

  @protected_paths [
    "/",
    "/molecule-bank",
    "/model",
    "/research",
    "/sketcher",
    "/profile",
    "/settings",
    "/message"
  ]

  describe "unauthenticated access" do
    for path <- @protected_paths do
      test "GET #{path} redirects to sign-in when not logged in", %{conn: conn} do
        conn = get(conn, unquote(path))
        assert redirected_to(conn) == ~p"/auth/sign-in"
      end
    end
  end

  describe "authenticated access" do
    setup :register_and_log_in_user

    for path <- @protected_paths do
      test "GET #{path} is reachable once logged in", %{conn: conn} do
        conn = get(conn, unquote(path))
        # Signed-in users get the page itself (HTTP 200), not a redirect.
        assert html_response(conn, 200)
      end
    end

    test "GET /auth/sign-in redirects an already-authenticated user home", %{conn: conn} do
      conn = get(conn, ~p"/auth/sign-in")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "EthSessionController" do
    test "an unknown/expired ticket redirects to sign-in with an error", %{conn: conn} do
      conn = get(conn, ~p"/auth/session/not-a-real-ticket")
      assert redirected_to(conn) == ~p"/auth/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "a valid ticket logs the user in", %{conn: conn} do
      user = user_fixture()
      ticket = PhxMolbind.EthAuth.Auth.create_login_ticket(user.id)

      conn = get(conn, ~p"/auth/session/#{ticket}")
      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
    end

    test "DELETE /auth/sign-out logs the user out", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/auth/sign-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
    end
  end
end
