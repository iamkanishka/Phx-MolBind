defmodule PhxMolbind.Collections.CollectionItem do
  @moduledoc """
  A saved candidate. `score` is the value the generation service reported for
  `property_name` at generation time (a model output, not a measurement); both
  are nil when unknown.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "collection_items" do
    field :smiles, :string
    field :score, :float
    field :property_name, :string

    field :review_status, Ecto.Enum,
      values: [:unreviewed, :shortlisted, :rejected, :needs_inspection],
      default: :unreviewed

    belongs_to :collection, PhxMolbind.Collections.Collection
    belongs_to :user, PhxMolbind.Accounts.User
    belongs_to :source_run, PhxMolbind.Molecules.Molecule

    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:smiles, :score, :property_name])
    |> update_change(:smiles, &String.trim/1)
    |> validate_required([:smiles])
    |> validate_length(:smiles, max: 500)
    |> validate_length(:property_name, max: 40)
    |> unique_constraint(:smiles,
      name: :collection_items_collection_id_smiles_index,
      message: "is already in this collection"
    )
  end
end
