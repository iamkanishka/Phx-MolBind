defmodule PhxMolbind.Collections do
  @moduledoc """
  User collections of saved candidate molecules.

  Every function takes the acting `user_id` and scopes by it. Ids that come
  from the client are never trusted: a record that exists but belongs to
  someone else behaves exactly like one that does not exist (`nil` /
  `{:error, :not_found}`).
  """
  import Ecto.Query, only: [from: 2]

  alias PhxMolbind.Collections.{Collection, CollectionItem}
  alias PhxMolbind.Molecules.Molecule
  alias PhxMolbind.Repo

  ## Collections

  @doc "The user's collections (alphabetical) with `item_count` filled in."
  def list_collections(user_id) do
    Repo.all(
      from c in Collection,
        left_join: i in CollectionItem,
        on: i.collection_id == c.id,
        where: c.user_id == ^user_id,
        group_by: c.id,
        order_by: [asc: fragment("lower(?)", c.name), asc: c.id],
        select: %{c | item_count: count(i.id)}
    )
  end

  def get_collection(user_id, id), do: Repo.get_by(Collection, id: id, user_id: user_id)

  def create_collection(user_id, attrs) do
    %Collection{user_id: user_id} |> Collection.changeset(attrs) |> Repo.insert()
  end

  def rename_collection(user_id, id, name) do
    case get_collection(user_id, id) do
      nil -> {:error, :not_found}
      collection -> collection |> Collection.changeset(%{name: name}) |> Repo.update()
    end
  end

  @doc "Deletes a collection and its saved items. Source runs are untouched."
  def delete_collection(user_id, id) do
    case get_collection(user_id, id) do
      nil -> {:error, :not_found}
      collection -> Repo.delete(collection)
    end
  end

  ## Items

  @doc """
  Items of one of the user's collections, newest first. Pass `status:` (an
  atom from `review_statuses/0`) to filter by review status.
  """
  def list_items(user_id, collection_id, opts \\ []) do
    query =
      from i in CollectionItem,
        where: i.user_id == ^user_id and i.collection_id == ^collection_id,
        order_by: [desc: i.inserted_at, desc: i.id]

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> from i in query, where: i.review_status == ^status
      end

    Repo.all(query)
  end

  @doc """
  Saved items whose recorded source is one of `run_ids`, with their
  collection's id and name, as `[{item, %{id, name}}]`. Scoped to the user.
  """
  def items_for_runs(_user_id, []), do: []

  def items_for_runs(user_id, run_ids) do
    Repo.all(
      from i in CollectionItem,
        join: c in Collection,
        on: c.id == i.collection_id,
        where: i.user_id == ^user_id and i.source_run_id in ^run_ids,
        order_by: [asc: i.source_run_id, asc: i.id],
        select: {i, %{id: c.id, name: c.name}}
    )
  end

  @doc "Total number of molecules the user has saved across all collections."
  def count_items(user_id) do
    Repo.aggregate(from(i in CollectionItem, where: i.user_id == ^user_id), :count, :id)
  end

  @doc "Counts of items per review status for a collection (statuses with none are absent)."
  def review_counts(user_id, collection_id) do
    Repo.all(
      from i in CollectionItem,
        where: i.user_id == ^user_id and i.collection_id == ^collection_id,
        group_by: i.review_status,
        select: {i.review_status, count(i.id)}
    )
    |> Map.new()
  end

  @doc "All review statuses, in display order."
  def review_statuses, do: Ecto.Enum.values(CollectionItem, :review_status)

  @doc """
  Sets the review status of one of the user's saved items. `status` may be an
  atom or its string form (as received from the client); anything outside
  `review_statuses/0` is rejected.
  """
  def set_review_status(user_id, item_id, status) do
    with {:ok, status} <- cast_status(status),
         %CollectionItem{} = item <- Repo.get_by(CollectionItem, id: item_id, user_id: user_id) do
      item |> Ecto.Changeset.change(review_status: status) |> Repo.update()
    else
      nil -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  @doc "Parses a status from its string or atom form."
  def cast_status(status) when is_atom(status) and not is_nil(status) do
    if status in review_statuses(), do: {:ok, status}, else: {:error, :invalid_status}
  end

  def cast_status(status) when is_binary(status) do
    case Enum.find(review_statuses(), &(Atom.to_string(&1) == status)) do
      nil -> {:error, :invalid_status}
      found -> {:ok, found}
    end
  end

  def cast_status(_), do: {:error, :invalid_status}

  @doc """
  Saves a candidate into one of the user's collections.

  `attrs` may contain `:smiles`, `:score`, `:property_name` and
  `:source_run_id`. The run id is kept only if that run belongs to the same
  user; otherwise provenance is dropped rather than trusted.
  """
  def add_item(user_id, collection_id, attrs) do
    with %Collection{} = collection <- get_collection(user_id, collection_id) do
      run_id = owned_run_id(user_id, Map.get(attrs, :source_run_id))

      %CollectionItem{collection_id: collection.id, user_id: user_id, source_run_id: run_id}
      |> CollectionItem.changeset(Map.take(attrs, [:smiles, :score, :property_name]))
      |> Repo.insert()
    else
      nil -> {:error, :not_found}
    end
  end

  def remove_item(user_id, item_id) do
    case Repo.get_by(CollectionItem, id: item_id, user_id: user_id) do
      nil -> {:error, :not_found}
      item -> Repo.delete(item)
    end
  end

  defp owned_run_id(_user_id, nil), do: nil

  defp owned_run_id(user_id, run_id) do
    Repo.one(from m in Molecule, where: m.id == ^run_id and m.user_id == ^user_id, select: m.id)
  end

  ## CSV export

  @csv_headers ~w(smiles score score_property review_status saved_at)

  @doc """
  CSV (RFC 4180, CRLF line endings) of saved items with stable headers.
  Cells that a spreadsheet could execute as a formula (leading `= + - @`,
  tab or CR) are prefixed with a single quote.
  """
  def items_to_csv(items) do
    rows =
      for item <- items do
        [
          item.smiles,
          if(item.score, do: {:raw, Float.to_string(item.score)}),
          item.property_name,
          to_string(item.review_status),
          if(item.inserted_at, do: NaiveDateTime.to_iso8601(item.inserted_at))
        ]
      end

    [@csv_headers | rows] |> Enum.map_join("\r\n", &csv_row/1) |> Kernel.<>("\r\n")
  end

  def csv_row(cells), do: Enum.map_join(cells, ",", &csv_cell/1)

  defp csv_cell(nil), do: ""
  # Numbers are emitted as-is: a negative score must not be quoted as text.
  defp csv_cell({:raw, value}), do: value

  defp csv_cell(value) do
    value = to_string(value)

    value =
      if String.starts_with?(value, ["=", "+", "-", "@", "\t", "\r"]),
        do: "'" <> value,
        else: value

    if String.contains?(value, [",", "\"", "\r", "\n"]),
      do: "\"" <> String.replace(value, "\"", "\"\"") <> "\"",
      else: value
  end
end
