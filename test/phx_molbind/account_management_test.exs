defmodule PhxMolbind.AccountManagementTest do
  use PhxMolbind.DataCase, async: true

  alias PhxMolbind.{Accounts, Collections, DataExport, Repo}
  alias PhxMolbind.Accounts.UserToken
  alias PhxMolbind.Messages.Message
  alias PhxMolbind.Molecules.Molecules
  import PhxMolbind.AccountsFixtures

  setup do
    %{user: user_fixture(), other: user_fixture()}
  end

  describe "sessions" do
    test "list marks the current session and never exposes raw tokens", %{user: user} do
      current = Accounts.generate_user_session_token(user)
      _other = Accounts.generate_user_session_token(user)

      sessions = Accounts.list_user_sessions(user, current)
      assert length(sessions) == 2
      assert Enum.count(sessions, & &1.current?) == 1
      refute Enum.any?(sessions, &(&1.id == Base.url_encode64(current)))
      assert Enum.all?(sessions, &(byte_size(&1.id) == 16))
    end

    test "expired sessions are not listed", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      old = DateTime.add(DateTime.utc_now(), -61 * 86_400, :second)

      Repo.update_all(Ecto.Query.from(t in UserToken, where: t.token == ^token),
        set: [inserted_at: old]
      )

      assert Accounts.list_user_sessions(user, nil) == []
    end

    test "revoke deletes another session, refuses the current one", %{user: user} do
      current = Accounts.generate_user_session_token(user)
      other = Accounts.generate_user_session_token(user)
      [other_ref] = for s <- Accounts.list_user_sessions(user, current), not s.current?, do: s.id
      [current_ref] = for s <- Accounts.list_user_sessions(user, current), s.current?, do: s.id

      assert {:error, :current_session} = Accounts.revoke_user_session(user, current_ref, current)
      assert {:ok, ^other} = Accounts.revoke_user_session(user, other_ref, current)

      assert Accounts.get_user_by_session_token(other) == nil
      assert Accounts.get_user_by_session_token(current).id == user.id
      assert {:error, :not_found} = Accounts.revoke_user_session(user, other_ref, current)
    end

    test "a user cannot revoke someone else's session by id", %{user: user, other: other} do
      theirs = Accounts.generate_user_session_token(other)
      [%{id: ref}] = Accounts.list_user_sessions(other, nil)

      assert {:error, :not_found} = Accounts.revoke_user_session(user, ref, nil)
      assert Accounts.get_user_by_session_token(theirs).id == other.id
    end

    test "delete_other_sessions keeps only the current one", %{user: user, other: other} do
      current = Accounts.generate_user_session_token(user)
      a = Accounts.generate_user_session_token(user)
      b = Accounts.generate_user_session_token(user)
      theirs = Accounts.generate_user_session_token(other)

      assert Enum.sort(Accounts.delete_other_sessions(user, current)) == Enum.sort([a, b])
      assert Accounts.get_user_by_session_token(current)
      assert Accounts.get_user_by_session_token(a) == nil
      assert Accounts.get_user_by_session_token(theirs)
    end
  end

  describe "profile validation" do
    test "rejects non-http photo URLs, long bios and long usernames", %{user: user} do
      for url <- [
            "javascript:alert(1)",
            "data:image/png;base64,AAAA",
            "ftp://x.test/a.png",
            "/relative.png"
          ] do
        assert {:error, cs} =
                 Accounts.update_profile(user, %{"username" => "ada", "photo_url" => url})

        assert %{metadata: [_]} = errors_on(cs)
      end

      assert {:error, _} =
               Accounts.update_profile(user, %{
                 "username" => "ada",
                 "bio" => String.duplicate("x", 501)
               })

      assert {:error, _} =
               Accounts.update_profile(user, %{"username" => String.duplicate("a", 41)})

      assert {:ok, u} =
               Accounts.update_profile(user, %{
                 "username" => "ada",
                 "photo_url" => "https://example.com/a.png",
                 "bio" => "hi"
               })

      assert u.username == "ada"
    end

    test "login-time updates are not blocked by legacy profile data", %{user: user} do
      {:ok, user} = Accounts.update_user(user, %{metadata: %{"photo_url" => "/old/relative.png"}})
      assert {:ok, _} = Accounts.find_or_create_user_by_address(user.address)
    end
  end

  describe "onboarding preference" do
    test "state is nil until set, then round-trips", %{user: user} do
      assert Accounts.onboarding_state(user) == nil
      assert {:ok, user} = Accounts.set_onboarding(user, "dismissed")
      assert Accounts.onboarding_state(user) == "dismissed"
      assert {:ok, user} = Accounts.set_onboarding(user, "restarted")
      assert Accounts.onboarding_state(Accounts.get_user(user.id)) == "restarted"
    end

    test "only known states are accepted", %{user: user} do
      assert_raise FunctionClauseError, fn -> Accounts.set_onboarding(user, "bogus") end
    end

    test "unknown stored values are treated as unset", %{user: user} do
      {:ok, user} = Accounts.update_user(user, %{metadata: %{"onboarding" => "garbage"}})
      assert Accounts.onboarding_state(user) == nil
    end

    test "visibility rules", %{user: user} do
      assert Accounts.show_onboarding?(user, 0)
      refute Accounts.show_onboarding?(user, 3)

      {:ok, dismissed} = Accounts.set_onboarding(user, "dismissed")
      refute Accounts.show_onboarding?(dismissed, 0)

      {:ok, restarted} = Accounts.set_onboarding(user, "restarted")
      assert Accounts.show_onboarding?(restarted, 5)
    end

    test "saving the profile does not wipe it, and setting it keeps profile data", %{user: user} do
      {:ok, user} = Accounts.update_profile(user, %{"username" => "ada", "bio" => "hi"})
      {:ok, user} = Accounts.set_onboarding(user, "dismissed")
      assert user.metadata["bio"] == "hi"

      {:ok, user} = Accounts.update_profile(user, %{"username" => "ada2"})
      assert Accounts.onboarding_state(user) == "dismissed"
      assert user.metadata["bio"] == "hi"
    end
  end

  describe "data export and account deletion" do
    test "export contains only the user's own data and no session tokens", %{
      user: user,
      other: other
    } do
      {:ok, _} =
        Molecules.create_history(
          %{
            algorithm: "CMA-ES",
            num_molecules: 1,
            property_name: "QED",
            minimize: false,
            min_similarity: 0.5,
            particles: 10,
            iterations: 2,
            smiles: "CCO",
            generated_molecules: %{"molecules" => [%{"structure" => "CCN", "score" => 0.4}]}
          },
          user.id
        )

      {:ok, c} = Collections.create_collection(user.id, %{name: "Picks"})

      {:ok, _} =
        Collections.add_item(user.id, c.id, %{smiles: "CCN", score: 0.4, property_name: "QED"})

      {:ok, _} = Repo.insert(Message.changeset(%Message{}, %{body: "hello", user_id: user.id}))

      {:ok, _} =
        Repo.insert(Message.changeset(%Message{}, %{body: "not mine", user_id: other.id}))

      _ = Accounts.generate_user_session_token(user)

      export = DataExport.build(user)
      assert export.account.address == user.address
      assert [%{starting_smiles: "CCO"}] = export.generation_runs
      assert [%{name: "Picks", items: [%{smiles: "CCN"}]}] = export.collections
      assert [%{body: "hello"}] = export.chat_messages
      refute inspect(export) =~ "token"
      assert {:ok, _json} = Jason.encode(export)
    end

    test "delete_account removes the user and everything they own", %{user: user, other: other} do
      {:ok, c} = Collections.create_collection(user.id, %{name: "Picks"})
      {:ok, _} = Collections.add_item(user.id, c.id, %{smiles: "CCN"})
      {:ok, _} = Collections.create_collection(other.id, %{name: "Keep"})
      token = Accounts.generate_user_session_token(user)

      assert {:ok, _} = Accounts.delete_account(user)
      assert Accounts.get_user(user.id) == nil
      assert Accounts.get_user_by_session_token(token) == nil
      assert Collections.list_collections(user.id) == []
      assert [%{name: "Keep"}] = Collections.list_collections(other.id)
    end
  end
end
