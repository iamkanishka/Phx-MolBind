defmodule PhxMolbind.AccountsTest do
  use PhxMolbind.DataCase, async: true

  alias PhxMolbind.Accounts
  alias PhxMolbind.Accounts.User

  import PhxMolbind.AccountsFixtures

  describe "create_user/1" do
    test "creates a user with a valid address" do
      assert {:ok, %User{} = user} = Accounts.create_user(%{address: unique_user_address()})
      assert user.address == String.downcase(user.address)
    end

    test "normalizes (downcases) a mixed-case address on write" do
      address = "0x" <> String.upcase(String.trim_leading(unique_user_address(), "0x"))
      assert {:ok, user} = Accounts.create_user(%{address: address})
      assert user.address == String.downcase(address)
    end

    test "rejects a malformed address" do
      assert {:error, changeset} = Accounts.create_user(%{address: "not-an-address"})
      assert %{address: [_]} = errors_on(changeset)
    end

    test "rejects a duplicate address" do
      address = unique_user_address()
      assert {:ok, _} = Accounts.create_user(%{address: address})
      assert {:error, changeset} = Accounts.create_user(%{address: address})
      assert %{address: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_user_by_address/1" do
    test "finds a user regardless of the query's case" do
      user = user_fixture()
      assert Accounts.get_user_by_address(String.upcase(user.address)).id == user.id
      assert Accounts.get_user_by_address(user.address).id == user.id
    end

    test "returns nil for an unknown address" do
      refute Accounts.get_user_by_address(unique_user_address())
    end
  end

  describe "find_or_create_user_by_address/1" do
    test "creates a new user on first login" do
      address = unique_user_address()
      assert {:ok, user} = Accounts.find_or_create_user_by_address(address)
      assert user.address == String.downcase(address)
      assert user.last_login_at
    end

    test "reuses the existing user and bumps last_login_at on subsequent logins" do
      user = user_fixture(%{address: unique_user_address()})
      assert {:ok, again} = Accounts.find_or_create_user_by_address(user.address)
      assert again.id == user.id
      assert again.last_login_at
    end
  end

  describe "update_profile/2" do
    test "sets username and merges bio/photo_url into metadata" do
      user = user_fixture()

      assert {:ok, updated} =
               Accounts.update_profile(user, %{
                 "username" => "researcher1",
                 "bio" => "Studying kinase inhibitors.",
                 "photo_url" => "https://example.com/me.png"
               })

      assert updated.username == "researcher1"
      assert updated.metadata["bio"] == "Studying kinase inhibitors."
      assert updated.metadata["photo_url"] == "https://example.com/me.png"
    end

    test "leaves fields not included in attrs untouched" do
      user = user_fixture()

      {:ok, user} =
        Accounts.update_profile(user, %{"username" => "a", "bio" => "first bio"})

      assert {:ok, updated} = Accounts.update_profile(user, %{"username" => "b"})
      assert updated.username == "b"
      assert updated.metadata["bio"] == "first bio"
    end
  end

  describe "session tokens" do
    test "generate_user_session_token/1 produces a token that resolves back to the user" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.get_user_by_session_token(token).id == user.id
    end

    test "get_user_by_session_token/1 returns nil for a bogus token" do
      refute Accounts.get_user_by_session_token(:crypto.strong_rand_bytes(32))
    end

    test "delete_user_session_token/1 invalidates the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert :ok = Accounts.delete_user_session_token(token)
      refute Accounts.get_user_by_session_token(token)
    end
  end
end
