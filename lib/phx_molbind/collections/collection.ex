defmodule PhxMolbind.Collections.Collection do
  @moduledoc "A user-owned, named group of saved candidate molecules."
  use Ecto.Schema
  import Ecto.Changeset

  schema "collections" do
    field :name, :string
    field :item_count, :integer, virtual: true, default: 0

    belongs_to :user, PhxMolbind.Accounts.User
    has_many :items, PhxMolbind.Collections.CollectionItem

    timestamps()
  end

  @doc false
  def changeset(collection, attrs) do
    collection
    |> cast(attrs, [:name])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: 80)
    |> unique_constraint(:name,
      name: :collections_user_id_name_index,
      message: "you already have a collection with this name"
    )
  end
end
