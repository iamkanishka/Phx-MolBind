defmodule PhxMolbind.Molecules.Lineage do
  @moduledoc """
  Lineage around one run, built only from relationships MolBind recorded:

    * **ancestors** – the chain of `parent_run_id` links above the run
    * **descendants** – runs whose recorded parent is this run (recursively)
    * **saved** – collection items whose recorded source is a run in the tree

  Plus one deliberately separate, *unverified* list: other runs that merely
  started from the same SMILES string. Those are shown for convenience but are
  never presented as ancestry, because nothing records that they are related.

  Everything is scoped to the user, and walks are bounded (depth and node
  caps) so a large history cannot make a page slow.
  """
  import Ecto.Query, only: [from: 2]

  alias PhxMolbind.{Collections, Repo}
  alias PhxMolbind.Molecules.Molecule

  @max_ancestors 20
  @max_depth 5
  @max_nodes 50
  @same_start_limit 10

  def build(user_id, %Molecule{} = run) do
    ancestors = ancestors(user_id, run)
    {tree, truncated?} = descendants(user_id, run)

    ids = Enum.map(ancestors, & &1.id) ++ [run.id] ++ tree_ids(tree)

    saved =
      user_id
      |> Collections.items_for_runs(ids)
      |> Enum.group_by(fn {item, _collection} -> item.source_run_id end)

    %{
      ancestors: ancestors,
      run: run,
      descendants: tree,
      truncated?: truncated?,
      saved: saved,
      same_start: same_start(user_id, run, ids),
      has_recorded_lineage?: ancestors != [] or tree != [] or saved != %{}
    }
  end

  @doc "Chain of recorded parents, root first (excludes `run` itself)."
  def ancestors(user_id, run), do: walk_up(user_id, run, [], 0)

  defp walk_up(_user_id, _run, acc, depth) when depth >= @max_ancestors, do: acc
  defp walk_up(_user_id, %Molecule{parent_run_id: nil}, acc, _depth), do: acc

  defp walk_up(user_id, %Molecule{parent_run_id: parent_id}, acc, depth) do
    case Repo.get_by(Molecule, id: parent_id, user_id: user_id) do
      nil ->
        acc

      # Defensive cycle guard: a run already on the path ends the walk.
      %Molecule{id: id} = parent ->
        if Enum.any?(acc, &(&1.id == id)),
          do: acc,
          else: walk_up(user_id, parent, [parent | acc], depth + 1)
    end
  end

  @doc """
  Tree of runs derived from `run`: `[%{run: r, children: [...]}]`, plus a
  flag saying whether the depth/node caps cut it short.

  Each run appears at most once, so a cycle in the data (not creatable
  through the API, but possible via direct edits) cannot loop forever.
  """
  def descendants(user_id, %Molecule{id: root_id}) do
    {nodes, truncated?} = collect(user_id, [root_id], 1, [], MapSet.new([root_id]))
    {build_tree(nodes, root_id, MapSet.new([root_id])), truncated?}
  end

  defp collect(_user_id, [], _depth, acc, _seen), do: {acc, false}

  # Past the depth cap: report truncation only if there really is more below.
  defp collect(user_id, parent_ids, depth, acc, seen) when depth > @max_depth do
    seen_list = MapSet.to_list(seen)

    more? =
      Repo.exists?(
        from m in Molecule,
          where:
            m.user_id == ^user_id and m.parent_run_id in ^parent_ids and m.id not in ^seen_list
      )

    {acc, more?}
  end

  defp collect(user_id, parent_ids, depth, acc, seen) do
    remaining = @max_nodes - length(acc)
    seen_list = MapSet.to_list(seen)

    children =
      Repo.all(
        from m in Molecule,
          where:
            m.user_id == ^user_id and m.parent_run_id in ^parent_ids and m.id not in ^seen_list,
          order_by: [asc: m.id],
          limit: ^(remaining + 1)
      )

    {kept, cut?} =
      if length(children) > remaining,
        do: {Enum.take(children, remaining), true},
        else: {children, false}

    seen = Enum.reduce(kept, seen, &MapSet.put(&2, &1.id))

    {deeper, deeper_cut?} =
      collect(user_id, Enum.map(kept, & &1.id), depth + 1, acc ++ kept, seen)

    {deeper, cut? or deeper_cut?}
  end

  defp build_tree(nodes, parent_id, path) do
    for run <- nodes, run.parent_run_id == parent_id, not MapSet.member?(path, run.id) do
      %{run: run, children: build_tree(nodes, run.id, MapSet.put(path, run.id))}
    end
  end

  defp tree_ids(tree),
    do: Enum.flat_map(tree, fn %{run: r, children: c} -> [r.id | tree_ids(c)] end)

  # Same starting SMILES, but not part of the recorded lineage: NOT verified
  # as related.
  defp same_start(user_id, run, known_ids) do
    Repo.all(
      from m in Molecule,
        where: m.user_id == ^user_id and m.smiles == ^run.smiles and m.id not in ^known_ids,
        order_by: [desc: m.id],
        limit: @same_start_limit
    )
  end
end
