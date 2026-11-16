defmodule PhxMolbindWeb.LineageLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PhxMolbind.AccountsFixtures

  alias PhxMolbind.Collections
  alias PhxMolbind.Molecules.Molecules

  setup :register_and_log_in_user

  defp run(user, smiles, structures, extra \\ %{}) do
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
          smiles: smiles,
          generated_molecules: %{
            "molecules" => for(s <- structures, do: %{"structure" => s, "score" => 0.5})
          }
        },
        extra
      )

    {:ok, run} = Molecules.create_history(attrs, user.id)
    run
  end

  describe "run page lineage section" do
    test "explains the empty state", %{conn: conn, user: user} do
      r = run(user, "CCO", ["CCN"])
      {:ok, _view, html} = live(conn, ~p"/history/#{r.id}")
      assert html =~ "Lineage"
      assert html =~ "No recorded lineage for this run yet."
    end

    test "shows ancestors, descendants and saved molecules as links", %{conn: conn, user: user} do
      root = run(user, "CCO", ["CCN"])
      mid = run(user, "CCN", ["CCC"], %{parent_run_id: root.id})
      leaf = run(user, "CCC", [], %{parent_run_id: mid.id})
      {:ok, c} = Collections.create_collection(user.id, %{name: "Keepers"})
      {:ok, _} = Collections.add_item(user.id, c.id, %{smiles: "CCC", source_run_id: mid.id})

      {:ok, _view, html} = live(conn, ~p"/history/#{mid.id}")
      assert html =~ "Derived from"
      assert html =~ ~s(href="/history/#{root.id}")
      assert html =~ "started from candidate 1 of run #{root.id}"
      assert html =~ "Led to"
      assert html =~ ~s(href="/history/#{leaf.id}")
      assert html =~ "Keepers"
      refute html =~ "No recorded lineage"
    end

    test "same-SMILES runs appear under an explicit 'not verified' heading", %{
      conn: conn,
      user: user
    } do
      a = run(user, "CCO", ["CCN"])
      b = run(user, "CCO", ["CCC"])
      {:ok, _view, html} = live(conn, ~p"/history/#{a.id}")
      assert html =~ "not verified as related"
      assert html =~ ~s(href="/history/#{b.id}")
      assert html =~ "No recorded lineage"
    end

    test "candidate links carry provenance to the generator", %{conn: conn, user: user} do
      r = run(user, "CCO", ["CCN"])
      {:ok, _view, html} = live(conn, ~p"/history/#{r.id}")
      assert html =~ "smiles=CCN"
      assert html =~ "from_run=#{r.id}"
    end
  end

  describe "generator lineage note" do
    test "appears for a verified candidate and is dropped when the SMILES is edited", %{
      conn: conn,
      user: user
    } do
      r = run(user, "CCO", ["CCN"])
      {:ok, view, html} = live(conn, ~p"/model?#{%{smiles: "CCN", from_run: r.id}}")
      assert html =~ ~s(id="lineage-note")
      assert html =~ "candidate 1 of"

      html = view |> form("#molecule-form", form: %{smiles: "CCNC"}) |> render_change()
      refute html =~ ~s(id="lineage-note")

      html = view |> form("#molecule-form", form: %{smiles: "CCN"}) |> render_change()
      assert html =~ ~s(id="lineage-note")
    end

    test "never appears for a SMILES that is not a candidate, or for someone else's run", %{
      conn: conn,
      user: user
    } do
      mine = run(user, "CCO", ["CCN"])
      theirs = run(user_fixture(), "CCO", ["CCN"])

      {:ok, _v, html} = live(conn, ~p"/model?#{%{smiles: "CCC", from_run: mine.id}}")
      refute html =~ ~s(id="lineage-note")

      {:ok, _v, html} = live(conn, ~p"/model?#{%{smiles: "CCN", from_run: theirs.id}}")
      refute html =~ ~s(id="lineage-note")

      {:ok, _v, html} = live(conn, ~p"/model?#{%{smiles: "CCN", from_run: "garbage"}}")
      refute html =~ ~s(id="lineage-note")
    end
  end

  test "saved molecules link to the generator with their recorded source", %{
    conn: conn,
    user: user
  } do
    r = run(user, "CCO", ["CCN"])
    {:ok, c} = Collections.create_collection(user.id, %{name: "P"})
    {:ok, _} = Collections.add_item(user.id, c.id, %{smiles: "CCN", source_run_id: r.id})
    {:ok, _} = Collections.add_item(user.id, c.id, %{smiles: "CCC"})

    {:ok, _view, html} = live(conn, ~p"/collections/#{c.id}")
    assert html =~ "from_run=#{r.id}"
    assert length(Regex.scan(~r/from_run=/, html)) == 1
  end
end
