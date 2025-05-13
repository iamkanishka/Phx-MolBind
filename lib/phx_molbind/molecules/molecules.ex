defmodule PhxMolbind.Molecules.Molecules do
  alias PhxMolbind.Repo

  alias PhxMolbind.Accounts.Accounts

  alias PhxMolbind.Molecules.Molecule
  import Ecto.Query, only: [from: 2]

  def get_user_by_email(address) do
    Accounts.get_user_by_address(address)
  end

  def get_history_for_user(user_id) do
    Repo.all(
      from mo in Molecule,
        join: u in assoc(mo, :user),
        where: u.user_id == ^user_id,
        preload: [:user]
    )
  end

  def create_history(attrs, user_id) do
    %Molecule{}
    |> Molecule.changeset(Map.put(attrs, :user_id, user_id))
    |> Repo.insert()
  end

  @spec generate_molecules(any()) ::
          {:error,
           {:error, map()}
           | {:ok, any()}
           | %{:__exception__ => true, :__struct__ => atom(), optional(atom()) => any()}}
          | {:ok, list()}
  def generate_molecules(payload) do
    url = "https://health.api.nvidia.com/v1/biology/nvidia/molmim/generate"

    headers = [
      {"Authorization",
       "Bearer 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"},
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]

    case Finch.build(:post, url, headers, Jason.encode!(payload))
         |> Finch.request(PhxMolbind.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        with {:ok, %{"molecules" => molecules_str}} <- Jason.decode(body),
             {:ok, molecules_list} <- Jason.decode(molecules_str) do
          {:ok,
           Enum.map(molecules_list, fn %{"sample" => smi, "score" => score} ->
             %{structure: smi, score: score}
           end)}
        else
          error -> {:error, error}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
