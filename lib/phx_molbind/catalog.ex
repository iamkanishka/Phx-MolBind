defmodule PhxMolbind.Catalog do
  @moduledoc """
  The built-in reference molecule catalog shown in the Molecule Bank.

  Data lives in `priv/catalog/molecules.json` and is read at compile time.
  `priv/catalog/audit.py` re-checks every entry with RDKit (SMILES parses,
  formula, listed weight within 0.02 g/mol, stereocentre counts); run it
  whenever the file changes. Formula and stereocentre counts are *computed
  from the SMILES*; `molecular_weight` is the listed reference value. None of
  these are experimental measurements.
  """

  @path Path.expand("../../priv/catalog/molecules.json", __DIR__)
  @external_resource @path

  @data @path |> File.read!() |> Jason.decode!()

  @molecules Enum.map(@data["molecules"], fn m ->
               %{
                 id: m["id"],
                 name: m["name"],
                 smiles: m["smiles"],
                 formula: m["formula"],
                 molecular_weight: m["molecular_weight"],
                 category: m["category"],
                 stereocentres: m["stereocentres"],
                 stereocentres_defined: m["stereocentres_defined"]
               }
             end)

  @audit_note @data["audit"]["note"]
  @sorts ~w(name weight_asc weight_desc)

  @doc "All catalog entries in their stored order."
  def all, do: @molecules

  @doc "The provenance note recorded with the data file."
  def audit_note, do: @audit_note

  @doc "Accepted values for the `:sort` option of `list/1`."
  def sorts, do: @sorts

  @doc "Sorted distinct categories."
  def categories, do: @molecules |> Enum.map(& &1.category) |> Enum.uniq() |> Enum.sort()

  @doc "Finds an entry by its exact SMILES string."
  def get_by_smiles(smiles), do: Enum.find(@molecules, &(&1.smiles == smiles))

  @doc """
  Filtered, sorted entries.

  Options: `:q` (case-insensitive substring of name, formula, category or
  SMILES), `:category` (exact), `:sort` (one of `sorts/0`, default `"name"`).
  Unknown categories or sorts fall back to no filter / name order.
  """
  def list(opts \\ []) do
    q = opts |> Keyword.get(:q, "") |> to_string() |> String.trim() |> String.downcase()
    category = Keyword.get(opts, :category)

    @molecules
    |> Enum.filter(&matches_query?(&1, q))
    |> Enum.filter(&(category in [nil, ""] or &1.category == category))
    |> sort(Keyword.get(opts, :sort, "name"))
  end

  @doc "Human text for the stereochemistry state of an entry."
  def stereo_summary(%{stereocentres: 0}), do: "No stereocentres"

  def stereo_summary(%{stereocentres: total, stereocentres_defined: defined}) do
    noun = if total == 1, do: "stereocentre", else: "stereocentres"
    "#{defined} of #{total} #{noun} defined"
  end

  defp matches_query?(_molecule, ""), do: true

  defp matches_query?(m, q) do
    Enum.any?(
      [m.name, m.formula, m.category, m.smiles],
      &String.contains?(String.downcase(&1), q)
    )
  end

  defp sort(list, "weight_asc"), do: Enum.sort_by(list, & &1.molecular_weight, :asc)
  defp sort(list, "weight_desc"), do: Enum.sort_by(list, & &1.molecular_weight, :desc)
  defp sort(list, _name), do: Enum.sort_by(list, &String.downcase(&1.name))
end
