defmodule PhxMolbind.LineageTest do
  use PhxMolbind.DataCase, async: true

  alias PhxMolbind.{Collections, Repo}
  alias PhxMolbind.Molecules.{Lineage, Molecule, Molecules}
  import PhxMolbind.AccountsFixtures

  setup do
    %{user: user_fixture(), other: user_fixture()}
  end

  # A run starting at `smiles` that produced `structures` as candidates.
  defp run(user, smiles, structures \\ [], extra \\ %{}) do
    attrs =
      Map.merge(
        %{
          algorithm: "CMA-ES",
          num_molecules: 3,
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

  describe "verified_parent/3" do
    test "accepts an owned run and an exact candidate match", %{user: user} do
      parent = run(user, "CCO", ["CCN", "CCC"])
      assert {:ok, %{run_id: id, index: 1}} = Molecules.verified_parent(user.id, parent.id, "CCC")
      assert id == parent.id
      assert {:ok, %{index: 0}} = Molecules.verified_parent(user.id, to_string(parent.id), "CCN")
    end

    test "rejects anything that is not exactly a candidate of an owned run", %{
      user: user,
      other: other
    } do
      parent = run(user, "CCO", ["CCN"])
      theirs = run(other, "CCO", ["CCN"])

      assert Molecules.verified_parent(user.id, parent.id, "CCC") == :none
      assert Molecules.verified_parent(user.id, parent.id, "ccn") == :none
      assert Molecules.verified_parent(user.id, parent.id, "CCN ") == :none
      assert Molecules.verified_parent(user.id, theirs.id, "CCN") == :none
      assert Molecules.verified_parent(user.id, 0, "CCN") == :none
      assert Molecules.verified_parent(user.id, "abc", "CCN") == :none
      assert Molecules.verified_parent(user.id, nil, "CCN") == :none
      assert Molecules.verified_parent(user.id, parent.id, nil) == :none
    end
  end

  describe "create_history/2 lineage" do
    test "records a verified parent and its candidate index", %{user: user} do
      parent = run(user, "CCO", ["CCN", "CCC"])
      child = run(user, "CCC", ["CCCC"], %{parent_run_id: parent.id})
      assert child.parent_run_id == parent.id
      assert child.parent_candidate_index == 1
    end

    test "silently drops forged or mismatched parents instead of recording them", %{
      user: user,
      other: other
    } do
      mine = run(user, "CCO", ["CCN"])
      theirs = run(other, "CCO", ["CCN"])

      assert run(user, "CCN", [], %{parent_run_id: theirs.id}).parent_run_id == nil
      assert run(user, "NOT-A-CANDIDATE", [], %{parent_run_id: mine.id}).parent_run_id == nil
      assert run(user, "CCN", [], %{parent_run_id: 0}).parent_run_id == nil
      assert run(user, "CCN", [], %{parent_candidate_index: 7}).parent_candidate_index == nil
    end

    test "deleting the parent keeps the child, with the link cleared", %{user: user} do
      parent = run(user, "CCO", ["CCN"])
      child = run(user, "CCN", [], %{parent_run_id: parent.id})
      {:ok, _} = Molecules.delete_history_entry(user.id, parent.id)

      assert %{parent_run_id: nil} = Repo.get!(Molecule, child.id)
    end
  end

  describe "Lineage.build/2" do
    test "an unrelated run has no recorded lineage", %{user: user} do
      lonely = run(user, "CCO", ["CCN"])
      result = Lineage.build(user.id, lonely)
      assert result.ancestors == [] and result.descendants == []
      refute result.has_recorded_lineage?
    end

    test "walks ancestors root-first and descendants as a tree", %{user: user} do
      root = run(user, "CCO", ["CCN"])
      mid = run(user, "CCN", ["CCC", "CCCC"], %{parent_run_id: root.id})
      leaf = run(user, "CCC", ["CCCCC"], %{parent_run_id: mid.id})
      sibling = run(user, "CCCC", [], %{parent_run_id: mid.id})

      up = Lineage.build(user.id, leaf)
      assert Enum.map(up.ancestors, & &1.id) == [root.id, mid.id]
      assert up.has_recorded_lineage?

      down = Lineage.build(user.id, root)
      assert [%{run: %{id: mid_id}, children: kids}] = down.descendants
      assert mid_id == mid.id
      assert kids |> Enum.map(& &1.run.id) |> Enum.sort() == Enum.sort([leaf.id, sibling.id])
      refute down.truncated?
    end

    test "includes molecules saved from any run in the tree", %{user: user} do
      root = run(user, "CCO", ["CCN"])
      child = run(user, "CCN", ["CCC"], %{parent_run_id: root.id})
      {:ok, c} = Collections.create_collection(user.id, %{name: "Picks"})
      {:ok, _} = Collections.add_item(user.id, c.id, %{smiles: "CCC", source_run_id: child.id})
      {:ok, _} = Collections.add_item(user.id, c.id, %{smiles: "CCN", source_run_id: root.id})

      saved = Lineage.build(user.id, root).saved
      assert [{%{smiles: "CCN"}, %{name: "Picks"}}] = saved[root.id]
      assert [{%{smiles: "CCC"}, _}] = saved[child.id]
    end

    test "same-SMILES runs are listed separately and never as recorded lineage", %{user: user} do
      a = run(user, "CCO", ["CCN"])
      b = run(user, "CCO", ["CCC"])
      linked = run(user, "CCN", [], %{parent_run_id: a.id})

      result = Lineage.build(user.id, a)
      assert Enum.map(result.same_start, & &1.id) == [b.id]
      refute Enum.any?(result.same_start, &(&1.id == linked.id))
      refute result.has_recorded_lineage? == false
      assert result.ancestors == []
    end

    test "never exposes another user's runs, even via a parent id forced into the database",
         %{user: user, other: other} do
      theirs = run(other, "CCO", ["CCN"])
      mine = run(user, "CCN", [])
      # Bypass the context's verification on purpose.
      Repo.update_all(Ecto.Query.from(m in Molecule, where: m.id == ^mine.id),
        set: [parent_run_id: theirs.id]
      )

      same = run(other, "CCN", [])

      result = Lineage.build(user.id, Repo.get!(Molecule, mine.id))
      assert result.ancestors == []
      assert result.same_start == []
      refute same.id in Enum.map(result.same_start, & &1.id)
    end

    test "a cycle in the data cannot hang the walk", %{user: user} do
      a = run(user, "CCO", ["CCN"])
      b = run(user, "CCN", [], %{parent_run_id: a.id})

      Repo.update_all(Ecto.Query.from(m in Molecule, where: m.id == ^a.id),
        set: [parent_run_id: b.id]
      )

      result = Lineage.build(user.id, Repo.get!(Molecule, b.id))
      assert length(result.ancestors) <= 2

      # Descendants must terminate too, listing each run at most once.
      flat = fn f, nodes -> Enum.flat_map(nodes, &[&1.run.id | f.(f, &1.children)]) end
      ids = flat.(flat, result.descendants)
      assert ids == Enum.uniq(ids)
    end

    test "the tree is bounded by node count and reports truncation", %{user: user} do
      root = run(user, "CCO", ["CCN"])
      for _ <- 1..55, do: run(user, "CCN", [], %{parent_run_id: root.id})

      result = Lineage.build(user.id, root)
      assert length(result.descendants) == 50
      assert result.truncated?
    end

    test "the tree is bounded by depth", %{user: user} do
      first = run(user, "C0", ["C1"])

      Enum.reduce(1..7, first, fn i, parent ->
        run(user, "C#{i}", ["C#{i + 1}"], %{parent_run_id: parent.id})
      end)

      result = Lineage.build(user.id, first)

      depth = fn f, nodes ->
        if nodes == [], do: 0, else: 1 + Enum.max(Enum.map(nodes, &f.(f, &1.children)))
      end

      assert depth.(depth, result.descendants) == 5
      assert result.truncated?
    end
  end
end
