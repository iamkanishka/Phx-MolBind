defmodule PhxMolbind.CatalogTest do
  use ExUnit.Case, async: true

  alias PhxMolbind.Catalog

  test "entries are well formed and unique" do
    all = Catalog.all()
    assert length(all) >= 10
    assert length(Enum.uniq_by(all, & &1.id)) == length(all)
    assert length(Enum.uniq_by(all, &String.downcase(&1.name))) == length(all)

    for m <- all do
      assert m.smiles =~ ~r/\A[A-Za-z0-9@+\-\[\]\(\)=#$:\/\\%.*]+\z/
      assert m.molecular_weight > 0
      assert m.formula =~ ~r/\A[A-Z]/
      assert m.stereocentres_defined <= m.stereocentres
    end
  end

  test "corrected entries carry the right structures" do
    glucose = Enum.find(Catalog.all(), &(&1.id == "glucose"))
    assert glucose.formula == "C6H12O6"
    refute glucose.smiles == "C(CC(=O)O)C(=O)O"

    morphine = Enum.find(Catalog.all(), &(&1.id == "morphine"))
    assert morphine.formula == "C17H19NO3"
    assert morphine.stereocentres_defined == 0
  end

  describe "list/1" do
    test "searches name, formula, category and SMILES case-insensitively" do
      assert [%{name: "Caffeine"}] = Catalog.list(q: "CAFF")
      assert [%{name: "Benzene"}] = Catalog.list(q: "c6h6")
      assert Enum.all?(Catalog.list(q: "nsaid"), &(&1.category =~ "NSAID"))
      assert [%{name: "Ethanol"}] = Catalog.list(q: "  cco ")
      assert Catalog.list(q: "no-such-molecule") == []
    end

    test "filters by category and ignores unknown ones" do
      assert Enum.all?(Catalog.list(category: "Stimulant"), &(&1.category == "Stimulant"))
      assert length(Catalog.list(category: "Stimulant")) == 2
      assert Catalog.list(category: "") == Catalog.list()
    end

    test "sorts by name and by weight" do
      names = Enum.map(Catalog.list(), & &1.name)
      assert names == Enum.sort_by(names, &String.downcase/1)

      weights = Enum.map(Catalog.list(sort: "weight_asc"), & &1.molecular_weight)
      assert weights == Enum.sort(weights)

      assert Enum.map(Catalog.list(sort: "weight_desc"), & &1.molecular_weight) ==
               Enum.reverse(weights)

      assert Catalog.list(sort: "bogus") == Catalog.list()
    end
  end

  test "stereo_summary/1 states what is and is not defined" do
    assert Catalog.stereo_summary(%{stereocentres: 0, stereocentres_defined: 0}) ==
             "No stereocentres"

    assert Catalog.stereo_summary(%{stereocentres: 1, stereocentres_defined: 0}) ==
             "0 of 1 stereocentre defined"

    assert Catalog.stereo_summary(%{stereocentres: 5, stereocentres_defined: 4}) ==
             "4 of 5 stereocentres defined"
  end

  describe "RDKit audit" do
    @describetag :rdkit

    setup do
      available? =
        try do
          match?({_, 0}, System.cmd("python3", ["-c", "import rdkit"], stderr_to_stdout: true))
        rescue
          ErlangError -> false
        end

      if available?, do: :ok, else: {:skip, "python3 with RDKit is not installed"}
    end

    test "priv/catalog/audit.py passes against the shipped data" do
      {output, status} = System.cmd("python3", ["priv/catalog/audit.py"], stderr_to_stdout: true)
      assert status == 0, output
      assert output =~ "Catalog audit passed"
    end
  end
end
