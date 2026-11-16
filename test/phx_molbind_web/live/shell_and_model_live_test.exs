defmodule PhxMolbindWeb.ShellAndModelLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PhxMolbind.Molecules.Molecules

  describe "application shell" do
    setup :register_and_log_in_user

    test "renders navigation with the active page marked", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/model")
      assert html =~ ~s(id="app-sidebar")
      assert html =~ ~s(aria-current="page")
      assert html =~ "command-palette"
    end

    test "sidebar starts closed on small screens and is toggled client-side", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "-translate-x-full"
      assert html =~ ~s(aria-controls="app-sidebar")
    end
  end

  describe "sign-in page" do
    test "has no application shell", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/auth/sign-in")
      refute html =~ ~s(id="app-sidebar")
    end
  end

  describe "/model" do
    setup :register_and_log_in_user

    test "pre-fills the SMILES field from ?smiles=", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/model?#{%{smiles: "CCO"}}")
      assert html =~ ~s(value="CCO")
    end

    test "validation shows range errors for filled-in fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/model")

      html =
        view
        |> form("#molecule-form", form: %{smiles: "CCO", num_molecules: "500"})
        |> render_change()

      assert html =~ "Number of molecules must be between 1 and 100."
    end

    test "submitting an empty SMILES shows an error and does not start a run", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/model")

      html = view |> form("#molecule-form", form: %{smiles: ""}) |> render_submit()

      assert html =~ "Enter a SMILES string."
      refute html =~ "Waiting for the generation service"
    end

    test "form values survive a failed generation (missing API key in test)", %{conn: conn} do
      Application.put_env(:phx_molbind, :nvidia_api_key, nil)
      {:ok, view, _html} = live(conn, ~p"/model")

      view
      |> form("#molecule-form", form: %{smiles: "CCO", num_molecules: "3"})
      |> render_submit()

      html = render_async(view)

      assert html =~ "NVIDIA_API_KEY is missing"
      assert html =~ ~s(value="CCO")
      assert html =~ ~s(value="3")
    end

    test "viewing a past run shows its candidates; other users' runs are not reachable",
         %{conn: conn, user: user} do
      other = PhxMolbind.AccountsFixtures.user_fixture()

      attrs = fn smiles ->
        %{
          algorithm: "CMA-ES",
          num_molecules: 1,
          property_name: "QED",
          minimize: false,
          min_similarity: 0.5,
          particles: 10,
          iterations: 2,
          smiles: smiles,
          generated_molecules: %{"molecules" => [%{"structure" => "CCN", "score" => 0.42}]}
        }
      end

      {:ok, mine} = Molecules.create_history(attrs.("CCO"), user.id)
      {:ok, theirs} = Molecules.create_history(attrs.("CCC"), other.id)

      {:ok, view, _html} = live(conn, ~p"/model")

      html = render_click(view, "view_molecules", %{"id" => to_string(mine.id)})
      assert html =~ "CCN"
      assert html =~ "0.4200"

      html = render_click(view, "view_molecules", %{"id" => to_string(theirs.id)})
      assert html =~ "That run could not be found."
    end
  end

  describe "Molecules context" do
    test "describe_error/1 never leaks response bodies" do
      {kind, message} = Molecules.describe_error({:unexpected_status, 500, "secret stack trace"})
      assert kind == :service_error
      refute message =~ "secret"
    end

    test "dashboard_summary/1 counts only the given user's saved runs" do
      user = PhxMolbind.AccountsFixtures.user_fixture()
      other = PhxMolbind.AccountsFixtures.user_fixture()

      base = %{
        algorithm: "CMA-ES",
        num_molecules: 2,
        property_name: "QED",
        minimize: false,
        min_similarity: 0.5,
        particles: 10,
        iterations: 2,
        smiles: "CCO"
      }

      {:ok, _} =
        Molecules.create_history(
          Map.put(base, :generated_molecules, %{"molecules" => [%{}, %{}]}),
          user.id
        )

      {:ok, _} = Molecules.create_history(Map.put(base, :generated_molecules, %{}), user.id)

      {:ok, _} =
        Molecules.create_history(
          Map.put(base, :generated_molecules, %{"molecules" => [%{}]}),
          other.id
        )

      assert %{runs: 2, runs_this_week: 2, molecules: 2} = Molecules.dashboard_summary(user.id)
    end
  end
end
