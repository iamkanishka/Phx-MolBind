defmodule PhxMolbind.CollectionsTest do
  use PhxMolbind.DataCase, async: true

  alias PhxMolbind.Collections
  alias PhxMolbind.Molecules.Molecules
  import PhxMolbind.AccountsFixtures

  setup do
    %{user: user_fixture(), other: user_fixture()}
  end

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

  test "create enforces name rules and per-user uniqueness", %{user: user, other: other} do
    assert {:ok, _} = Collections.create_collection(user.id, %{name: "  Shortlist "})
    assert [%{name: "Shortlist"}] = Collections.list_collections(user.id)

    assert {:error, cs} = Collections.create_collection(user.id, %{name: "Shortlist"})
    assert %{name: [_]} = errors_on(cs)

    assert {:error, cs} = Collections.create_collection(user.id, %{name: ""})
    assert %{name: ["can't be blank"]} = errors_on(cs)

    assert {:error, cs} =
             Collections.create_collection(user.id, %{name: String.duplicate("a", 81)})

    assert %{name: [_]} = errors_on(cs)

    # Same name for a different user is fine.
    assert {:ok, _} = Collections.create_collection(other.id, %{name: "Shortlist"})
  end

  test "other users cannot read, rename, delete or add to a collection", %{
    user: user,
    other: other
  } do
    {:ok, c} = Collections.create_collection(user.id, %{name: "Private"})

    assert Collections.get_collection(other.id, c.id) == nil
    assert {:error, :not_found} = Collections.rename_collection(other.id, c.id, "Hijacked")
    assert {:error, :not_found} = Collections.delete_collection(other.id, c.id)
    assert {:error, :not_found} = Collections.add_item(other.id, c.id, %{smiles: "CCO"})
    assert Collections.list_items(other.id, c.id) == []
    assert Collections.get_collection(user.id, c.id).name == "Private"
  end

  test "add_item stores provenance only for the user's own runs; duplicates are rejected",
       %{user: user, other: other} do
    {:ok, c} = Collections.create_collection(user.id, %{name: "Picks"})
    mine = run_for(user)
    theirs = run_for(other)

    assert {:ok, item} =
             Collections.add_item(user.id, c.id, %{
               smiles: "CCN",
               score: 0.4,
               property_name: "QED",
               source_run_id: mine.id
             })

    assert item.source_run_id == mine.id

    assert {:ok, item2} =
             Collections.add_item(user.id, c.id, %{smiles: "CCC", source_run_id: theirs.id})

    assert item2.source_run_id == nil

    assert {:error, cs} = Collections.add_item(user.id, c.id, %{smiles: "CCN"})
    assert %{smiles: ["is already in this collection"]} = errors_on(cs)

    assert {:error, cs} =
             Collections.add_item(user.id, c.id, %{smiles: String.duplicate("C", 501)})

    assert %{smiles: [_]} = errors_on(cs)
  end

  test "remove_item is owner-scoped; deleting a run keeps saved items", %{
    user: user,
    other: other
  } do
    {:ok, c} = Collections.create_collection(user.id, %{name: "Picks"})
    run = run_for(user)
    {:ok, item} = Collections.add_item(user.id, c.id, %{smiles: "CCN", source_run_id: run.id})

    assert {:error, :not_found} = Collections.remove_item(other.id, item.id)

    assert {:ok, _} = Molecules.delete_history_entry(user.id, run.id)
    assert [%{smiles: "CCN", source_run_id: nil}] = Collections.list_items(user.id, c.id)

    assert {:ok, _} = Collections.remove_item(user.id, item.id)
    assert Collections.list_items(user.id, c.id) == []
  end

  describe "review status" do
    setup %{user: user} do
      {:ok, c} = Collections.create_collection(user.id, %{name: "Review"})
      {:ok, a} = Collections.add_item(user.id, c.id, %{smiles: "CCN"})
      {:ok, b} = Collections.add_item(user.id, c.id, %{smiles: "CCC"})
      %{c: c, a: a, b: b}
    end

    test "defaults to unreviewed and can be changed to each valid status", %{user: user, a: a} do
      assert a.review_status == :unreviewed

      for status <- Collections.review_statuses() do
        assert {:ok, %{review_status: ^status}} =
                 Collections.set_review_status(user.id, a.id, Atom.to_string(status))
      end
    end

    test "rejects unknown statuses without touching the item", %{user: user, a: a} do
      assert {:error, :invalid_status} = Collections.set_review_status(user.id, a.id, "approved")
      assert {:error, :invalid_status} = Collections.set_review_status(user.id, a.id, nil)
      assert {:error, :invalid_status} = Collections.set_review_status(user.id, a.id, :bogus)

      assert [%{review_status: :unreviewed} | _] =
               Collections.list_items(user.id, a.collection_id)
    end

    test "only the owner can change a status", %{other: other, a: a, user: user} do
      assert {:error, :not_found} = Collections.set_review_status(other.id, a.id, "rejected")
      assert [%{review_status: :unreviewed}, _] = Collections.list_items(user.id, a.collection_id)
    end

    test "filters by status and counts per status", %{user: user, c: c, a: a} do
      {:ok, _} = Collections.set_review_status(user.id, a.id, :shortlisted)

      assert [%{smiles: "CCN"}] = Collections.list_items(user.id, c.id, status: :shortlisted)
      assert [%{smiles: "CCC"}] = Collections.list_items(user.id, c.id, status: :unreviewed)
      assert Collections.list_items(user.id, c.id, status: :rejected) == []
      assert Collections.review_counts(user.id, c.id) == %{shortlisted: 1, unreviewed: 1}
    end
  end

  test "list_collections reports item counts", %{user: user} do
    {:ok, a} = Collections.create_collection(user.id, %{name: "A"})
    {:ok, _b} = Collections.create_collection(user.id, %{name: "B"})
    {:ok, _} = Collections.add_item(user.id, a.id, %{smiles: "CCN"})
    {:ok, _} = Collections.add_item(user.id, a.id, %{smiles: "CCC"})

    assert [%{name: "A", item_count: 2}, %{name: "B", item_count: 0}] =
             Collections.list_collections(user.id)
  end

  test "CSV has stable headers, escapes cells and neutralises formulas" do
    items = [
      %{
        smiles: "CC(=O)O",
        score: -0.5,
        property_name: "plogP",
        review_status: :unreviewed,
        inserted_at: ~N[2026-10-14 01:02:03]
      },
      %{
        smiles: "=cmd|'/C calc'!A0",
        score: nil,
        property_name: nil,
        review_status: :unreviewed,
        review_status: :unreviewed,
        inserted_at: nil
      },
      %{
        smiles: "C,C\"x\"",
        score: 0.91,
        property_name: "QED",
        review_status: :unreviewed,
        inserted_at: ~N[2026-10-14 01:02:03]
      }
    ]

    csv = Collections.items_to_csv(items)
    [header | rows] = String.split(csv, "\r\n", trim: true)

    assert header == "smiles,score,score_property,review_status,saved_at"
    assert Enum.at(rows, 0) == "CC(=O)O,-0.5,plogP,unreviewed,2026-10-14T01:02:03"
    assert Enum.at(rows, 1) == "'=cmd|'/C calc'!A0,,,unreviewed,"
    assert Enum.at(rows, 2) == ~s("C,C""x""",0.91,QED,unreviewed,2026-10-14T01:02:03)
    assert String.ends_with?(csv, "\r\n")
  end

  describe "Molecules.list_history/2" do
    test "paginates, searches literally and is scoped to the user", %{user: user, other: other} do
      for s <- ["CCO", "C_O%", "CCCC"], do: run_for(user, s)
      run_for(other, "CCO")

      all = Molecules.list_history(user.id, per_page: 2)
      assert all.total == 3 and all.pages == 2 and length(all.entries) == 2

      page2 = Molecules.list_history(user.id, per_page: 2, page: 2)
      assert length(page2.entries) == 1

      # Out-of-range pages clamp instead of returning nothing.
      assert Molecules.list_history(user.id, per_page: 2, page: 99).page == 2

      literal = Molecules.list_history(user.id, search: "_O%")
      assert Enum.map(literal.entries, & &1.smiles) == ["C_O%"]

      assert Molecules.list_history(user.id, search: "cco").total == 1
    end

    test "delete_history_entry is owner-scoped", %{user: user, other: other} do
      run = run_for(user)
      assert {:error, :not_found} = Molecules.delete_history_entry(other.id, run.id)
      assert {:ok, _} = Molecules.delete_history_entry(user.id, run.id)
    end
  end
end
