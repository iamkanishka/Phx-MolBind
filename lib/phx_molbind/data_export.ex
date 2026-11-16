defmodule PhxMolbind.DataExport do
  @moduledoc """
  Builds a machine-readable export of everything MolBind stores about a user:
  profile, generation runs, collections (with saved molecules) and chat
  messages they wrote. Session tokens are deliberately excluded.

  Scores in runs and collections are values reported by the generation
  service (model outputs), exported as stored.
  """
  import Ecto.Query, only: [from: 2]

  alias PhxMolbind.{Collections, Repo}
  alias PhxMolbind.Messages.Message
  alias PhxMolbind.Molecules.Molecule

  def build(%{id: user_id} = user) do
    %{
      format: "molbind-export",
      version: 1,
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      account: %{
        address: user.address,
        username: user.username,
        metadata: user.metadata || %{},
        created_at: iso(user.inserted_at),
        last_login_at: iso(user.last_login_at)
      },
      generation_runs: runs(user_id),
      collections: collections(user_id),
      chat_messages: messages(user_id)
    }
  end

  defp runs(user_id) do
    Repo.all(
      from m in Molecule, where: m.user_id == ^user_id, order_by: [asc: m.inserted_at, asc: m.id]
    )
    |> Enum.map(fn m ->
      %{
        id: m.id,
        created_at: iso(m.inserted_at),
        starting_smiles: m.smiles,
        parent_run_id: m.parent_run_id,
        parent_candidate_index: m.parent_candidate_index,
        parameters: %{
          algorithm: m.algorithm,
          num_molecules: m.num_molecules,
          property_name: m.property_name,
          minimize: m.minimize,
          min_similarity: m.min_similarity,
          particles: m.particles,
          iterations: m.iterations
        },
        generated_molecules: m.generated_molecules
      }
    end)
  end

  defp collections(user_id) do
    for c <- Collections.list_collections(user_id) do
      %{
        name: c.name,
        created_at: iso(c.inserted_at),
        items:
          for i <- Collections.list_items(user_id, c.id) do
            %{
              smiles: i.smiles,
              score: i.score,
              score_property: i.property_name,
              review_status: i.review_status,
              source_run_id: i.source_run_id,
              saved_at: iso(i.inserted_at)
            }
          end
      }
    end
  end

  defp messages(user_id) do
    Repo.all(
      from m in Message, where: m.user_id == ^user_id, order_by: [asc: m.inserted_at, asc: m.id]
    )
    |> Enum.map(&%{body: &1.body, shared_smiles: &1.smiles, sent_at: iso(&1.inserted_at)})
  end

  defp iso(nil), do: nil
  defp iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp iso(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
end
