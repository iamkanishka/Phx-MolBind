defmodule PhxMolbindWeb.PageControllerTest do
  use PhxMolbindWeb.ConnCase

  # "/" is the signed-in dashboard (the old Phoenix welcome page no longer
  # exists), so anonymous visitors are sent to wallet sign-in.
  test "GET / sends anonymous visitors to sign-in", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/auth/sign-in"
  end
end
