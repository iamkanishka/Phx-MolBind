defmodule PhxMolbindWeb.ResearchLive.CompoundSearch do
  @moduledoc """
  Fetches compound data from PubChem (PUG REST) using Finch.

  All property values are returned exactly as PubChem reports them; nothing
  is substituted or computed here. Errors are returned as user-safe strings
  (no inspected exceptions).
  """

  @finch PhxMolbind.Finch
  @base_url "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name"
  @autocomplete_url "https://pubchem.ncbi.nlm.nih.gov/rest/autocomplete/compound,gene,taxonomy"
  @max_name_length 200

  # Keys under which PubChem has reported SMILES. PubChem's documentation
  # lists CanonicalSMILES/IsomericSMILES; newer responses may use
  # ConnectivitySMILES/SMILES, so all are accepted (isomeric first, which
  # preserves stereochemistry).
  @isomeric_keys ["IsomericSMILES", "SMILES"]
  @connectivity_keys ["CanonicalSMILES", "ConnectivitySMILES"]

  @spec lookup(String.t()) :: {:ok, map()} | {:error, String.t()}
  def lookup(name) when is_binary(name) do
    name = String.trim(name)

    cond do
      name == "" -> {:error, "Compound name is required"}
      String.length(name) > @max_name_length -> {:error, "Compound name is too long"}
      true -> do_lookup(name)
    end
  end

  def lookup(_), do: {:error, "Compound name is required"}

  defp do_lookup(name) do
    url =
      "#{@base_url}/#{encode(name)}/property/" <>
        "MolecularFormula,MolecularWeight,InChIKey,CanonicalSMILES,IsomericSMILES," <>
        "IUPACName,XLogP,ExactMass,MonoisotopicMass,TPSA,Complexity,Charge," <>
        "HBondDonorCount,HBondAcceptorCount,RotatableBondCount,HeavyAtomCount/JSON"

    case Finch.build(:get, url) |> Finch.request(@finch, receive_timeout: 15_000) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        with {:ok, %{"PropertyTable" => %{"Properties" => [info | _]}}} <- Jason.decode(body) do
          {:ok, info}
        else
          _ -> {:error, "PubChem returned data this page could not read"}
        end

      {:ok, %Finch.Response{status: 404}} ->
        {:error, "No PubChem compound found for “#{name}”"}

      {:ok, %Finch.Response{status: status}} when status in [429, 503] ->
        {:error, "PubChem is busy or rate limiting requests. Try again in a moment."}

      {:ok, %Finch.Response{status: status}} when status in 400..499 ->
        {:error, "PubChem could not process this search (HTTP #{status})"}

      {:ok, %Finch.Response{status: status}} ->
        {:error, "PubChem had a server error (HTTP #{status}). Try again shortly."}

      {:error, _reason} ->
        {:error, "Could not reach PubChem. Check your connection and retry."}
    end
  end

  @doc "Up to 10 compound-name suggestions for `query`; `[]` on any failure."
  @spec suggest(String.t()) :: [String.t()]
  def suggest(query) when is_binary(query) do
    query = String.trim(query)

    if String.length(query) < 2 or String.length(query) > @max_name_length do
      []
    else
      headers = [
        {"NCBI-PHID", "95B7506F824A39291747389517618SID.06"},
        {"User-Agent", "Mozilla/5.0"},
        {"Referer", "https://pubchem.ncbi.nlm.nih.gov"},
        {"Accept", "application/json"}
      ]

      with {:ok, %Finch.Response{status: 200, body: body}} <-
             Finch.build(:get, "#{@autocomplete_url}/#{encode(query)}", headers)
             |> Finch.request(@finch, receive_timeout: 8_000),
           {:ok, %{"dictionary_terms" => %{"compound" => compounds}}} when is_list(compounds) <-
             Jason.decode(body) do
        compounds |> Enum.filter(&is_binary/1) |> Enum.take(10)
      else
        _ -> []
      end
    end
  end

  def suggest(_), do: []

  @doc "SMILES for handoff: isomeric (stereo-preserving) when available."
  @spec smiles(map()) :: String.t() | nil
  def smiles(info), do: first_value(info, @isomeric_keys ++ @connectivity_keys)

  @doc "Connectivity-only SMILES (no stereochemistry), when PubChem provides it."
  @spec connectivity_smiles(map()) :: String.t() | nil
  def connectivity_smiles(info), do: first_value(info, @connectivity_keys)

  @doc "Isomeric SMILES, when PubChem provides it."
  @spec isomeric_smiles(map()) :: String.t() | nil
  def isomeric_smiles(info), do: first_value(info, @isomeric_keys)

  @doc "Link to the authoritative PubChem record, or nil when no CID is known."
  @spec record_url(map()) :: String.t() | nil
  def record_url(%{"CID" => cid}) when is_integer(cid),
    do: "https://pubchem.ncbi.nlm.nih.gov/compound/#{cid}"

  def record_url(_), do: nil

  defp first_value(info, keys) do
    Enum.find_value(keys, fn key ->
      case Map.get(info, key) do
        value when is_binary(value) and value != "" -> value
        _ -> nil
      end
    end)
  end

  # Percent-encode everything except RFC 3986 unreserved characters, so names
  # containing "/", "?" or "#" cannot alter the request path.
  defp encode(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
