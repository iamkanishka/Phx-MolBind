defmodule PhxMolbindWeb.HistoryCollectionsLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PhxMolbind.Collections
  alias PhxMolbind.Molecules.Molecules

  setup :register_and_log_in_user

  defp run_for(user, smiles \\ "CCO") do
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
          smiles: smiles,
          generated_molecules: %{"molecules" => [%{"structure" => "CCN", "score" => 0.4}]}
        },
        user.id
      )

    run
  end

  describe "/history" do
    test "shows an empty state, then runs, and filters by search", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/history")
      assert html =~ "No saved runs yet."

      run_for(user, "CCO")
      run_for(user, "CCCC")

      {:ok, view, html} = live(conn, ~p"/history")
      assert html =~ "CCCC" and html =~ "CCO"

      view |> form("form[role=search]", q: "CCCC") |> render_change()
      assert_patch(view)
      html = render(view)
      assert html =~ ">CCCC<"
      refute html =~ ">CCO<"
    end

    test "delete asks for confirmation first", %{conn: conn, user: user} do
      run = run_for(user)
      {:ok, view, _} = live(conn, ~p"/history")

      html = render_click(view, "ask_delete", %{"id" => to_string(run.id)})
      assert html =~ "Delete this run permanently?"
      assert Molecules.get_history_entry(user.id, run.id)

      render_click(view, "delete", %{"id" => to_string(run.id)})
      assert Molecules.get_history_entry(user.id, run.id) == nil
    end

    test "cannot delete another user's run", %{conn: conn} do
      other = PhxMolbind.AccountsFixtures.user_fixture()
      run = run_for(other)
      {:ok, view, _} = live(conn, ~p"/history")

      html = render_click(view, "delete", %{"id" => to_string(run.id)})
      assert html =~ "That run could not be found."
      assert Molecules.get_history_entry(other.id, run.id)
    end
  end

  describe "/history/:id" do
    test "shows parameters and candidates without re-running", %{conn: conn, user: user} do
      run = run_for(user)
      {:ok, _view, html} = live(conn, ~p"/history/#{run.id}")
      assert html =~ "CCN" and html =~ "0.4000" and html =~ "Re-run with these settings"
      assert html =~ "/model?"
    end

    test "another user's run redirects with an error", %{conn: conn} do
      other = PhxMolbind.AccountsFixtures.user_fixture()
      run = run_for(other)
      assert {:error, {:live_redirect, %{to: "/history"}}} = live(conn, ~p"/history/#{run.id}")
    end

    test "saves a candidate to an owned collection using server-side data", %{
      conn: conn,
      user: user
    } do
      run = run_for(user)
      {:ok, c} = Collections.create_collection(user.id, %{name: "Picks"})
      {:ok, view, _} = live(conn, ~p"/history/#{run.id}")

      view |> form("#run-candidate-0 form", %{collection_id: to_string(c.id)}) |> render_submit()

      assert [%{smiles: "CCN", score: 0.4, source_run_id: id}] =
               Collections.list_items(user.id, c.id)

      assert id == run.id
    end

    test "cannot save into another user's collection", %{conn: conn, user: user} do
      other = PhxMolbind.AccountsFixtures.user_fixture()
      {:ok, theirs} = Collections.create_collection(other.id, %{name: "Theirs"})
      run = run_for(user)
      {:ok, view, _} = live(conn, ~p"/history/#{run.id}")

      html =
        render_click(view, "save_candidate", %{
          "index" => "0",
          "collection_id" => to_string(theirs.id)
        })

      assert html =~ "That collection could not be found."
      assert Collections.list_items(other.id, theirs.id) == []
    end
  end

  describe "/collections" do
    test "create, duplicate error, delete with confirmation", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/collections")
      assert html =~ "No collections yet."

      html = view |> form("#collection-form", collection: %{name: "Picks"}) |> render_submit()
      assert html =~ "Picks"

      html = view |> form("#collection-form", collection: %{name: "Picks"}) |> render_submit()
      assert html =~ "already have a collection"

      [c] = Collections.list_collections(user.id)
      assert render_click(view, "ask_delete", %{"id" => to_string(c.id)}) =~ "Delete “Picks”"
      render_click(view, "delete", %{"id" => to_string(c.id)})
      assert Collections.list_collections(user.id) == []
    end

    test "another user's collection is not reachable", %{conn: conn} do
      other = PhxMolbind.AccountsFixtures.user_fixture()
      {:ok, theirs} = Collections.create_collection(other.id, %{name: "Theirs"})

      assert {:error, {:live_redirect, %{to: "/collections"}}} =
               live(conn, ~p"/collections/#{theirs.id}")
    end
  end

  describe "CSV exports" do
    test "run export downloads for the owner and 404s for others", %{conn: conn, user: user} do
      run = run_for(user)
      resp = get(conn, ~p"/history/#{run.id}/export.csv")
      assert response(resp, 200) =~ "candidate,smiles,score,score_property,parent_smiles"
      assert get_resp_header(resp, "content-disposition") |> hd() =~ "molbind-run-#{run.id}.csv"

      other_run = run_for(PhxMolbind.AccountsFixtures.user_fixture())
      assert conn |> get(~p"/history/#{other_run.id}/export.csv") |> response(404)
    end

    test "collection export is owner-only", %{conn: conn, user: user} do
      {:ok, mine} = Collections.create_collection(user.id, %{name: "Mine"})

      {:ok, _} =
        Collections.add_item(user.id, mine.id, %{smiles: "CCN", score: 0.4, property_name: "QED"})

      assert conn |> get(~p"/collections/#{mine.id}/export.csv") |> response(200) =~ "CCN,0.4,QED"

      other = PhxMolbind.AccountsFixtures.user_fixture()
      {:ok, theirs} = Collections.create_collection(other.id, %{name: "Theirs"})
      assert conn |> get(~p"/collections/#{theirs.id}/export.csv") |> response(404)
    end

    test "exports require sign-in" do
      conn = Phoenix.ConnTest.build_conn() |> get("/history/1/export.csv")
      assert redirected_to(conn)
    end
  end
end
