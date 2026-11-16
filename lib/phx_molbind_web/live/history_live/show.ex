defmodule PhxMolbindWeb.HistoryLive.Show do
  @moduledoc """
  Detail view of one saved run (`/history/:id`). Opening it never re-runs the
  generation: everything shown comes from the stored record. Scores are the
  values the MolMIM service reported for the run's property (model output,
  not experimental measurement).
  """
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.{Collections, Molecules.Molecules}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user_id = socket.assigns.current_user.id

    with {int_id, ""} <- Integer.parse(id),
         %{} = run <- Molecules.get_history_entry(user_id, int_id) do
      {:ok,
       socket
       |> assign(:page_title, "Run #{run.id}")
       |> assign(:run, run)
       |> assign(:candidates, Molecules.candidates(run))
       |> assign(:collections, Collections.list_collections(user_id))
       |> assign(:lineage, PhxMolbind.Molecules.Lineage.build(user_id, run))
       |> assign(:confirm_delete, false)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That run could not be found.")
         |> push_navigate(to: ~p"/history")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl">
      <.link
        navigate={~p"/history"}
        class="text-sm text-accent dark:text-accent-light hover:underline"
      >
        ← All runs
      </.link>

      <section
        class="mt-3 rounded-lg border border-stroke bg-white p-5 dark:border-strokedark dark:bg-[#181818]"
        aria-labelledby="run-heading"
      >
        <h2 id="run-heading" class="font-medium text-black dark:text-white">Run {@run.id}</h2>
        <p class="mt-1 text-xs text-body dark:text-bodydark">
          Saved {Calendar.strftime(@run.inserted_at, "%Y-%m-%d %H:%M")} UTC · completed
        </p>
        <dl class="mt-4 grid grid-cols-1 gap-3 text-sm sm:grid-cols-2">
          <div class="sm:col-span-2">
            <dt class="font-medium text-black dark:text-white">Starting molecule</dt>
            <dd class="break-all font-mono text-body dark:text-bodydark">{@run.smiles}</dd>
          </div>
          <div :for={{label, value} <- parameters(@run)}>
            <dt class="font-medium text-black dark:text-white">{label}</dt>
            <dd class="text-body dark:text-bodydark">{value}</dd>
          </div>
        </dl>

        <div class="mt-5 flex flex-wrap items-center gap-3 text-sm">
          <.link
            navigate={rerun_path(@run)}
            class="rounded-lg bg-accent px-4 py-2 text-white hover:bg-accent-hover"
          >
            Re-run with these settings
          </.link>
          <.link
            href={~p"/history/#{@run.id}/export.csv"}
            class="rounded-lg border border-stroke px-4 py-2 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
          >
            Export candidates (CSV)
          </.link>
          <button
            :if={!@confirm_delete}
            type="button"
            phx-click="ask_delete"
            class="text-red-600 hover:underline dark:text-red-400"
          >
            Delete run
          </button>
        </div>

        <div
          :if={@confirm_delete}
          class="mt-3 flex flex-wrap items-center gap-3 rounded-md bg-red-50 p-3 text-sm dark:bg-red-950/30"
          role="alert"
        >
          <span>Delete this run permanently? Candidates saved to collections are kept.</span>
          <button type="button" phx-click="delete" class="rounded bg-red-600 px-3 py-1 text-white">
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
      </section>

      <.live_component
        module={PhxMolbindWeb.ShareLive.Panel}
        id="share-panel"
        kind="run"
        target_id={@run.id}
        user_id={@current_user.id}
      />

      <section class="mt-6" aria-labelledby="lineage-heading">
        <h2 id="lineage-heading" class="font-medium text-black dark:text-white">Lineage</h2>
        <p class="mt-1 text-xs text-body dark:text-bodydark">
          Only relationships MolBind recorded are shown as lineage: a run counts as derived from another when you started it with "Use as starting molecule" from that run's candidate (or a molecule saved from it).
        </p>

        <p :if={!@lineage.has_recorded_lineage?} class="mt-3 text-sm text-body dark:text-bodydark">
          No recorded lineage for this run yet.
        </p>

        <ol
          :if={@lineage.has_recorded_lineage?}
          class="mt-3 space-y-1 text-sm"
          aria-label="Lineage tree"
        >
          <li
            :for={{ancestor, depth} <- Enum.with_index(@lineage.ancestors)}
            style={"margin-left: #{depth * 1.25}rem"}
          >
            <span class="text-body dark:text-bodydark">Derived from</span>
            <.link
              navigate={~p"/history/#{ancestor.id}"}
              class="text-accent underline dark:text-accent-light"
            >
              run {ancestor.id}
            </.link>
            <span class="break-all font-mono text-xs">{ancestor.smiles}</span>
          </li>
          <li style={"margin-left: #{length(@lineage.ancestors) * 1.25}rem"} aria-current="true">
            <strong class="text-black dark:text-white">This run ({@run.id})</strong>
            <span :if={@run.parent_candidate_index} class="text-xs text-body dark:text-bodydark">
              — started from candidate {@run.parent_candidate_index + 1} of run {@run.parent_run_id}
            </span>
          </li>
          <.saved_items
            items={Map.get(@lineage.saved, @run.id, [])}
            indent={length(@lineage.ancestors) + 1}
          />
          <.lineage_children
            nodes={@lineage.descendants}
            depth={length(@lineage.ancestors) + 1}
            saved={@lineage.saved}
          />
        </ol>

        <p :if={@lineage.truncated?} class="mt-2 text-xs text-body dark:text-bodydark">
          The tree is cut off at its size limit; open a descendant run to see further.
        </p>

        <div :if={@lineage.same_start != []} class="mt-4">
          <h3 class="text-sm font-medium text-black dark:text-white">
            Other runs with the same starting SMILES (not verified as related)
          </h3>
          <ul class="mt-1 text-sm">
            <li :for={other <- @lineage.same_start}>
              <.link
                navigate={~p"/history/#{other.id}"}
                class="text-accent underline dark:text-accent-light"
              >
                run {other.id}
              </.link>
              <span class="text-xs text-body dark:text-bodydark">
                {Calendar.strftime(other.inserted_at, "%Y-%m-%d %H:%M")}
              </span>
            </li>
          </ul>
        </div>
      </section>

      <section class="mt-6" aria-labelledby="cand-heading">
        <h2 id="cand-heading" class="font-medium text-black dark:text-white">
          Candidates ({length(@candidates)} returned, {@run.num_molecules} requested)
        </h2>
        <p :if={@candidates == []} class="mt-3 text-sm text-body dark:text-bodydark">
          The service returned no candidates for this run.
        </p>

        <ul class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <li
            :for={c <- @candidates}
            id={"run-candidate-#{c.index}"}
            class="rounded-lg border border-stroke bg-white p-3 dark:border-strokedark dark:bg-[#181818]"
          >
            <p class="text-sm font-medium text-black dark:text-white">Candidate {c.index + 1}</p>
            <.structure_viewer
              id={"run-viewer-#{c.index}"}
              canvas_id={"run-canvas-#{c.index}"}
              smiles={c.structure}
              size={260}
              export={false}
              label={"candidate #{c.index + 1}: #{c.structure}"}
            />
            <p class="mt-2 break-all font-mono text-xs text-black dark:text-white">{c.structure}</p>
            <p class="mt-1 text-sm text-black dark:text-white">
              {@run.property_name} score: <span class="font-mono">{format_score(c.score)}</span>
            </p>
            <div class="mt-3 flex flex-wrap items-center gap-2 text-sm">
              <button
                id={"run-copy-#{c.index}"}
                type="button"
                phx-hook="CopyButton"
                data-copy={c.structure}
                class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
              >
                Copy SMILES
              </button>
              <button
                id={"run-png-#{c.index}"}
                type="button"
                phx-hook="DownloadCanvas"
                data-canvas-id={"run-canvas-#{c.index}"}
                data-filename={"molbind-run-#{@run.id}-candidate-#{c.index + 1}.png"}
                class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
              >
                Download PNG
              </button>
              <.link
                navigate={~p"/model?#{%{smiles: c.structure, from_run: @run.id}}"}
                class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
              >
                Use as starting molecule
              </.link>
              <button
                type="button"
                phx-click="share_candidate"
                phx-value-index={c.index}
                class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
              >
                Share to chat
              </button>
            </div>
            <form
              :if={@collections != []}
              phx-submit="save_candidate"
              class="mt-3 flex items-center gap-2 text-sm"
            >
              <input type="hidden" name="index" value={c.index} />
              <label for={"save-to-#{c.index}"} class="sr-only">
                Save candidate {c.index + 1} to collection
              </label>
              <select
                id={"save-to-#{c.index}"}
                name="collection_id"
                class="min-w-0 grow rounded border border-stroke bg-white px-2 py-1 dark:border-strokedark dark:bg-boxdark"
              >
                <option :for={col <- @collections} value={col.id}>{col.name}</option>
              </select>
              <button
                type="submit"
                class="rounded border border-primary px-2 py-1 text-accent dark:text-accent-light hover:bg-primary/10"
              >
                Save
              </button>
            </form>
          </li>
        </ul>

        <p
          :if={@collections == [] and @candidates != []}
          class="mt-4 text-sm text-body dark:text-bodydark"
        >
          Create a
          <.link navigate={~p"/collections"} class="text-accent dark:text-accent-light underline">
            collection
          </.link>
          to save candidates from this run.
        </p>
      </section>
    </div>
    """
  end

  @impl true
  def handle_event(
        "save_candidate",
        %{"index" => index, "collection_id" => collection_id},
        socket
      ) do
    user_id = socket.assigns.current_user.id

    # The candidate is looked up server-side by index: the client never
    # supplies the SMILES or score that gets stored.
    with {i, ""} <- Integer.parse(index),
         {cid, ""} <- Integer.parse(collection_id),
         %{} = candidate <- Enum.find(socket.assigns.candidates, &(&1.index == i)) do
      attrs = %{
        smiles: candidate.structure,
        score: if(is_number(candidate.score), do: candidate.score * 1.0),
        property_name: socket.assigns.run.property_name,
        source_run_id: socket.assigns.run.id
      }

      case Collections.add_item(user_id, cid, attrs) do
        {:ok, _item} ->
          {:noreply, put_flash(socket, :info, "Candidate #{i + 1} saved.")}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "That collection could not be found.")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, put_flash(socket, :error, "Could not save: " <> first_error(changeset))}
      end
    else
      _ -> {:noreply, put_flash(socket, :error, "Could not save that candidate.")}
    end
  end

  def handle_event("share_candidate", %{"index" => index}, socket) do
    # The structure comes from this (owned) run, never from the client.
    with {i, ""} <- Integer.parse(index),
         %{} = candidate <- Enum.find(socket.assigns.candidates, &(&1.index == i)),
         {:ok, _message} <-
           PhxMolbind.Messages.share_molecule(
             socket.assigns.current_user.id,
             candidate.structure,
             "Candidate #{i + 1} from run #{socket.assigns.run.id}"
           ) do
      {:noreply, put_flash(socket, :info, "Shared to the chat lobby.")}
    else
      _ -> {:noreply, put_flash(socket, :error, "That candidate could not be shared.")}
    end
  end

  def handle_event("ask_delete", _params, socket),
    do: {:noreply, assign(socket, :confirm_delete, true)}

  def handle_event("cancel_delete", _params, socket),
    do: {:noreply, assign(socket, :confirm_delete, false)}

  def handle_event("delete", _params, socket) do
    case Molecules.delete_history_entry(socket.assigns.current_user.id, socket.assigns.run.id) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Run deleted.") |> push_navigate(to: ~p"/history")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "That run could not be found.")}
    end
  end

  attr :nodes, :list, required: true
  attr :depth, :integer, required: true
  attr :saved, :map, required: true

  defp lineage_children(assigns) do
    ~H"""
    <%= for %{run: child, children: grandchildren} <- @nodes do %>
      <li style={"margin-left: #{@depth * 1.25}rem"}>
        <span class="text-body dark:text-bodydark">Led to</span>
        <.link
          navigate={~p"/history/#{child.id}"}
          class="text-accent underline dark:text-accent-light"
        >
          run {child.id}
        </.link>
        <span class="text-xs text-body dark:text-bodydark">
          (candidate {child.parent_candidate_index + 1}) starting
          <span class="break-all font-mono">{child.smiles}</span>
        </span>
      </li>
      <.saved_items items={Map.get(@saved, child.id, [])} indent={@depth + 1} />
      <.lineage_children nodes={grandchildren} depth={@depth + 1} saved={@saved} />
    <% end %>
    """
  end

  attr :items, :list, required: true
  attr :indent, :integer, required: true

  defp saved_items(assigns) do
    ~H"""
    <li
      :for={{item, collection} <- @items}
      style={"margin-left: #{@indent * 1.25}rem"}
      class="text-xs"
    >
      <span class="text-body dark:text-bodydark">Saved</span>
      <span class="break-all font-mono">{item.smiles}</span>
      <span class="text-body dark:text-bodydark">to</span>
      <.link
        navigate={~p"/collections/#{collection.id}"}
        class="text-accent underline dark:text-accent-light"
      >
        {collection.name}
      </.link>
    </li>
    """
  end

  defp parameters(run) do
    [
      {"Algorithm", run.algorithm},
      {"Property", run.property_name},
      {"Objective", if(run.minimize, do: "Minimise", else: "Maximise")},
      {"Molecules requested", run.num_molecules},
      {"Minimum similarity", run.min_similarity},
      {"Particles", run.particles},
      {"Iterations", run.iterations}
    ]
  end

  defp rerun_path(run) do
    ~p"/model?#{%{smiles: run.smiles, algorithm: run.algorithm, property_name: run.property_name, minimize: run.minimize, num_molecules: run.num_molecules, min_similarity: run.min_similarity, particles: run.particles, iterations: run.iterations}}"
  end

  defp format_score(score) when is_number(score),
    do: :erlang.float_to_binary(score * 1.0, decimals: 4)

  defp format_score(_), do: "not reported"

  defp first_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.flat_map(fn {field, msgs} -> Enum.map(msgs, &"#{field} #{&1}") end)
    |> List.first("invalid data")
  end
end
