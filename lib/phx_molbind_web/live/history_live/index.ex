defmodule PhxMolbindWeb.HistoryLive.Index do
  @moduledoc "Browse, search, sort, paginate and delete saved generation runs (`/history`)."
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Molecules.Molecules

  @sorts ~w(newest oldest most_candidates)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "History")
     |> assign(:confirm_id, nil)
     |> assign(:compare_ids, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    search = params |> Map.get("q", "") |> to_string() |> String.slice(0, 200)
    sort = if params["sort"] in @sorts, do: params["sort"], else: "newest"

    sort_atom =
      case sort do
        "oldest" -> :oldest
        "most_candidates" -> :most_candidates
        _ -> :newest
      end

    page = parse_page(params["page"])

    result =
      Molecules.list_history(socket.assigns.current_user.id,
        search: search,
        sort: sort_atom,
        page: page
      )

    {:noreply,
     socket
     |> assign(:q, search)
     |> assign(:sort, sort)
     |> assign(:result, result)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl">
      <form
        phx-change="filter"
        phx-submit="filter"
        class="mb-4 flex flex-wrap items-end gap-3"
        role="search"
      >
        <div class="grow">
          <label for="history-q" class="text-sm text-body dark:text-bodydark">
            Search starting SMILES
          </label>
          <input
            id="history-q"
            type="search"
            name="q"
            value={@q}
            phx-debounce="300"
            autocomplete="off"
            class="mt-1 w-full rounded-lg border border-stroke bg-white px-3 py-2 dark:border-strokedark dark:bg-boxdark"
          />
        </div>
        <div>
          <label for="history-sort" class="text-sm text-body dark:text-bodydark">Sort</label>
          <select
            id="history-sort"
            name="sort"
            class="mt-1 rounded-lg border border-stroke bg-white px-3 py-2 dark:border-strokedark dark:bg-boxdark"
          >
            <option value="newest" selected={@sort == "newest"}>Newest first</option>
            <option value="oldest" selected={@sort == "oldest"}>Oldest first</option>
            <option value="most_candidates" selected={@sort == "most_candidates"}>
              Most candidates requested
            </option>
          </select>
        </div>
      </form>

      <p class="mb-3 text-sm text-body dark:text-bodydark" aria-live="polite">
        {@result.total} {if @result.total == 1, do: "run", else: "runs"}
      </p>

      <div
        :if={@result.total == 0 and @q == ""}
        class="rounded-lg border border-dashed border-stroke p-6 text-sm text-body dark:border-strokedark dark:text-bodydark"
      >
        <p class="font-medium text-black dark:text-white">No saved runs yet.</p>
        <p class="mt-1">Runs are saved automatically after a successful generation.</p>
        <.link
          navigate={~p"/model"}
          class="mt-3 inline-block text-accent dark:text-accent-light hover:underline"
        >
          Open the generator
        </.link>
      </div>

      <p
        :if={@result.total == 0 and @q != ""}
        class="rounded-lg border border-dashed border-stroke p-6 text-sm text-body dark:border-strokedark dark:text-bodydark"
      >
        No runs match “{@q}”.
        <.link patch={~p"/history"} class="text-accent dark:text-accent-light underline">
          Clear search
        </.link>
      </p>

      <div
        :if={@compare_ids != []}
        class="mb-3 flex flex-wrap items-center gap-3 text-sm"
        role="status"
      >
        <span>{length(@compare_ids)} of 2 runs selected.</span>
        <.link
          :if={length(@compare_ids) == 2}
          navigate={
            ~p"/history/compare?#{%{a: Enum.at(@compare_ids, 0), b: Enum.at(@compare_ids, 1)}}"
          }
          class="rounded-lg bg-accent px-3 py-1 text-white hover:bg-accent-hover"
        >
          Compare selected runs
        </.link>
        <button
          type="button"
          phx-click="clear_compare"
          class="text-accent dark:text-accent-light hover:underline"
        >
          Clear
        </button>
      </div>

      <ul class="divide-y divide-stroke rounded-lg border border-stroke bg-white dark:divide-strokedark dark:border-strokedark dark:bg-[#181818]">
        <li :for={run <- @result.entries} id={"run-#{run.id}"} class="p-4">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <label class="mt-1 flex shrink-0 items-center gap-2 text-xs text-body dark:text-bodydark">
              <input
                type="checkbox"
                phx-click="toggle_compare"
                phx-value-id={run.id}
                checked={run.id in @compare_ids}
                aria-label={"Select run #{run.id} for comparison"}
              /> Compare
            </label>
            <div class="min-w-0 grow">
              <p class="break-all font-mono text-sm text-black dark:text-white">{run.smiles}</p>
              <p class="mt-1 text-xs text-body dark:text-bodydark">
                {run.algorithm} · {run.property_name} · {run.num_molecules} requested · {length(
                  Molecules.candidates(run)
                )} returned · {Calendar.strftime(run.inserted_at, "%Y-%m-%d %H:%M")}
              </p>
            </div>
            <div class="flex items-center gap-3 text-sm">
              <.link
                navigate={~p"/history/#{run.id}"}
                class="text-accent dark:text-accent-light hover:underline"
              >
                Open
              </.link>
              <button
                :if={@confirm_id != run.id}
                type="button"
                phx-click="ask_delete"
                phx-value-id={run.id}
                class="text-red-600 hover:underline dark:text-red-400"
              >
                Delete
              </button>
            </div>
          </div>
          <div
            :if={@confirm_id == run.id}
            class="mt-3 flex flex-wrap items-center gap-3 rounded-md bg-red-50 p-3 text-sm dark:bg-red-950/30"
            role="alert"
          >
            <span>Delete this run permanently? Candidates saved to collections are kept.</span>
            <button
              type="button"
              phx-click="delete"
              phx-value-id={run.id}
              class="rounded bg-red-600 px-3 py-1 text-white"
            >
              Delete run
            </button>
            <button
              type="button"
              phx-click="cancel_delete"
              class="rounded border border-stroke px-3 py-1 dark:border-strokedark"
            >
              Cancel
            </button>
          </div>
        </li>
      </ul>

      <nav
        :if={@result.pages > 1}
        class="mt-4 flex items-center justify-between text-sm"
        aria-label="Pagination"
      >
        <.link
          :if={@result.page > 1}
          patch={page_path(@q, @sort, @result.page - 1)}
          class="text-accent dark:text-accent-light hover:underline"
        >
          ← Previous
        </.link>
        <span :if={@result.page == 1}></span>
        <span class="text-body dark:text-bodydark">Page {@result.page} of {@result.pages}</span>
        <.link
          :if={@result.page < @result.pages}
          patch={page_path(@q, @sort, @result.page + 1)}
          class="text-accent dark:text-accent-light hover:underline"
        >
          Next →
        </.link>
        <span :if={@result.page == @result.pages}></span>
      </nav>
    </div>
    """
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     push_patch(socket,
       to: page_path(Map.get(params, "q", ""), Map.get(params, "sort", "newest"), 1)
     )}
  end

  def handle_event("toggle_compare", %{"id" => id}, socket) do
    visible_ids = Enum.map(socket.assigns.result.entries, & &1.id)

    with {int, ""} <- Integer.parse(id),
         true <- int in visible_ids or int in socket.assigns.compare_ids do
      selected = socket.assigns.compare_ids

      selected =
        cond do
          int in selected -> List.delete(selected, int)
          # A third pick replaces the oldest one so exactly two stay selected.
          length(selected) >= 2 -> tl(selected) ++ [int]
          true -> selected ++ [int]
        end

      {:noreply, assign(socket, :compare_ids, selected)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("clear_compare", _params, socket),
    do: {:noreply, assign(socket, :compare_ids, [])}

  def handle_event("ask_delete", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {int, ""} -> {:noreply, assign(socket, :confirm_id, int)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("cancel_delete", _params, socket),
    do: {:noreply, assign(socket, :confirm_id, nil)}

  def handle_event("delete", %{"id" => id}, socket) do
    with {int, ""} <- Integer.parse(id),
         {:ok, _} <- Molecules.delete_history_entry(socket.assigns.current_user.id, int) do
      {:noreply,
       socket
       |> assign(:confirm_id, nil)
       |> assign(:compare_ids, List.delete(socket.assigns.compare_ids, int))
       |> put_flash(:info, "Run deleted.")
       |> push_patch(
         to: page_path(socket.assigns.q, socket.assigns.sort, socket.assigns.result.page)
       )}
    else
      _ ->
        {:noreply,
         socket |> assign(:confirm_id, nil) |> put_flash(:error, "That run could not be found.")}
    end
  end

  defp parse_page(value) do
    case Integer.parse(to_string(value)) do
      {n, ""} when n > 0 -> n
      _ -> 1
    end
  end

  defp page_path(q, sort, page) do
    params =
      [{"q", q}, {"sort", sort}, {"page", page}]
      |> Enum.reject(fn {k, v} ->
        (k == "q" and v in [nil, ""]) or (k == "sort" and v == "newest") or
          (k == "page" and v == 1)
      end)

    if params == [], do: ~p"/history", else: ~p"/history?#{params}"
  end
end
