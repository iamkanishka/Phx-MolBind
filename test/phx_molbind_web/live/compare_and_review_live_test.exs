defmodule PhxMolbindWeb.CompareAndReviewLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PhxMolbind.Collections
  alias PhxMolbind.Molecules.Molecules

  setup :register_and_log_in_user

  defp run_for(user, overrides \\ %{}, molecules \\ [%{"structure" => "CCN", "score" => 0.4}]) do
    attrs =
      Map.merge(
        %{
          algorithm: "CMA-ES",
          num_molecules: 2,
          property_name: "QED",
          minimize: false,
          min_similarity: 0.5,
          particles: 10,
          iterations: 2,
          smiles: "CCO",
          generated_molecules: %{"molecules" => molecules}
        },
        overrides
      )

    {:ok, run} = Molecules.create_history(attrs, user.id)
    run
  end

  describe "history selection" do
    test "selecting two runs offers a comparison link; a third replaces the oldest", %{
      conn: conn,
      user: user
    } do
      [r1, r2, r3] = for i <- 1..3, do: run_for(user, %{smiles: "C" <> String.duplicate("C", i)})
      {:ok, view, _} = live(conn, ~p"/history")

      render_click(view, "toggle_compare", %{"id" => to_string(r1.id)})
      html = render_click(view, "toggle_compare", %{"id" => to_string(r2.id)})
      assert html =~ "2 of 2 runs selected."
      assert html =~ "/history/compare?"

      html = render_click(view, "toggle_compare", %{"id" => to_string(r3.id)})
      assert html =~ "a=#{r2.id}" and html =~ "b=#{r3.id}"
      refute html =~ "a=#{r1.id}"
    end

    test "ids that are not on screen cannot be selected", %{conn: conn} do
      other = PhxMolbind.AccountsFixtures.user_fixture()
      theirs = run_for(other)
      {:ok, view, _} = live(conn, ~p"/history")
      html = render_click(view, "toggle_compare", %{"id" => to_string(theirs.id)})
      refute html =~ "runs selected"
    end
  end

  describe "/history/compare" do
    test "shows changed parameters and per-run stats", %{conn: conn, user: user} do
      a =
        run_for(user, %{}, [
          %{"structure" => "CCN", "score" => 0.2},
          %{"structure" => "CCC", "score" => 0.8}
        ])

      b = run_for(user, %{particles: 50}, [%{"structure" => "CCC", "score" => 0.9}])

      {:ok, _view, html} = live(conn, ~p"/history/compare?#{%{a: a.id, b: b.id}}")
      assert html =~ "Changed"
      assert html =~ "0.8000" and html =~ "0.9000"
      assert html =~ "Candidates found by both runs (1)"
      refute html =~ "not directly comparable"
    end

    test "warns when scores are not comparable", %{conn: conn, user: user} do
      a = run_for(user)
      b = run_for(user, %{property_name: "plogP"})
      {:ok, _view, html} = live(conn, ~p"/history/compare?#{%{a: a.id, b: b.id}}")
      assert html =~ "not directly comparable"
    end

    test "rejects same run, missing run and other users' runs", %{conn: conn, user: user} do
      mine = run_for(user)
      theirs = run_for(PhxMolbind.AccountsFixtures.user_fixture())

      for params <- [
            %{a: mine.id, b: mine.id},
            %{a: mine.id, b: 0},
            %{a: mine.id, b: theirs.id},
            %{a: "x", b: "y"}
          ] do
        assert {:error, {:live_redirect, %{to: "/history"}}} =
                 live(conn, ~p"/history/compare?#{params}")
      end
    end
  end

  describe "review status" do
    setup %{user: user} do
      {:ok, c} = Collections.create_collection(user.id, %{name: "Triage"})

      {:ok, i1} =
        Collections.add_item(user.id, c.id, %{smiles: "CCN", score: 0.4, property_name: "QED"})

      {:ok, i2} = Collections.add_item(user.id, c.id, %{smiles: "CCC"})
      %{c: c, i1: i1, i2: i2}
    end

    test "changing a status persists it and shows it as text", %{
      conn: conn,
      user: user,
      c: c,
      i1: i1
    } do
      {:ok, view, html} = live(conn, ~p"/collections/#{c.id}")
      assert html =~ "Unreviewed (2)"

      html =
        render_change(view, "set_status", %{
          "item_id" => to_string(i1.id),
          "status" => "shortlisted"
        })

      assert html =~ "Shortlisted (1)"

      assert [%{review_status: :shortlisted}] =
               Collections.list_items(user.id, c.id, status: :shortlisted)
    end

    test "invalid statuses are rejected", %{conn: conn, c: c, i1: i1} do
      {:ok, view, _} = live(conn, ~p"/collections/#{c.id}")

      html =
        render_change(view, "set_status", %{"item_id" => to_string(i1.id), "status" => "approved"})

      assert html =~ "That status could not be saved."
    end

    test "the filter shows only matching items and ignores junk values", %{
      conn: conn,
      user: user,
      c: c,
      i1: i1
    } do
      {:ok, _} = Collections.set_review_status(user.id, i1.id, :rejected)

      {:ok, _view, html} = live(conn, ~p"/collections/#{c.id}?status=rejected")
      assert html =~ "CCN"
      refute html =~ ">CCC<"

      {:ok, _view, html} = live(conn, ~p"/collections/#{c.id}?status=bogus")
      assert html =~ "CCN" and html =~ "CCC"

      {:ok, _view, html} = live(conn, ~p"/collections/#{c.id}?status=needs_inspection")
      assert html =~ "No molecules with this status."
    end

    test "another user cannot change a status", %{user: user, c: c, i1: i1} do
      other = PhxMolbind.AccountsFixtures.user_fixture()
      assert {:error, :not_found} = Collections.set_review_status(other.id, i1.id, "rejected")
      assert [%{review_status: :unreviewed} | _] = Collections.list_items(user.id, c.id)
    end
  end
end
