defmodule PhxMolbindWeb.CollectionsLive.Show do
  @moduledoc """
  One collection: saved candidates with review statuses, rename, remove and
  CSV export (`/collections/:id`, optional `?status=` filter).

  Review statuses are the user's own triage labels. They are shown as text,
  not colour alone.
  """
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Collections

  @status_labels %{
    unreviewed: "Unreviewed",
    shortlisted: "Shortlisted",
    rejected: "Rejected",
    needs_inspection: "Needs further inspection"
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user_id = socket.assigns.current_user.id

    with {int_id, ""} <- Integer.parse(id),
         %{} = collection <- Collections.get_collection(user_id, int_id) do
      {:ok,
       socket
       |> assign(:page_title, collection.name)
       |> assign(:collection, collection)
       |> assign(:status_filter, nil)
       |> assign(:form, to_form(%{"name" => collection.name}, as: :collection))}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That collection could not be found.")
         |> push_navigate(to: ~p"/collections")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter =
      case Collections.cast_status(params["status"]) do
        {:ok, status} -> status
        _ -> nil
      end

    {:noreply, socket |> assign(:status_filter, filter) |> load_items()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl">
      <.link
        navigate={~p"/collections"}
        class="text-sm text-accent dark:text-accent-light hover:underline"
      >
        ← All collections
      </.link>

      <section class="mt-3 rounded-lg border border-stroke bg-white p-5 dark:border-strokedark dark:bg-[#181818]">
        <h2 class="font-medium text-black dark:text-white">{@collection.name}</h2>
        <.simple_form for={@form} id="rename-form" phx-submit="rename">
          <.input field={@form[:name]} type="text" label="Rename" maxlength="80" />
          <:actions>
            <.button type="submit">Save name</.button>
          </:actions>
        </.simple_form>
        <.link
          :if={@total > 0}
          href={~p"/collections/#{@collection.id}/export.csv"}
          class="mt-3 inline-block rounded-lg border border-stroke px-4 py-2 text-sm hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
        >
          Export all (CSV)
        </.link>
      </section>

      <.live_component
        module={PhxMolbindWeb.ShareLive.Panel}
        id="share-panel"
        kind="collection"
        target_id={@collection.id}
        user_id={@current_user.id}
      />

      <nav
        :if={@total > 0}
        class="mt-6 flex flex-wrap gap-2 text-sm"
        aria-label="Filter by review status"
      >
        <.link
          patch={~p"/collections/#{@collection.id}"}
          aria-current={if is_nil(@status_filter), do: "true"}
          class={filter_class(is_nil(@status_filter))}
        >
          All ({@total})
        </.link>
        <.link
          :for={status <- Collections.review_statuses()}
          patch={~p"/collections/#{@collection.id}?#{%{status: status}}"}
          aria-current={if @status_filter == status, do: "true"}
          class={filter_class(@status_filter == status)}
        >
          {status_label(status)} ({Map.get(@counts, status, 0)})
        </.link>
      </nav>

      <p
        :if={@total == 0}
        class="mt-6 rounded-lg border border-dashed border-stroke p-6 text-sm text-body dark:border-strokedark dark:text-bodydark"
      >
        Nothing saved yet. Open a run in your
        <.link navigate={~p"/history"} class="text-accent dark:text-accent-light underline">
          history
        </.link>
        and save candidates here.
      </p>

      <p :if={@total > 0 and @items == []} class="mt-6 text-sm text-body dark:text-bodydark">
        No molecules with this status.
      </p>

      <ul class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <li
          :for={item <- @items}
          id={"item-#{item.id}"}
          class="rounded-lg border border-stroke bg-white p-3 dark:border-strokedark dark:bg-[#181818]"
        >
          <.structure_viewer
            id={"item-viewer-#{item.id}"}
            canvas_id={"item-canvas-#{item.id}"}
            smiles={item.smiles}
            size={240}
            export={false}
            label={"saved molecule: #{item.smiles}"}
          />
          <p class="mt-2 break-all font-mono text-xs text-black dark:text-white">{item.smiles}</p>
          <p class="mt-1 text-xs text-body dark:text-bodydark">
            <%= if item.score do %>
              {item.property_name} score (model output):
              <span class="font-mono">{:erlang.float_to_binary(item.score, decimals: 4)}</span>
            <% else %>
              No score recorded
            <% end %>
          </p>

          <form phx-change="set_status" class="mt-2">
            <input type="hidden" name="item_id" value={item.id} />
            <label for={"status-#{item.id}"} class="text-xs text-body dark:text-bodydark">
              Review status
            </label>
            <select
              id={"status-#{item.id}"}
              name="status"
              class="mt-1 w-full rounded border border-stroke bg-white px-2 py-1 text-sm dark:border-strokedark dark:bg-boxdark"
            >
              <option
                :for={status <- Collections.review_statuses()}
                value={status}
                selected={item.review_status == status}
              >
                {status_label(status)}
              </option>
            </select>
          </form>

          <div class="mt-3 flex flex-wrap gap-2 text-sm">
            <button
              id={"item-copy-#{item.id}"}
              type="button"
              phx-hook="CopyButton"
              data-copy={item.smiles}
              class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
            >
              Copy SMILES
            </button>
            <.link
              navigate={~p"/model?#{lineage_params(item)}"}
              class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
            >
              Use as starting molecule
            </.link>
            <button
              type="button"
              phx-click="share_item"
              phx-value-id={item.id}
              class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
            >
              Share to chat
            </button>
            <button
              type="button"
              phx-click="remove"
              phx-value-id={item.id}
              class="rounded border border-stroke px-2 py-1 text-red-600 hover:bg-gray-2 dark:border-strokedark dark:text-red-400 dark:hover:bg-white/5"
            >
              Remove
            </button>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  @impl true
  def handle_event("set_status", %{"item_id" => id, "status" => status}, socket) do
    with {int, ""} <- Integer.parse(id),
         {:ok, _item} <-
           Collections.set_review_status(socket.assigns.current_user.id, int, status) do
      {:noreply, load_items(socket)}
    else
      _ -> {:noreply, put_flash(socket, :error, "That status could not be saved.")}
    end
  end

  def handle_event("share_item", %{"id" => id}, socket) do
    # Looked up in this collection's server-loaded items: ownership is implied.
    with {int, ""} <- Integer.parse(id),
         %{} = item <- Enum.find(socket.assigns.items, &(&1.id == int)),
         {:ok, _message} <-
           PhxMolbind.Messages.share_molecule(
             socket.assigns.current_user.id,
             item.smiles,
             "From collection “#{socket.assigns.collection.name}”"
           ) do
      {:noreply, put_flash(socket, :info, "Shared to the chat lobby.")}
    else
      _ -> {:noreply, put_flash(socket, :error, "That molecule could not be shared.")}
    end
  end

  def handle_event("rename", %{"collection" => %{"name" => name}}, socket) do
    case Collections.rename_collection(
           socket.assigns.current_user.id,
           socket.assigns.collection.id,
           name
         ) do
      {:ok, collection} ->
        {:noreply,
         socket
         |> assign(:collection, collection)
         |> assign(:page_title, collection.name)
         |> assign(:form, to_form(%{"name" => collection.name}, as: :collection))
         |> put_flash(:info, "Renamed.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = Enum.map(changeset.errors, fn {field, {msg, opts}} -> {field, {msg, opts}} end)

        {:noreply,
         assign(socket, :form, to_form(%{"name" => name}, as: :collection, errors: errors))}

      {:error, :not_found} ->
        {:noreply, push_navigate(socket, to: ~p"/collections")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    with {int, ""} <- Integer.parse(id),
         {:ok, _} <- Collections.remove_item(socket.assigns.current_user.id, int) do
      {:noreply,
       socket
       |> put_flash(:info, "Removed. Save it again from its run if you change your mind.")
       |> load_items()}
    else
      _ -> {:noreply, put_flash(socket, :error, "That item could not be found.")}
    end
  end

  defp load_items(socket) do
    user_id = socket.assigns.current_user.id
    collection_id = socket.assigns.collection.id
    counts = Collections.review_counts(user_id, collection_id)

    opts = if socket.assigns.status_filter, do: [status: socket.assigns.status_filter], else: []

    socket
    |> assign(:counts, counts)
    |> assign(:total, counts |> Map.values() |> Enum.sum())
    |> assign(:items, Collections.list_items(user_id, collection_id, opts))
  end

  # Carries the recorded source run, if any; the generator re-verifies it
  # server-side before recording lineage.
  defp lineage_params(%{source_run_id: nil, smiles: smiles}), do: %{smiles: smiles}

  defp lineage_params(%{source_run_id: run_id, smiles: smiles}),
    do: %{smiles: smiles, from_run: run_id}

  defp status_label(status), do: Map.fetch!(@status_labels, status)

  defp filter_class(true),
    do:
      "rounded-full border border-primary bg-primary/10 px-3 py-1 text-accent dark:text-accent-light"

  defp filter_class(false),
    do:
      "rounded-full border border-stroke px-3 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
end
