defmodule PhxMolbindWeb.CollectionsLive.Index do
  @moduledoc "List, create and delete the signed-in user's collections (`/collections`)."
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Collections

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Collections")
     |> assign(:confirm_id, nil)
     |> assign(:form, to_form(%{"name" => ""}, as: :collection))
     |> load()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl">
      <.simple_form for={@form} id="collection-form" phx-submit="create">
        <.input
          field={@form[:name]}
          type="text"
          label="New collection"
          placeholder="e.g. Shortlist"
          maxlength="80"
        />
        <:actions>
          <.button type="submit">Create</.button>
        </:actions>
      </.simple_form>

      <div
        :if={@collections == []}
        class="mt-6 rounded-lg border border-dashed border-stroke p-6 text-sm text-body dark:border-strokedark dark:text-bodydark"
      >
        <p class="font-medium text-black dark:text-white">No collections yet.</p>
        <p class="mt-1">
          Create one above, then save candidates into it from any run in your history.
        </p>
      </div>

      <ul
        :if={@collections != []}
        class="mt-6 divide-y divide-stroke rounded-lg border border-stroke bg-white dark:divide-strokedark dark:border-strokedark dark:bg-[#181818]"
      >
        <li :for={c <- @collections} id={"collection-#{c.id}"} class="p-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <.link
                navigate={~p"/collections/#{c.id}"}
                class="font-medium text-accent dark:text-accent-light hover:underline"
              >
                {c.name}
              </.link>
              <p class="text-xs text-body dark:text-bodydark">
                {c.item_count} saved {if c.item_count == 1, do: "molecule", else: "molecules"}
              </p>
            </div>
            <button
              :if={@confirm_id != c.id}
              type="button"
              phx-click="ask_delete"
              phx-value-id={c.id}
              class="text-sm text-red-600 hover:underline dark:text-red-400"
            >
              Delete
            </button>
          </div>
          <div
            :if={@confirm_id == c.id}
            class="mt-3 flex flex-wrap items-center gap-3 rounded-md bg-red-50 p-3 text-sm dark:bg-red-950/30"
            role="alert"
          >
            <span>
              Delete “{c.name}” and its {c.item_count} saved molecules? Your runs are not affected.
            </span>
            <button
              type="button"
              phx-click="delete"
              phx-value-id={c.id}
              class="rounded bg-red-600 px-3 py-1 text-white"
            >
              Delete collection
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
    </div>
    """
  end

  @impl true
  def handle_event("create", %{"collection" => %{"name" => name}}, socket) do
    case Collections.create_collection(socket.assigns.current_user.id, %{name: name}) do
      {:ok, _collection} ->
        {:noreply, socket |> assign(:form, to_form(%{"name" => ""}, as: :collection)) |> load()}

      {:error, changeset} ->
        errors =
          for {field, {msg, opts}} <- Enum.map(changeset.errors, & &1), do: {field, {msg, opts}}

        {:noreply,
         assign(socket, :form, to_form(%{"name" => name}, as: :collection, errors: errors))}
    end
  end

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
         {:ok, _} <- Collections.delete_collection(socket.assigns.current_user.id, int) do
      {:noreply,
       socket |> assign(:confirm_id, nil) |> put_flash(:info, "Collection deleted.") |> load()}
    else
      _ ->
        {:noreply,
         socket
         |> assign(:confirm_id, nil)
         |> put_flash(:error, "That collection could not be found.")}
    end
  end

  defp load(socket),
    do: assign(socket, :collections, Collections.list_collections(socket.assigns.current_user.id))
end
