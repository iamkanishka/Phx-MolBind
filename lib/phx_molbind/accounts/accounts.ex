defmodule PhxMolbind.Accounts.Accounts do
  alias PhxMolbind.Accounts.User
  alias PhxMolbind.Repo

  def get_user_by_address(address), do: Repo.get_by(User, address: address)

  def get_user!(id), do: Repo.get!(User, id)

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end
end
