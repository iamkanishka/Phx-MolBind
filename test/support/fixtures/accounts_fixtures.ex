defmodule PhxMolbind.AccountsFixtures do
  @moduledoc """
  Test helpers for creating entities via the `PhxMolbind.Accounts` context.
  """

  @doc "Returns a syntactically-valid, unique-per-call Ethereum address."
  def unique_user_address do
    suffix =
      :crypto.strong_rand_bytes(20)
      |> Base.encode16(case: :lower)

    "0x" <> suffix
  end

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{address: unique_user_address()})
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> PhxMolbind.Accounts.create_user()

    user
  end
end
