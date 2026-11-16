defmodule PhxMolbindWeb.ResearchLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "renders the search combobox and a first-use hint", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research")
    assert html =~ ~s(role="combobox")
    assert html =~ "Search PubChem by compound name"
  end

  test "submitting a blank name shows an error instead of crashing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/research")
    html = view |> form("#compound-search form", compound_name: "  ") |> render_submit()
    assert html =~ "Enter a compound name to search."
  end

  test "short input clears suggestions without a network request", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/research")
    html = view |> form("#compound-search form", compound_name: "a") |> render_change()
    refute html =~ ~s(id="compound-suggestions")
  end
end

defmodule PhxMolbindWeb.SettingsThemeTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "choosing a theme pushes it to the client", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")
    view |> element("#theme-form") |> render_change(%{theme: "dark"})
    assert_push_event(view, "theme:set", %{theme: "dark"})
  end
end
