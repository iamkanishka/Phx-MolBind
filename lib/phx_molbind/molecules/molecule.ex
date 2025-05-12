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
    field :smi, :string
    field :generated_molecules, :map, default: %{}

    belongs_to :user, PhxMolbind.Accounts.User

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
      :smi,
      :generated_molecules,
      :user_id
    ])
    |> validate_required([
      :algorithm,
      :num_molecules,
      :property_name,
      :minimize,
      :min_similarity,
      :particles,
      :iterations,
      :smi,
      :user_id
    ])
  end
end
