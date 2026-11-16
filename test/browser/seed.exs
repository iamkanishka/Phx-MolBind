alias PhxMolbind.{Accounts, Collections, Messages}
alias PhxMolbind.Molecules.Molecules
{:ok, user} = Accounts.find_or_create_user_by_address("0x" <> String.duplicate("ab", 20))
{:ok, user} = Accounts.update_profile(user, %{"username" => "ada", "bio" => "Chemist"})
{:ok, other} = Accounts.find_or_create_user_by_address("0x" <> String.duplicate("cd", 20))
mk = fn smi, mols ->
  {:ok, r} = Molecules.create_history(%{algorithm: "CMA-ES", num_molecules: 3, property_name: "QED", minimize: false, min_similarity: 0.5, particles: 10, iterations: 2, smiles: smi, generated_molecules: %{"molecules" => mols}}, user.id)
  r
end
r1 = mk.("CC(=O)OC1=CC=CC=C1C(O)=O", [%{"structure" => "CC(=O)OC1=CC=CC=C1C(=O)O", "score" => 0.55}, %{"structure" => "CC(=O)Oc1ccccc1C(N)=O", "score" => 0.61}, %{"structure" => "CCOC(=O)c1ccccc1OC(C)=O", "score" => 0.48}])
_r2 = mk.("CN1C=NC2=C1C(=O)N(C(=O)N2C)C", [%{"structure" => "CN1C=NC2=C1C(=O)NC(=O)N2C", "score" => 0.5}])
{:ok, c} = Collections.create_collection(user.id, %{name: "Shortlist"})
{:ok, _} = Collections.add_item(user.id, c.id, %{smiles: "CC(=O)Oc1ccccc1C(N)=O", score: 0.61, property_name: "QED", source_run_id: r1.id})
for i <- 1..60, do: Messages.create_message(%{"body" => "message number #{i}"}, (if rem(i, 2) == 0, do: user.id, else: other.id))
IO.puts("SEEDED user=#{user.id} run=#{r1.id} collection=#{c.id}")

# --- lineage: a child run started from candidate 2 of the first run, and a
# grandchild started from the child's first candidate. Created through the
# normal context so the parent links are verified exactly as in the app.
alias PhxMolbind.Molecules.Molecule
import Ecto.Query
first = PhxMolbind.Repo.one!(from m in Molecule, where: m.user_id == ^user.id, order_by: [asc: m.id], limit: 1)
child_smiles = "CC(=O)Oc1ccccc1C(N)=O"

{:ok, child} =
  Molecules.create_history(
    %{algorithm: "CMA-ES", num_molecules: 2, property_name: "QED", minimize: false, min_similarity: 0.5,
      particles: 10, iterations: 2, smiles: child_smiles, parent_run_id: first.id,
      generated_molecules: %{"molecules" => [%{"structure" => "CC(=O)Oc1ccccc1C(N)=S", "score" => 0.58}, %{"structure" => "CC(=O)Oc1ccccc1C(=O)N", "score" => 0.52}]}},
    user.id
  )

{:ok, _grandchild} =
  Molecules.create_history(
    %{algorithm: "CMA-ES", num_molecules: 1, property_name: "QED", minimize: false, min_similarity: 0.5,
      particles: 10, iterations: 2, smiles: "CC(=O)Oc1ccccc1C(N)=S", parent_run_id: child.id,
      generated_molecules: %{"molecules" => [%{"structure" => "CC(=O)Oc1ccccc1C(N)=O", "score" => 0.5}]}},
    user.id
  )

IO.puts("LINEAGE child=#{child.id} parent=#{child.parent_run_id} idx=#{child.parent_candidate_index}")
