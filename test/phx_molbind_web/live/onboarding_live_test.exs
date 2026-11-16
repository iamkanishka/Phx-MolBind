defmodule PhxMolbindWeb.OnboardingLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PhxMolbind.{Accounts, Collections}
  alias PhxMolbind.Molecules.Molecules

  setup :register_and_log_in_user

  defp save_run(user) do
    {:ok, run} =
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

    run
  end

  test "a new user sees the five-step guide with nothing falsely marked done", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ ~s(id="onboarding")
    for i <- 1..5, do: assert(html =~ ~s(id="onboarding-step-#{i}"))
    refute html =~ ">\n            Done\n"
    refute html =~ ~r/>\s*Done\s*</
  end

  test "returning users with saved runs are not nagged", %{conn: conn, user: user} do
    save_run(user)
    {:ok, _view, html} = live(conn, ~p"/")
    refute html =~ ~s(id="onboarding")
    assert html =~ "Show the getting-started guide"
  end

  test "dismissing persists across visits", %{conn: conn, user: user} do
    {:ok, view, _} = live(conn, ~p"/")
    html = render_click(view, "dismiss_onboarding", %{})
    refute html =~ ~s(id="onboarding")

    assert Accounts.onboarding_state(Accounts.get_user(user.id)) == "dismissed"
    {:ok, _view, html} = live(conn, ~p"/")
    refute html =~ ~s(id="onboarding")
  end

  test "restarting shows the guide even for users with runs, and marks real progress", %{
    conn: conn,
    user: user
  } do
    run = save_run(user)
    {:ok, c} = Collections.create_collection(user.id, %{name: "Picks"})
    {:ok, _} = Collections.add_item(user.id, c.id, %{smiles: "CCN"})

    {:ok, view, _} = live(conn, ~p"/")
    html = render_click(view, "restart_onboarding", %{})
    assert html =~ ~s(id="onboarding")
    assert Accounts.onboarding_state(Accounts.get_user(user.id)) == "restarted"

    # Steps 2 (generated) and 4 (saved) are detectable; the others are not.
    assert length(Regex.scan(~r/>\s*Done\s*</, html)) == 2
    assert html =~ "/history/#{run.id}"
  end
end
