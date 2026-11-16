defmodule PhxMolbindWeb.ShareLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PhxMolbind.AccountsFixtures

  alias PhxMolbind.{Collections, Sharing}
  alias PhxMolbind.Molecules.Molecules

  defp make_run(user) do
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

    run
  end

  describe "public page (signed out)" do
    test "renders a shared run with privacy headers and without the app shell", %{conn: conn} do
      user = user_fixture()
      run = make_run(user)
      {:ok, _, token} = Sharing.create_link(user.id, "run", run.id)

      resp = get(conn, ~p"/s/#{token}")
      assert html_response(resp, 200) =~ "Shared from MolBind"
      assert get_resp_header(resp, "referrer-policy") == ["no-referrer"]
      assert get_resp_header(resp, "x-robots-tag") == ["noindex, nofollow"]
      assert get_resp_header(resp, "cache-control") == ["no-store"]

      {:ok, _view, html} = live(conn, ~p"/s/#{token}")
      assert html =~ "CCN" and html =~ "0.4000" and html =~ "read-only"
      refute html =~ ~s(id="app-sidebar")
      refute html =~ user.address
    end

    test "a shared collection shows items but never review statuses", %{conn: conn} do
      user = user_fixture()
      {:ok, c} = Collections.create_collection(user.id, %{name: "Open set"})

      {:ok, item} =
        Collections.add_item(user.id, c.id, %{smiles: "CCN", score: 0.4, property_name: "QED"})

      {:ok, _} = Collections.set_review_status(user.id, item.id, :rejected)
      {:ok, _, token} = Sharing.create_link(user.id, "collection", c.id)

      {:ok, _view, html} = live(conn, ~p"/s/#{token}")
      assert html =~ "Open set" and html =~ "CCN"
      refute html =~ ~r/rejected|shortlisted|needs/i
    end

    test "unknown, revoked and expired links are all the same 404", %{conn: conn} do
      user = user_fixture()
      run = make_run(user)
      {:ok, link, token} = Sharing.create_link(user.id, "run", run.id)
      {:ok, expired, expired_token} = Sharing.create_link(user.id, "run", run.id)

      expired
      |> Ecto.Changeset.change(expires_at: DateTime.add(DateTime.utc_now(), -5, :second))
      |> PhxMolbind.Repo.update!()

      Sharing.revoke_link(user.id, link.id)

      for t <- [token, expired_token, "does-not-exist-" <> String.duplicate("x", 30)] do
        assert_error_sent 404, fn -> get(conn, ~p"/s/#{t}") end
      end
    end

    test "the same minimal page is served to signed-in visitors" do
      %{conn: conn} = register_and_log_in_user(%{conn: Phoenix.ConnTest.build_conn()})
      owner = user_fixture()
      run = make_run(owner)
      {:ok, _, token} = Sharing.create_link(owner.id, "run", run.id)

      {:ok, _view, html} = live(conn, ~p"/s/#{token}")
      refute html =~ ~s(id="app-sidebar")
      assert html =~ "Shared from MolBind"
    end
  end

  describe "owner panel on a run" do
    setup :register_and_log_in_user

    test "starts private; creating a link shows its URL once; revoking kills it", %{
      conn: conn,
      user: user
    } do
      run = make_run(user)
      {:ok, view, html} = live(conn, ~p"/history/#{run.id}")
      assert html =~ "Private: no active links"
      assert html =~ "What a link shows to anyone who has it"

      html = view |> form("#share-panel form", %{expiry: "7"}) |> render_submit()
      assert html =~ "shown only once"
      assert html =~ "Shared: 1 active link"
      [_, token] = Regex.run(~r{value="http[^"]*/s/([A-Za-z0-9_-]+)"}, html)

      # The secret is usable...
      assert {:ok, _} = Sharing.resolve(token)

      # ...but is not recoverable from a fresh page load.
      {:ok, view, html} = live(conn, ~p"/history/#{run.id}")
      refute html =~ token
      assert html =~ "Active"

      [link] = Sharing.list_links(user.id, "run", run.id)
      view |> element("#share-link-#{link.id} button", "Revoke") |> render_click()
      html = render(view)
      assert html =~ "Revoked"
      assert Sharing.resolve(token) == {:error, :not_found}
      assert html =~ "Private: no active links"
    end

    test "a forged revoke for another user's link changes nothing", %{conn: conn, user: user} do
      run = make_run(user)
      other = user_fixture()
      other_run = make_run(other)
      {:ok, theirs, token} = Sharing.create_link(other.id, "run", other_run.id)

      {:ok, view, _} = live(conn, ~p"/history/#{run.id}")
      # Even a hand-crafted event straight to the panel cannot touch it.
      html =
        view
        |> with_target("#share-panel")
        |> render_click("revoke", %{"id" => to_string(theirs.id)})

      assert html =~ "That link could not be found."

      assert {:ok, _} = Sharing.resolve(token)
    end

    test "collections get the same panel", %{conn: conn, user: user} do
      {:ok, c} = Collections.create_collection(user.id, %{name: "Mine"})
      {:ok, view, html} = live(conn, ~p"/collections/#{c.id}")
      assert html =~ "Private: no active links"
      html = view |> form("#share-panel form", %{expiry: "never"}) |> render_submit()
      assert html =~ "Shared: 1 active link"
      assert html =~ "never expires"
    end
  end
end
