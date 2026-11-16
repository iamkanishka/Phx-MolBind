defmodule PhxMolbind.Molecules.ComparisonTest do
  use ExUnit.Case, async: true

  alias PhxMolbind.Molecules.{Comparison, Molecule}

  defp run(overrides \\ %{}, molecules \\ []) do
    struct(
      Molecule,
      Map.merge(
        %{
          id: 1,
          algorithm: "CMA-ES",
          num_molecules: 3,
          property_name: "QED",
          minimize: false,
          min_similarity: 0.5,
          particles: 30,
          iterations: 10,
          smiles: "CCO",
          inserted_at: ~N[2026-10-14 10:00:00],
          generated_molecules: %{"molecules" => molecules}
        },
        overrides
      )
    )
  end

  defp mol(structure, score), do: %{"structure" => structure, "score" => score}

  test "flags only the parameters that differ" do
    result = Comparison.compare(run(), run(%{id: 2, particles: 50, minimize: true}))
    differing = for %{differs?: true, label: l} <- result.parameters, do: l
    assert Enum.sort(differing) == ["Objective", "Particles"]
    refute result.starting_molecule.differs?
  end

  test "stats follow each run's own objective" do
    a = run(%{}, [mol("CCN", 0.2), mol("CCC", 0.8)])
    b = run(%{id: 2, minimize: true}, [mol("CCN", 0.2), mol("CCC", 0.8)])

    result = Comparison.compare(a, b)
    assert result.stats.a.best == 0.8
    assert result.stats.b.best == 0.2
    assert_in_delta result.stats.a.mean, 0.5, 1.0e-9
    refute result.scores_comparable?
  end

  test "scores are comparable only for the same property and direction" do
    assert Comparison.compare(run(), run(%{id: 2})).scores_comparable?
    refute Comparison.compare(run(), run(%{id: 2, property_name: "plogP"})).scores_comparable?
  end

  test "missing scores and empty runs produce nil stats, not zeros" do
    result = Comparison.compare(run(%{}, [%{"structure" => "CCN"}]), run(%{id: 2}))
    assert result.stats.a == %{returned: 1, scored: 0, best: nil, mean: nil}
    assert result.stats.b == %{returned: 0, scored: 0, best: nil, mean: nil}
  end

  test "shared candidates are exact string matches only" do
    a = run(%{}, [mol("CCN", 0.1), mol("CCC", 0.2)])
    b = run(%{id: 2}, [mol("CCC", 0.3), mol("NCC", 0.4)])
    assert Comparison.compare(a, b).shared_candidates == ["CCC"]
  end
end
