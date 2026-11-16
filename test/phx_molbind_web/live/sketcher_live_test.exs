defmodule PhxMolbindWeb.SketcherLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "export buttons ask the browser hook for the structure (map payload)", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/sketcher")

    view |> element("button[phx-value-format=smiles]") |> render_click()
    assert_push_event(view, "get_molecule", %{format: "smiles"})

    view |> element("button[phx-value-format=mol]") |> render_click()
    assert_push_event(view, "get_molecule", %{format: "mol"})
  end

  test "unknown formats are rejected without crashing", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/sketcher")

    assert render_click(view, "get_molecule", %{"format" => "pdb"}) =~
             "Unsupported export format."
  end

  test "data and errors from the hook are displayed", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/sketcher")

    html = render_click(view, "molecule_data", %{"format" => "smiles", "data" => "CCO"})
    assert html =~ "CCO" and html =~ "Use in generator"

    html =
      render_click(view, "molecule_error", %{
        "message" => "The canvas is empty. Draw a molecule first."
      })

    assert html =~ "The canvas is empty."
    refute html =~ "Use in generator"
  end
end
