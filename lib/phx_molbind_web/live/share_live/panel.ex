defmodule PhxMolbindWeb.ShareLive.Panel do
  @moduledoc """
  Owner-side sharing controls, embedded on the run and collection pages.

  Shows an explicit visibility state, previews exactly what a link exposes,
  creates links (revealing each URL once), lists them and revokes them. All
  data access goes through `PhxMolbind.Sharing`, which is scoped to the user.
  """
  use PhxMolbindWeb, :live_component

  alias PhxMolbind.Sharing
  alias PhxMolbind.Sharing.ShareLink

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:new_url, fn -> nil end)
     |> assign_new(:error, fn -> nil end)
     |> assign(:shown_limit, 8)
     |> load_links()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      id={@id}
      class="mt-6 rounded-lg border border-stroke bg-white p-5 dark:border-strokedark dark:bg-[#181818]"
      aria-labelledby={"#{@id}-heading"}
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h2 id={"#{@id}-heading"} class="font-medium text-black dark:text-white">Sharing</h2>
        <p class="text-sm" data-visibility={if @active_count > 0, do: "shared", else: "private"}>
          <%= if @active_count > 0 do %>
            <span class="font-medium text-black dark:text-white">
              Shared: {@active_count} active {if @active_count == 1, do: "link", else: "links"}
            </span>
          <% else %>
            <span class="text-body dark:text-bodydark">Private: no active links</span>
          <% end %>
        </p>
      </div>

      <div class="mt-3 rounded-md bg-gray-2 p-3 text-sm text-black dark:bg-white/5 dark:text-white">
        <p class="font-medium">What a link shows to anyone who has it</p>
        <ul class="mt-1 list-disc pl-5">
          <li :for={item <- visible_items(@kind)}>{item}</li>
        </ul>
        <p class="mt-2 font-medium">What it never shows</p>
        <ul class="mt-1 list-disc pl-5">
          <li>Your name or wallet address, your other runs and collections, and review statuses</li>
        </ul>
      </div>

      <form phx-submit="create" phx-target={@myself} class="mt-4 flex flex-wrap items-end gap-3">
        <div>
          <label for={"#{@id}-expiry"} class="text-sm text-body dark:text-bodydark">
            Link expires after
          </label>
          <select
            id={"#{@id}-expiry"}
            name="expiry"
            class="mt-1 rounded-lg border border-stroke bg-white px-3 py-2 text-zinc-900 dark:border-strokedark"
          >
            <option :for={{label, value} <- Sharing.expiry_options()} value={value}>{label}</option>
          </select>
        </div>
        <button
          type="submit"
          class="rounded-lg bg-accent px-4 py-2 text-white hover:bg-accent-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        >
          Create read-only link
        </button>
      </form>

      <p :if={@error} class="mt-3 text-sm text-red-600 dark:text-red-400" role="alert">{@error}</p>

      <div
        :if={@new_url}
        class="mt-4 rounded-md border border-accent p-3 dark:border-accent-light"
        role="status"
      >
        <p class="text-sm font-medium text-black dark:text-white">
          Copy this link now. For your security it is shown only once and cannot be recovered later.
        </p>
        <div class="mt-2 flex flex-wrap items-center gap-2">
          <label for={"#{@id}-url"} class="sr-only">New share link</label>
          <input
            id={"#{@id}-url"}
            type="text"
            readonly
            value={@new_url}
            class="min-w-0 grow rounded border border-stroke bg-white px-2 py-1 font-mono text-xs text-zinc-900"
          />
          <button
            id={"#{@id}-copy"}
            type="button"
            phx-hook="CopyButton"
            data-copy={@new_url}
            class="rounded border border-stroke px-3 py-1 text-sm hover:bg-gray-2 dark:border-strokedark dark:text-white dark:hover:bg-white/5"
          >
            Copy link
          </button>
          <button
            type="button"
            phx-click="dismiss_url"
            phx-target={@myself}
            class="text-sm text-body underline dark:text-bodydark"
          >
            I've copied it
          </button>
        </div>
      </div>

      <p :if={length(@links) > @shown_limit} class="mt-4 text-xs text-body dark:text-bodydark">
        Showing the {@shown_limit} most recent of {length(@links)} links.
      </p>
      <ul :if={@links != []} class="mt-4 divide-y divide-stroke text-sm dark:divide-strokedark">
        <li
          :for={link <- Enum.take(@links, @shown_limit)}
          id={"share-link-#{link.id}"}
          class="flex flex-wrap items-center justify-between gap-2 py-2"
        >
          <span class="text-black dark:text-white">
            Created {Calendar.strftime(link.inserted_at, "%Y-%m-%d %H:%M")} UTC · {expiry_text(link)} ·
            <strong class="font-medium">{status_text(link)}</strong>
          </span>
          <button
            :if={ShareLink.active?(link)}
            type="button"
            phx-click="revoke"
            phx-value-id={link.id}
            phx-target={@myself}
            class="text-red-600 hover:underline dark:text-red-400"
          >
            Revoke
          </button>
        </li>
      </ul>
    </section>
    """
  end

  @impl true
  def handle_event("create", %{"expiry" => expiry}, socket) do
    %{kind: kind, target_id: target_id, user_id: user_id} = socket.assigns

    case Sharing.create_link(user_id, kind, target_id, expiry) do
      {:ok, _link, token} ->
        {:noreply,
         socket |> assign(:new_url, url(~p"/s/#{token}")) |> assign(:error, nil) |> load_links()}

      {:error, _reason} ->
        {:noreply, assign(socket, :error, "A link could not be created for this item.")}
    end
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    with {int, ""} <- Integer.parse(id),
         {:ok, _link} <- Sharing.revoke_link(socket.assigns.user_id, int) do
      {:noreply, socket |> assign(:error, nil) |> load_links()}
    else
      _ -> {:noreply, assign(socket, :error, "That link could not be found.")}
    end
  end

  def handle_event("dismiss_url", _params, socket), do: {:noreply, assign(socket, :new_url, nil)}

  defp load_links(socket) do
    %{kind: kind, target_id: target_id, user_id: user_id} = socket.assigns
    links = Sharing.list_links(user_id, kind, target_id)

    socket
    |> assign(:links, links)
    |> assign(:active_count, Enum.count(links, &ShareLink.active?/1))
  end

  defp visible_items("run"),
    do: [
      "The starting molecule, the run's parameters and date",
      "Every candidate with its model-reported score"
    ]

  defp visible_items("collection"),
    do: ["The collection's name", "Each saved molecule with its score, if one was recorded"]

  defp expiry_text(%{expires_at: nil}), do: "never expires"

  defp expiry_text(%{expires_at: at}),
    do: "expires #{Calendar.strftime(at, "%Y-%m-%d %H:%M")} UTC"

  defp status_text(link) do
    cond do
      link.revoked_at -> "Revoked"
      not ShareLink.active?(link) -> "Expired"
      true -> "Active"
    end
  end
end
