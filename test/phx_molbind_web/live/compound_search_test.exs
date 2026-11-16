defmodule PhxMolbindWeb.ResearchLive.CompoundSearchTest do
  use ExUnit.Case, async: true

  alias PhxMolbindWeb.ResearchLive.CompoundSearch

  test "smiles/1 prefers isomeric SMILES and accepts both PubChem key schemes" do
    assert CompoundSearch.smiles(%{
             "IsomericSMILES" => "C[C@H](N)C(=O)O",
             "CanonicalSMILES" => "CC(N)C(=O)O"
           }) ==
             "C[C@H](N)C(=O)O"

    assert CompoundSearch.smiles(%{"SMILES" => "CCO", "ConnectivitySMILES" => "CCO"}) == "CCO"
    assert CompoundSearch.smiles(%{"CanonicalSMILES" => "CCO"}) == "CCO"
    assert CompoundSearch.smiles(%{"CanonicalSMILES" => ""}) == nil
    assert CompoundSearch.smiles(%{}) == nil
  end

  test "record_url/1 only links when a CID is known" do
    assert CompoundSearch.record_url(%{"CID" => 2244}) ==
             "https://pubchem.ncbi.nlm.nih.gov/compound/2244"

    assert CompoundSearch.record_url(%{}) == nil
  end

  test "lookup/1 rejects blank and oversized names without a network call" do
    assert {:error, _} = CompoundSearch.lookup("   ")

    assert {:error, "Compound name is too long"} =
             CompoundSearch.lookup(String.duplicate("a", 201))
  end

  test "suggest/1 returns [] for too-short queries without a network call" do
    assert CompoundSearch.suggest("a") == []
    assert CompoundSearch.suggest(nil) == []
  end
end
