defmodule PhxMolbind.Molecules.Molecule do
  @moduledoc """
  The Molecules context.
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "molecule_optimizations" do
    field :algorithm, :string
    field :num_molecules, :integer
    field :property_name, :string
    field :minimize, :boolean, default: false
    field :min_similarity, :float
    field :particles, :integer
    field :iterations, :integer
    field :smiles, :string
    field :generated_molecules, :map, default: %{}

    field :parent_candidate_index, :integer

    belongs_to :user, PhxMolbind.Accounts.User
    belongs_to :parent_run, __MODULE__

    timestamps()
  end

  def changeset(optimization, attrs) do
    optimization
    |> cast(attrs, [
      :algorithm,
      :num_molecules,
      :property_name,
      :minimize,
      :min_similarity,
      :particles,
      :iterations,
      :smiles,
      :generated_molecules,
      :user_id,
      :parent_run_id,
      :parent_candidate_index
    ])
    |> validate_required([
      :algorithm,
      :num_molecules,
      :property_name,
      :minimize,
      :min_similarity,
      :particles,
      :iterations,
      :smiles,
      :user_id
    ])
  end
end
