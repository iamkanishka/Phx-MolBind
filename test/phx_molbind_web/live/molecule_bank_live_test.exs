defmodule PhxMolbindWeb.MoleculeBankLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "lists every catalog molecule with its computed formula", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/molecule-bank")
    assert html =~ "Aspirin" and html =~ "C9H8O4"
    assert html =~ "10 molecules"
    assert html =~ "No stereocentres"
    assert html =~ "None of these values are experimental measurements"
  end

  test "searching patches the URL and narrows the list", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/molecule-bank")
    view |> form("form[role=search]", %{search_query: "caffeine"}) |> render_change()
    assert_patch(view, ~p"/molecule-bank?#{%{q: "caffeine"}}")

    html = render(view)
    assert html =~ "1 molecule"
    assert html =~ "Caffeine"
    refute html =~ ">Aspirin<"
  end

  test "category filter, sort and table view come from the URL", %{conn: conn} do
    {:ok, _view, html} =
      live(
        conn,
        ~p"/molecule-bank?#{%{category: "Stimulant", sort: "weight_desc", view: "table"}}"
      )

    assert html =~ "2 molecules"
    assert html =~ "<table"
    assert html =~ ~s(scope="col")
    assert String.split(html, "Caffeine") |> hd() |> String.contains?("Nicotine") == false
  end

  test "junk parameters are ignored instead of crashing", %{conn: conn} do
    {:ok, _view, html} =
      live(
        conn,
        ~p"/molecule-bank?#{%{category: "nope", sort: "x", view: "y", q: String.duplicate("a", 500)}}"
      )

    assert html =~ "No molecules match these filters."
  end

  test "no results offers a way to clear filters", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/molecule-bank?q=zzzz")
    assert html =~ "No molecules match these filters."
    assert html =~ "Clear filters"
  end

  test "the 3D viewer only opens for catalog structures", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/molecule-bank")

    html = render_click(view, "enlarge_molecule", %{"smiles" => "CCO"})
    assert html =~ ~s(id="molecule-modal")

    {:ok, view, _} = live(conn, ~p"/molecule-bank")
    html = render_click(view, "enlarge_molecule", %{"smiles" => "NOT-IN-CATALOG"})
    refute html =~ ~s(id="molecule-modal")
  end

  test "each molecule can be handed to the generator", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/molecule-bank")
    assert html =~ "/model?smiles=CCO"
  end
end
