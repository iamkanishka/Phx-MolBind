defmodule PhxMolbindWeb.MessagesLive.Chat do
  @moduledoc """
  The shared research chat lobby (`/message`).

  Messages are persisted and delivered over PubSub. Authors can edit or
  delete their own messages (enforced in `PhxMolbind.Messages`, never by
  client-supplied ids alone). Older history loads on demand.

  LiveView streams only re-render an item when it is re-inserted, so every
  state change that affects a message's markup (editing, delete
  confirmation) re-inserts that message.
  """
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Messages

  @page 50
  @max_length 2000

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl">
      <h2 class="mb-4 text-3xl text-black dark:text-white">Drug Discovery Chat</h2>

      <div class="rounded-lg border border-stroke p-4 dark:border-form-strokedark dark:bg-form-input sm:p-6">
        <h3 class="mb-4 text-xl text-black dark:text-white">Lobby</h3>

        <div class="relative">
          <button
            :if={@has_older}
            type="button"
            phx-click="load_older"
            class="mb-2 w-full rounded border border-stroke py-1 text-sm text-accent dark:text-accent-light hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
          >
            Load older messages
          </button>

          <div
            id="chat-messages"
            phx-update="stream"
            phx-hook="ChatScroll"
            data-jump="chat-jump"
            role="log"
            aria-live="polite"
            aria-relevant="additions"
            aria-label="Chat messages"
            tabindex="0"
            class="mb-4 h-[50vh] min-h-64 overflow-y-auto rounded-lg bg-white p-4 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary dark:bg-[#181818]"
          >
            <div :for={{dom_id, message} <- @streams.messages} id={dom_id} class="mb-3">
              <p class="text-sm font-semibold text-black dark:text-white">
                {sender_label(message.user)}
                <time
                  datetime={DateTime.to_iso8601(message.inserted_at)}
                  title={Calendar.strftime(message.inserted_at, "%Y-%m-%d %H:%M:%S UTC")}
                  class="ml-2 text-xs font-normal text-gray-500 dark:text-gray-400"
                >
                  {format_time(message.inserted_at)}
                </time>
                <span
                  :if={message.edited_at}
                  class="ml-1 text-xs font-normal text-gray-500 dark:text-gray-400"
                >
                  (edited)
                </span>
              </p>

              <blockquote
                :if={message.reply_to}
                class="mt-1 border-l-2 border-stroke pl-2 text-xs text-gray-500 dark:border-strokedark dark:text-gray-400"
              >
                Replying to <strong class="font-medium">{sender_label(message.reply_to.user)}</strong>: {excerpt(
                  message.reply_to
                )}
              </blockquote>

              <%= if @editing_id == message.id do %>
                <form phx-submit="save_edit" class="mt-1 flex flex-wrap gap-2">
                  <input type="hidden" name="message_id" value={message.id} />
                  <label for={"edit-#{message.id}"} class="sr-only">Edit message</label>
                  <input
                    id={"edit-#{message.id}"}
                    type="text"
                    name="body"
                    value={message.body}
                    maxlength={max_length()}
                    autocomplete="off"
                    class="min-w-0 grow rounded border border-stroke bg-transparent px-2 py-1 dark:border-strokedark dark:text-white"
                  />
                  <button type="submit" class="rounded bg-accent px-3 py-1 text-sm text-white">
                    Save
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_edit"
                    class="rounded border border-stroke px-3 py-1 text-sm dark:border-strokedark dark:text-white"
                  >
                    Cancel
                  </button>
                </form>
              <% else %>
                <p phx-no-format class="whitespace-pre-wrap break-words text-black dark:text-white">{message.body}</p>
              <% end %>

              <div
                :if={message.smiles}
                id={"msg-card-#{message.id}"}
                class="mt-2 inline-block max-w-full rounded-lg border border-stroke bg-gray-2 p-3 dark:border-strokedark dark:bg-white/5"
              >
                <canvas
                  id={"msg-canvas-#{message.id}"}
                  phx-hook="renderSMILESmol"
                  data-smiles={message.smiles}
                  width="220"
                  height="160"
                  data-width="220"
                  data-height="160"
                  role="img"
                  aria-label={"Shared molecule: #{message.smiles}"}
                  class="max-w-full rounded border border-stroke bg-white dark:border-strokedark"
                >
                </canvas>
                <p class="mt-2 break-all font-mono text-xs text-black dark:text-white">
                  {message.smiles}
                </p>
                <div class="mt-2 flex flex-wrap gap-2 text-xs">
                  <button
                    id={"msg-copy-#{message.id}"}
                    type="button"
                    phx-hook="CopyButton"
                    data-copy={message.smiles}
                    class="rounded border border-stroke px-2 py-1 hover:bg-white dark:border-strokedark dark:text-white dark:hover:bg-white/5"
                  >
                    Copy SMILES
                  </button>
                  <.link
                    navigate={~p"/model?#{%{smiles: message.smiles}}"}
                    class="rounded border border-stroke px-2 py-1 hover:bg-white dark:border-strokedark dark:text-white dark:hover:bg-white/5"
                  >
                    Open in generator
                  </.link>
                </div>
                <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  Structure only; no properties are attached to shared molecules.
                </p>
              </div>

              <div
                class="mt-1 flex flex-wrap items-center gap-1 text-xs"
                role="group"
                aria-label="Reactions"
              >
                <button
                  :for={{emoji, name} <- Messages.reaction_emojis()}
                  type="button"
                  phx-click="react"
                  phx-value-id={message.id}
                  phx-value-emoji={emoji}
                  aria-pressed={to_string(reacted?(message, emoji, @current_user.id))}
                  aria-label={reaction_label(name, reaction_count(message, emoji))}
                  class={[
                    "inline-flex min-h-6 min-w-6 items-center justify-center rounded-full border px-2 py-0.5 hover:bg-gray-2 dark:hover:bg-white/5",
                    if(reacted?(message, emoji, @current_user.id),
                      do: "border-accent bg-accent/10 dark:border-accent-light",
                      else: "border-stroke dark:border-strokedark"
                    )
                  ]}
                >
                  <span aria-hidden="true">{emoji}</span>
                  <span
                    :if={reaction_count(message, emoji) > 0}
                    class="ml-1 text-black dark:text-white"
                  >
                    {reaction_count(message, emoji)}
                  </span>
                </button>
                <button
                  type="button"
                  phx-click="reply"
                  phx-value-id={message.id}
                  aria-label={"Reply to #{sender_label(message.user)}"}
                  class="ml-2 inline-flex min-h-6 items-center text-accent hover:underline dark:text-accent-light"
                >
                  Reply
                </button>
              </div>

              <div
                :if={message.user_id == @current_user.id and @editing_id != message.id}
                class="mt-1 flex items-center gap-3 text-xs [&>button]:inline-flex [&>button]:min-h-6 [&>button]:items-center"
              >
                <button
                  type="button"
                  phx-click="edit"
                  phx-value-id={message.id}
                  class="text-accent dark:text-accent-light hover:underline"
                >
                  Edit
                </button>
                <%= if @confirm_id == message.id do %>
                  <span class="text-gray-700 dark:text-gray-300">Delete this message?</span>
                  <button
                    type="button"
                    phx-click="delete"
                    phx-value-id={message.id}
                    class="text-red-600 hover:underline dark:text-red-400"
                  >
                    Delete
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_delete"
                    class="hover:underline dark:text-white"
                  >
                    Cancel
                  </button>
                <% else %>
                  <button
                    type="button"
                    phx-click="ask_delete"
                    phx-value-id={message.id}
                    class="text-red-600 hover:underline dark:text-red-400"
                  >
                    Delete
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <button
            id="chat-jump"
            type="button"
            class="absolute bottom-24 left-1/2 hidden -translate-x-1/2 rounded-full bg-accent px-4 py-1 text-sm text-white shadow-lg"
          >
            New messages ↓
          </button>
        </div>

        <div
          :if={@replying_to}
          id="reply-bar"
          class="mb-2 flex items-center justify-between gap-2 rounded bg-gray-2 px-3 py-2 text-sm text-black dark:bg-white/5 dark:text-white"
        >
          <span class="min-w-0 truncate">
            Replying to <strong class="font-medium">{sender_label(@replying_to.user)}</strong>: {excerpt(
              @replying_to
            )}
          </span>
          <button
            type="button"
            phx-click="cancel_reply"
            aria-label="Cancel reply"
            class="shrink-0 rounded px-2 py-1 hover:bg-white dark:hover:bg-white/10"
          >
            ✕
          </button>
        </div>

        <.simple_form for={@form} id="chat-form" phx-submit="send_message" phx-change="validate">
          <div class="flex space-x-4">
            <div class="w-full">
              <.input
                type="text"
                field={@form[:body]}
                placeholder="Type a message..."
                autocomplete="off"
                maxlength={max_length()}
                aria-label="Message"
              />
            </div>

            <button
              type="submit"
              class="flex items-center justify-center rounded-lg bg-accent px-6 py-3 text-white transition hover:bg-opacity-90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:bg-gray-400"
            >
              Send
            </button>
          </div>
        </.simple_form>

        <p :if={@send_error} class="mt-2 text-sm text-red-600 dark:text-red-400" role="alert">
          {@send_error}
        </p>
        <p class="mt-1 text-right text-xs text-gray-500 dark:text-gray-400" aria-hidden="true">
          {String.length(@form[:body].value || "")}/{max_length()}
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Messages.subscribe()

    messages = Messages.list_recent_messages(@page)

    {:ok,
     socket
     |> assign(:page_title, "Messages")
     |> assign(:editing_id, nil)
     |> assign(:confirm_id, nil)
     |> assign(:send_error, nil)
     |> assign(:replying_to, nil)
     |> assign_older(messages)
     |> stream(:messages, messages)
     |> assign_form("")}
  end

  defp assign_form(socket, body) do
    assign(socket, :form, Phoenix.HTML.FormData.to_form(%{"body" => body}, as: :message))
  end

  # Tracks the oldest loaded message so "Load older" knows where to resume.
  defp assign_older(socket, []), do: socket |> assign(:oldest, nil) |> assign(:has_older, false)

  defp assign_older(socket, [oldest | _]) do
    socket |> assign(:oldest, oldest) |> assign(:has_older, Messages.older_exists?(oldest))
  end

  ## Events

  @impl true
  def handle_event("validate", %{"message" => %{"body" => body}}, socket) do
    {:noreply, socket |> assign(:send_error, nil) |> assign_form(body)}
  end

  def handle_event("send_message", %{"message" => %{"body" => body}}, socket) do
    case String.trim(body) do
      "" ->
        {:noreply, socket}

      trimmed ->
        attrs =
          case socket.assigns.replying_to do
            nil -> %{"body" => trimmed}
            parent -> %{"body" => trimmed, "reply_to_id" => parent.id}
          end

        case Messages.create_message(attrs, socket.assigns.current_user.id) do
          {:ok, _message} ->
            # The PubSub broadcast delivers the message back to us too, so
            # every client (including the sender) renders via one code path.
            {:noreply,
             socket |> assign(:send_error, nil) |> assign(:replying_to, nil) |> assign_form("")}

          {:error, _changeset} ->
            # Keep the typed text so the user can simply press Send again.
            {:noreply,
             socket
             |> assign(
               :send_error,
               "Your message was not sent. It is still in the box, so you can retry."
             )
             |> assign_form(body)}
        end
    end
  end

  def handle_event("reply", %{"id" => id}, socket) do
    with {int, ""} <- Integer.parse(id),
         %{} = parent <- Messages.get_message(int) do
      {:noreply, assign(socket, :replying_to, parent)}
    else
      _ -> {:noreply, put_flash(socket, :error, "That message could not be found.")}
    end
  end

  def handle_event("cancel_reply", _params, socket),
    do: {:noreply, assign(socket, :replying_to, nil)}

  def handle_event("react", %{"id" => id, "emoji" => emoji}, socket) do
    with {int, ""} <- Integer.parse(id),
         {:ok, _message} <- Messages.toggle_reaction(socket.assigns.current_user.id, int, emoji) do
      # The broadcast re-renders the message for everyone, including us.
      {:noreply, socket}
    else
      _ -> {:noreply, put_flash(socket, :error, "That reaction could not be saved.")}
    end
  end

  def handle_event("load_older", _params, %{assigns: %{oldest: %{} = oldest}} = socket) do
    older = Messages.list_older_messages(oldest, @page)

    socket =
      older
      |> Enum.reverse()
      |> Enum.reduce(socket, &stream_insert(&2, :messages, &1, at: 0))

    socket =
      case older do
        [] -> assign(socket, :has_older, false)
        [first | _] -> assign_older(socket, [first])
      end

    {:noreply, socket}
  end

  def handle_event("load_older", _params, socket), do: {:noreply, socket}

  def handle_event("edit", %{"id" => id}, socket) do
    current_id = socket.assigns.current_user.id

    with {int, ""} <- Integer.parse(id),
         %{user_id: ^current_id} = message <- Messages.get_message(int) do
      previous = socket.assigns.editing_id
      socket = socket |> assign(:editing_id, int) |> assign(:confirm_id, nil)
      {:noreply, socket |> refresh(previous) |> stream_insert(:messages, message)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    previous = socket.assigns.editing_id
    {:noreply, socket |> assign(:editing_id, nil) |> refresh(previous)}
  end

  def handle_event("save_edit", %{"message_id" => id, "body" => body}, socket) do
    with {int, ""} <- Integer.parse(id),
         {:ok, message} <- Messages.update_message(socket.assigns.current_user.id, int, body) do
      # The broadcast re-inserts the updated message for everyone, including us.
      {:noreply, socket |> assign(:editing_id, nil) |> stream_insert(:messages, message)}
    else
      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:editing_id, nil)
         |> put_flash(:error, "That message could not be found.")}

      _ ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "The edit was not saved. Messages must be 1–#{@max_length} characters."
         )}
    end
  end

  def handle_event("ask_delete", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {int, ""} ->
        previous = socket.assigns.confirm_id
        {:noreply, socket |> assign(:confirm_id, int) |> refresh(previous) |> refresh(int)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    previous = socket.assigns.confirm_id
    {:noreply, socket |> assign(:confirm_id, nil) |> refresh(previous)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    with {int, ""} <- Integer.parse(id),
         {:ok, _} <- Messages.delete_message(socket.assigns.current_user.id, int) do
      {:noreply, assign(socket, :confirm_id, nil)}
    else
      _ ->
        {:noreply,
         socket
         |> assign(:confirm_id, nil)
         |> put_flash(:error, "That message could not be found.")}
    end
  end

  ## PubSub

  @impl true
  def handle_info({:new_message, message}, socket),
    do: {:noreply, stream_insert(socket, :messages, message)}

  def handle_info({:message_updated, message}, socket),
    do: {:noreply, stream_insert(socket, :messages, message)}

  def handle_info({:message_deleted, id}, socket),
    do: {:noreply, stream_delete_by_dom_id(socket, :messages, "messages-#{id}")}

  ## Helpers

  defp refresh(socket, nil), do: socket

  defp refresh(socket, id) do
    case Messages.get_message(id) do
      nil -> socket
      message -> stream_insert(socket, :messages, message)
    end
  end

  defp max_length, do: @max_length

  defp reaction_count(message, emoji), do: Enum.count(message.reactions, &(&1.emoji == emoji))

  defp reacted?(message, emoji, user_id),
    do: Enum.any?(message.reactions, &(&1.emoji == emoji and &1.user_id == user_id))

  defp reaction_label(name, 0), do: "React with #{name}"
  defp reaction_label(name, 1), do: "#{name}, 1 reaction"
  defp reaction_label(name, n), do: "#{name}, #{n} reactions"

  # One-line preview of a quoted message.
  defp excerpt(%{smiles: smiles}) when is_binary(smiles), do: "shared molecule " <> smiles

  defp excerpt(%{body: body}) do
    if String.length(body) > 80, do: String.slice(body, 0, 80) <> "…", else: body
  end

  defp format_time(datetime) do
    if DateTime.to_date(datetime) == Date.utc_today(),
      do: Calendar.strftime(datetime, "%H:%M"),
      else: Calendar.strftime(datetime, "%b %-d, %H:%M")
  end

  defp sender_label(%{username: username}) when is_binary(username) and username != "",
    do: username

  defp sender_label(%{address: address}), do: short_address(address)

  defp short_address("0x" <> rest) do
    "0x" <> String.slice(rest, 0, 4) <> "…" <> String.slice(rest, -4, 4)
  end

  defp short_address(address), do: address
end
