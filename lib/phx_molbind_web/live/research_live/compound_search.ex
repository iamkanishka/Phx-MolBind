defmodule PhxMolbindWeb.ResearchLive.CompoundSearch do
  @moduledoc "Handles fetching compound data from PubChem using Finch."

  @finch PhxMolbind.Finch
  @base_url "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name"

  def lookup(""), do: {:error, "Compound name is required"}

  def lookup(name) do
    encoded = URI.encode(name)

    url =
      "#{@base_url}/#{encoded}/property/" <>
        "MolecularFormula,MolecularWeight,InChIKey,CanonicalSMILES,IsomericSMILES," <>
        "IUPACName,XLogP,ExactMass,MonoisotopicMass,TPSA,Complexity,Charge," <>
        "HBondDonorCount,HBondAcceptorCount,RotatableBondCount,HeavyAtomCount/JSON"

    case Finch.build(:get, url) |> Finch.request(@finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        with {:ok, %{"PropertyTable" => %{"Properties" => [info | _]}}} <- Jason.decode(body) do
          {:ok, info}
        else
          _ -> {:error, "Compound data is not available"}
        end

      {:ok, %Finch.Response{status: status}} when status in 400..499 ->
        {:error, "Compound not found"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end
end
