
defmodule PhxMolbind.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :address, :string
    field :nonce, :string
    field :username, :string
    field :metadata, :map, default: %{}
    field :last_login_at, :utc_datetime_usec

    timestamps(type: :utc_datetime)

  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:address, :nonce, :username, :metadata, :last_login_at])
    |> validate_required([:address, :nonce])
    |> unique_constraint(:address)
  end
end
