defmodule PhxMolbindWeb.ProfileAndSettingsLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PhxMolbind.AccountsFixtures

  setup :register_and_log_in_user

  describe "Profile" do
    test "shows the connected wallet address and falls back to a shortened address when no username is set",
         %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/profile")
      assert html =~ user.address
    end

    test "shows the username and bio once set", %{conn: conn, user: user} do
      {:ok, _user} =
        PhxMolbind.Accounts.update_profile(user, %{
          "username" => "researcher1",
          "bio" => "Studying kinase inhibitors."
        })

      {:ok, _view, html} = live(conn, ~p"/profile")
      assert html =~ "researcher1"
      assert html =~ "Studying kinase inhibitors."
    end
  end

  describe "Settings" do
    test "renders the current profile values in the form", %{conn: conn, user: user} do
      {:ok, _user} = PhxMolbind.Accounts.update_profile(user, %{"username" => "researcher1"})

      {:ok, _view, html} = live(conn, ~p"/settings")
      assert html =~ "researcher1"
      assert html =~ user.address
    end

    test "saving the form updates the user and shows a confirmation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html =
        view
        |> form("#profile-form", profile: %{username: "newname", bio: "hi", photo_url: ""})
        |> render_submit()

      assert html =~ "Profile updated successfully!"
      assert html =~ "newname"
    end
  end
end
