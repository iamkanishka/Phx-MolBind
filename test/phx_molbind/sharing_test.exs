defmodule PhxMolbind.SharingTest do
  use PhxMolbind.DataCase, async: true

  alias PhxMolbind.{Accounts, Collections, Repo, Sharing}
  alias PhxMolbind.Molecules.Molecules
  alias PhxMolbind.Sharing.ShareLink
  import PhxMolbind.AccountsFixtures

  setup do
    user = user_fixture()
    other = user_fixture()

    {:ok, run} =
      Molecules.create_history(
        %{
          algorithm: "CMA-ES",
          num_molecules: 2,
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

    {:ok, collection} = Collections.create_collection(user.id, %{name: "Private name"})

    {:ok, item} =
      Collections.add_item(user.id, collection.id, %{
        smiles: "CCN",
        score: 0.4,
        property_name: "QED",
        source_run_id: run.id
      })

    {:ok, _} = Collections.set_review_status(user.id, item.id, :shortlisted)

    %{user: user, other: other, run: run, collection: collection}
  end

  describe "creating links" do
    test "owners can share their own run and collection", %{user: user, run: run, collection: c} do
      assert {:ok, %ShareLink{kind: "run"}, token} = Sharing.create_link(user.id, "run", run.id)
      assert byte_size(token) >= 40

      assert {:ok, %ShareLink{kind: "collection"}, _} =
               Sharing.create_link(user.id, "collection", c.id, "never")
    end

    test "nobody can share someone else's run or collection", %{
      other: other,
      run: run,
      collection: c
    } do
      assert {:error, :not_found} = Sharing.create_link(other.id, "run", run.id)
      assert {:error, :not_found} = Sharing.create_link(other.id, "collection", c.id)
      assert Repo.aggregate(ShareLink, :count) == 0
    end

    test "unknown kinds, missing targets and bad expiries are rejected", %{user: user, run: run} do
      assert {:error, :not_found} = Sharing.create_link(user.id, "user", user.id)
      assert {:error, :not_found} = Sharing.create_link(user.id, "run", 0)
      assert {:error, :invalid_expiry} = Sharing.create_link(user.id, "run", run.id, "forever")
    end

    test "only a hash is stored, and every link gets a distinct secret", %{user: user, run: run} do
      {:ok, l1, t1} = Sharing.create_link(user.id, "run", run.id)
      {:ok, l2, t2} = Sharing.create_link(user.id, "run", run.id)

      assert t1 != t2 and l1.token_hash != l2.token_hash
      refute l1.token_hash == t1

      stored = Repo.all(ShareLink) |> inspect()
      refute stored =~ t1
      refute stored =~ t2
    end

    test "expiry options set expires_at", %{user: user, run: run} do
      {:ok, never, _} = Sharing.create_link(user.id, "run", run.id, "never")
      assert never.expires_at == nil

      {:ok, week, _} = Sharing.create_link(user.id, "run", run.id, "7")
      diff = DateTime.diff(week.expires_at, DateTime.utc_now(), :second)
      assert diff > 6 * 86_400 and diff <= 7 * 86_400
    end
  end

  describe "resolving links" do
    test "a run link exposes only whitelisted fields", %{user: user, run: run} do
      {:ok, _, token} = Sharing.create_link(user.id, "run", run.id)
      assert {:ok, payload} = Sharing.resolve(token)

      assert Map.keys(payload) |> Enum.sort() ==
               ~w(candidates created_on kind parameters property_name starting_smiles title)a

      assert payload.starting_smiles == "CCO"
      assert [%{structure: "CCN", score: 0.4}] = payload.candidates
      assert Map.keys(hd(payload.candidates)) |> Enum.sort() == [:score, :structure]

      dump = inspect(payload)
      refute dump =~ user.address
      refute dump =~ "user_id"
    end

    test "a collection link hides review status, provenance and the owner", %{
      user: user,
      collection: c,
      run: run
    } do
      {:ok, _, token} = Sharing.create_link(user.id, "collection", c.id)
      assert {:ok, payload} = Sharing.resolve(token)

      assert payload.title == "Private name"
      assert [item] = payload.items
      assert Map.keys(item) |> Enum.sort() == [:property_name, :score, :smiles]

      dump = inspect(payload)
      refute dump =~ "shortlisted"
      refute dump =~ "review"
      refute dump =~ "source_run"
      refute dump =~ user.address
      refute dump =~ to_string(run.id) <> ","
    end

    test "malformed, unknown and non-string tokens all look the same" do
      random = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      for token <- [nil, 123, "", "short", String.duplicate("a", 500), random, "../../etc/passwd"] do
        assert Sharing.resolve(token) == {:error, :not_found}
      end
    end

    test "revoked links stop working immediately and revoking is owner-only",
         %{user: user, other: other, run: run} do
      {:ok, link, token} = Sharing.create_link(user.id, "run", run.id)

      assert {:error, :not_found} = Sharing.revoke_link(other.id, link.id)
      assert {:ok, _} = Sharing.resolve(token)

      assert {:ok, revoked} = Sharing.revoke_link(user.id, link.id)
      assert revoked.revoked_at
      assert Sharing.resolve(token) == {:error, :not_found}
      assert {:ok, _} = Sharing.revoke_link(user.id, link.id)
    end

    test "expired links stop working", %{user: user, run: run} do
      {:ok, link, token} = Sharing.create_link(user.id, "run", run.id, "1")
      assert {:ok, _} = Sharing.resolve(token)

      past = DateTime.add(DateTime.utc_now(), -60, :second)
      link |> Ecto.Changeset.change(expires_at: past) |> Repo.update!()
      assert Sharing.resolve(token) == {:error, :not_found}
    end

    test "deleting the target or the owner kills the link", %{user: user, run: run, collection: c} do
      {:ok, _, run_token} = Sharing.create_link(user.id, "run", run.id)
      {:ok, _, col_token} = Sharing.create_link(user.id, "collection", c.id)

      {:ok, _} = Molecules.delete_history_entry(user.id, run.id)
      assert Sharing.resolve(run_token) == {:error, :not_found}

      assert {:ok, _} = Sharing.resolve(col_token)
      {:ok, _} = Accounts.delete_account(user)
      assert Sharing.resolve(col_token) == {:error, :not_found}
      assert Repo.aggregate(ShareLink, :count) == 0
    end
  end

  describe "listing" do
    test "links are listed per owner and target, with an active count",
         %{user: user, other: other, run: run} do
      {:ok, l1, _} = Sharing.create_link(user.id, "run", run.id)
      {:ok, _, _} = Sharing.create_link(user.id, "run", run.id)
      assert length(Sharing.list_links(user.id, "run", run.id)) == 2
      assert Sharing.list_links(other.id, "run", run.id) == []
      assert Sharing.active_count(user.id, "run", run.id) == 2

      {:ok, _} = Sharing.revoke_link(user.id, l1.id)
      assert Sharing.active_count(user.id, "run", run.id) == 1
    end
  end
end
