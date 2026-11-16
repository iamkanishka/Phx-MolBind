defmodule PhxMolbind.Molecules.Comparison do
  @moduledoc """
  Compares two saved generation runs without inventing anything: every value
  comes from the stored records.

    * Parameter rows are listed with a `differs?` flag so changes stand out.
    * Score statistics (best, mean) are computed per run from the scores the
      service reported. "Best" follows each run's own objective (lowest when
      `minimize` is true, otherwise highest).
    * Scores are only called comparable when both runs optimised the same
      property in the same direction; otherwise the stats are still shown per
      run but flagged as not directly comparable.
    * Shared candidates are exact SMILES-string matches. SMILES are not
      canonicalised here, so two spellings of the same molecule are not
      detected as shared.
  """
  alias PhxMolbind.Molecules.{Molecule, Molecules}

  def compare(%Molecule{} = a, %Molecule{} = b) do
    cands_a = Molecules.candidates(a)
    cands_b = Molecules.candidates(b)

    %{
      starting_molecule: %{a: a.smiles, b: b.smiles, differs?: a.smiles != b.smiles},
      parameters: parameters(a, b),
      stats: %{a: stats(a, cands_a), b: stats(b, cands_b)},
      scores_comparable?: a.property_name == b.property_name and a.minimize == b.minimize,
      shared_candidates: shared(cands_a, cands_b),
      metadata: %{
        a: %{id: a.id, saved_at: a.inserted_at},
        b: %{id: b.id, saved_at: b.inserted_at}
      }
    }
  end

  defp parameters(a, b) do
    [
      {"Algorithm", :algorithm},
      {"Property", :property_name},
      {"Objective", :minimize},
      {"Molecules requested", :num_molecules},
      {"Minimum similarity", :min_similarity},
      {"Particles", :particles},
      {"Iterations", :iterations}
    ]
    |> Enum.map(fn {label, field} ->
      va = Map.fetch!(a, field)
      vb = Map.fetch!(b, field)
      %{label: label, a: display(field, va), b: display(field, vb), differs?: va != vb}
    end)
  end

  defp display(:minimize, true), do: "Minimise"
  defp display(:minimize, false), do: "Maximise"
  defp display(_field, value), do: value

  defp stats(run, candidates) do
    scores = for %{score: s} <- candidates, is_number(s), do: s

    best =
      cond do
        scores == [] -> nil
        run.minimize -> Enum.min(scores)
        true -> Enum.max(scores)
      end

    %{
      returned: length(candidates),
      scored: length(scores),
      best: best,
      mean: if(scores == [], do: nil, else: Enum.sum(scores) / length(scores))
    }
  end

  defp shared(cands_a, cands_b) do
    in_b = MapSet.new(cands_b, & &1.structure)

    cands_a
    |> Enum.map(& &1.structure)
    |> Enum.filter(&MapSet.member?(in_b, &1))
    |> Enum.uniq()
  end
end
