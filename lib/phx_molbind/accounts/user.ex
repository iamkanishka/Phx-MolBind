
defmodule PhxMolbind.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :address, :string

    field :last_login_at, :utc_datetime_usec

    timestamps(type: :utc_datetime)

  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:address,:last_login_at])
    |> validate_required([:address, :last_login_at])
    |> unique_constraint(:address)
  end
end
