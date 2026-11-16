defmodule PhxMolbindWeb.DashboardLive.Dashboard do
  @moduledoc """
  Dashboard (`/`). Every number comes from the signed-in user's saved
  generation runs; nothing is demo data. Statistics are defined in
  `PhxMolbind.Molecules.Molecules.dashboard_summary/1`.
  """
  use PhxMolbindWeb, :live_view
  alias PhxMolbind.{Accounts, Collections}
  alias PhxMolbind.Molecules.Molecules

  @quick_actions [
    %{
      title: "Generate molecules",
      text: "Start from a SMILES string",
      icon: "hero-beaker",
      to: "/model"
    },
    %{
      title: "Sketch a structure",
      text: "Draw and export a molecule",
      icon: "hero-pencil-square",
      to: "/sketcher"
    },
    %{
      title: "Search compounds",
      text: "Look up PubChem records",
      icon: "hero-magnifying-glass",
      to: "/research"
    },
    %{
      title: "Molecule bank",
      text: "Browse reference molecules",
      icon: "hero-archive-box",
      to: "/molecule-bank"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:quick_actions, @quick_actions)
     |> assign(:summary, Molecules.dashboard_summary(user_id))
     |> assign(:recent, Molecules.recent_history_for_user(user_id, 5))
     |> assign(:saved_items, Collections.count_items(user_id))
     |> assign_onboarding()}
  end

  @impl true
  def handle_event("dismiss_onboarding", _params, socket) do
    save_onboarding(socket, "dismissed")
  end

  def handle_event("restart_onboarding", _params, socket) do
    save_onboarding(socket, "restarted")
  end

  defp save_onboarding(socket, state) do
    case Accounts.set_onboarding(socket.assigns.current_user, state) do
      {:ok, user} ->
        {:noreply, socket |> assign(:current_user, user) |> assign_onboarding()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Your guide preference could not be saved.")}
    end
  end

  defp assign_onboarding(socket) do
    %{current_user: user, summary: summary, saved_items: saved, recent: recent} = socket.assigns

    socket
    |> assign(:show_onboarding, Accounts.show_onboarding?(user, summary.runs))
    |> assign(:onboarding_steps, onboarding_steps(summary.runs, saved, recent))
  end

  # `done` is true/false only where it can be derived from stored data;
  # steps that are just "go and look" stay nil rather than faking progress.
  defp onboarding_steps(runs, saved_items, recent) do
    inspect_target = if recent == [], do: ~p"/history", else: ~p"/history/#{hd(recent).id}"

    [
      %{
        title: "Open or draw a molecule",
        text: "Draw a structure or look one up in PubChem.",
        done: nil,
        links: [{"Sketcher", ~p"/sketcher"}, {"Research", ~p"/research"}]
      },
      %{
        title: "Generate candidate molecules",
        text: "Start from a SMILES string and run the generator.",
        done: runs > 0,
        links: [{"Open the generator", ~p"/model"}]
      },
      %{
        title: "Inspect the results",
        text: "Compare candidates and their model-reported scores.",
        done: nil,
        links: [{"Open a run", inspect_target}]
      },
      %{
        title: "Save a candidate",
        text: "Keep promising molecules in a collection and review them.",
        done: saved_items > 0,
        links: [{"Collections", ~p"/collections"}]
      },
      %{
        title: "Explore properties",
        text: "Browse formulas, weights and stereochemistry in the Molecule Bank.",
        done: nil,
        links: [{"Molecule Bank", ~p"/molecule-bank"}]
      }
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@show_onboarding}
      id="onboarding"
      aria-labelledby="onboarding-heading"
      class="mb-8 rounded-lg border border-primary/40 bg-primary/5 p-5"
    >
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 id="onboarding-heading" class="font-medium text-black dark:text-white">
            Getting started
          </h2>
          <p class="text-sm text-body dark:text-bodydark">
            Five steps from a starting molecule to its properties. "Done" appears only where MolBind can tell from your saved work.
          </p>
        </div>
        <button
          type="button"
          phx-click="dismiss_onboarding"
          class="rounded border border-stroke px-3 py-1 text-sm hover:bg-white/50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary dark:border-strokedark dark:text-white dark:hover:bg-white/5"
        >
          Dismiss guide
        </button>
      </div>
      <ol class="mt-4 space-y-3 text-sm">
        <li
          :for={{step, index} <- Enum.with_index(@onboarding_steps, 1)}
          id={"onboarding-step-#{index}"}
          class="flex flex-wrap items-baseline gap-x-2"
        >
          <span class="font-medium text-black dark:text-white">{index}. {step.title}</span>
          <span
            :if={step.done == true}
            class="rounded bg-green-100 px-2 py-0.5 text-xs text-green-800 dark:bg-green-900 dark:text-green-100"
          >
            Done
          </span>
          <span class="text-body dark:text-bodydark">{step.text}</span>
          <span class="flex gap-3">
            <.link
              :for={{label, to} <- step.links}
              navigate={to}
              class="text-accent dark:text-accent-light hover:underline"
            >
              {label}
            </.link>
          </span>
        </li>
      </ol>
    </section>

    <p :if={!@show_onboarding} class="mb-4 text-right text-sm">
      <button
        type="button"
        phx-click="restart_onboarding"
        class="text-accent dark:text-accent-light hover:underline"
      >
        Show the getting-started guide
      </button>
    </p>

    <section aria-labelledby="quick-actions-heading">
      <h2 id="quick-actions-heading" class="sr-only">Quick actions</h2>
      <ul class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <li :for={action <- @quick_actions}>
          <.link
            navigate={action.to}
            class="flex h-full items-start gap-4 rounded-lg border border-stroke bg-white p-5 shadow-sm hover:border-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary dark:border-strokedark dark:bg-[#181818]"
          >
            <span class="flex size-11 shrink-0 items-center justify-center rounded-full bg-primary/10">
              <.icon name={action.icon} class="size-5 text-accent dark:text-accent-light" />
            </span>
            <span>
              <span class="block font-semibold text-black dark:text-white">{action.title}</span>
              <span class="block text-sm text-body dark:text-bodydark">{action.text}</span>
            </span>
          </.link>
        </li>
      </ul>
    </section>

    <section :if={@summary.runs > 0} class="mt-8" aria-labelledby="stats-heading">
      <h2 id="stats-heading" class="font-medium text-black dark:text-white">Your activity</h2>
      <dl class="mt-3 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div class="rounded-lg border border-stroke bg-white p-5 dark:border-strokedark dark:bg-[#181818]">
          <dt class="text-sm text-body dark:text-bodydark">Saved runs</dt>
          <dd class="mt-1 text-2xl font-semibold text-black dark:text-white">{@summary.runs}</dd>
        </div>
        <div class="rounded-lg border border-stroke bg-white p-5 dark:border-strokedark dark:bg-[#181818]">
          <dt class="text-sm text-body dark:text-bodydark">Runs in the last 7 days</dt>
          <dd class="mt-1 text-2xl font-semibold text-black dark:text-white">
            {@summary.runs_this_week}
          </dd>
        </div>
        <div class="rounded-lg border border-stroke bg-white p-5 dark:border-strokedark dark:bg-[#181818]">
          <dt class="text-sm text-body dark:text-bodydark">Candidates generated</dt>
          <dd class="mt-1 text-2xl font-semibold text-black dark:text-white">{@summary.molecules}</dd>
        </div>
      </dl>
      <p class="mt-2 text-xs text-body dark:text-bodydark">
        Counts include only successfully completed, saved runs.
      </p>
    </section>

    <section class="mt-8" aria-labelledby="recent-heading">
      <h2 id="recent-heading" class="font-medium text-black dark:text-white">Recent runs</h2>

      <div
        :if={@recent == []}
        class="mt-3 rounded-lg border border-dashed border-stroke p-6 text-sm text-body dark:border-strokedark dark:text-bodydark"
      >
        <p class="font-medium text-black dark:text-white">Nothing here yet.</p>
        <p class="mt-1">
          Open the generator, enter a SMILES string (or draw one in the sketcher), and generate candidate molecules. Your runs will be listed here.
        </p>
        <.link
          navigate={~p"/model"}
          class="mt-3 inline-block text-accent dark:text-accent-light hover:underline"
        >
          Start your first run
        </.link>
      </div>

      <ul
        :if={@recent != []}
        class="mt-3 divide-y divide-stroke rounded-lg border border-stroke bg-white dark:divide-strokedark dark:border-strokedark dark:bg-[#181818]"
      >
        <li :for={run <- @recent} class="flex flex-wrap items-center justify-between gap-2 p-4">
          <div class="min-w-0">
            <p class="break-all font-mono text-sm text-black dark:text-white">{run.smiles}</p>
            <p class="text-xs text-body dark:text-bodydark">
              {run.algorithm} · {run.property_name} · {run.num_molecules} requested · {Calendar.strftime(
                run.inserted_at,
                "%Y-%m-%d %H:%M"
              )}
            </p>
          </div>
          <.link
            navigate={~p"/model?#{%{smiles: run.smiles}}"}
            class="text-sm text-accent dark:text-accent-light hover:underline"
          >
            Use as starting molecule
          </.link>
        </li>
      </ul>
    </section>
    """
  end
end
