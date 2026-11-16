defmodule PhxMolbindWeb.SettingsLive.Settings do
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Accounts

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:current_token, session["user_token"])
     |> allow_upload(:avatar,
       accept: ~w(.png .jpg .jpeg .gif .webp),
       max_entries: 1,
       max_file_size: PhxMolbind.Avatars.max_bytes()
     )
     |> assign_form(socket.assigns.current_user)
     |> load_sessions()}
  end

  defp load_sessions(socket) do
    assign(
      socket,
      :sessions,
      Accounts.list_user_sessions(socket.assigns.current_user, socket.assigns.current_token)
    )
  end

  # Revoked sessions must lose their already-open LiveView sockets too, not
  # just their ability to make new requests.
  defp disconnect(token) do
    PhxMolbindWeb.Endpoint.broadcast(
      "users_sessions:" <> Base.url_encode64(token),
      "disconnect",
      %{}
    )
  end

  defp assign_form(socket, user) do
    metadata = user.metadata || %{}

    form =
      Phoenix.HTML.FormData.to_form(
        %{
          "username" => user.username || "",
          "bio" => Map.get(metadata, "bio", ""),
          "photo_url" => Map.get(metadata, "photo_url", "")
        },
        as: :profile
      )

    assign(socket, form: form, current_user: user)
  end

  @impl true
  def handle_event("validate_avatar", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_avatar", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :avatar, ref)}

  def handle_event("save_avatar", _params, socket) do
    # File type is decided from the file's magic bytes in Avatars.store/1;
    # the browser-reported name and type are never trusted.
    uploaded =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        {:ok, File.read(path)}
      end)

    with [{:ok, binary}] <- uploaded,
         {:ok, user} <- Accounts.set_avatar(socket.assigns.current_user, binary) do
      {:noreply,
       socket |> assign(:current_user, user) |> put_flash(:info, "Profile picture updated.")}
    else
      [] ->
        {:noreply, put_flash(socket, :error, "Choose an image first.")}

      {:error, :unsupported} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "That file is not a PNG, JPEG, GIF or WebP image, so it was not saved."
         )}

      _ ->
        {:noreply, put_flash(socket, :error, "The picture could not be saved. Please try again.")}
    end
  end

  def handle_event("remove_avatar", _params, socket) do
    case Accounts.clear_avatar(socket.assigns.current_user) do
      {:ok, user} ->
        {:noreply,
         socket |> assign(:current_user, user) |> put_flash(:info, "Profile picture removed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "The picture could not be removed.")}
    end
  end

  def handle_event("set_theme", %{"theme" => theme}, socket)
      when theme in ~w(light dark system) do
    {:noreply, socket |> assign(:theme, theme) |> push_event("theme:set", %{theme: theme})}
  end

  def handle_event("set_theme", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save_profile", %{"profile" => profile_params}, socket) do
    case Accounts.update_profile(socket.assigns.current_user, profile_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign_form(user)
         |> put_flash(:info, "Profile updated successfully!")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Could not update your profile: " <> profile_error(changeset))}
    end
  end

  def handle_event("revoke_session", %{"id" => ref}, socket) do
    case Accounts.revoke_user_session(
           socket.assigns.current_user,
           ref,
           socket.assigns.current_token
         ) do
      {:ok, token} ->
        disconnect(token)
        {:noreply, socket |> put_flash(:info, "Session signed out.") |> load_sessions()}

      {:error, :current_session} ->
        {:noreply,
         put_flash(socket, :error, "This is your current session. Use Sign out below to end it.")}

      {:error, :not_found} ->
        {:noreply,
         socket |> put_flash(:error, "That session no longer exists.") |> load_sessions()}
    end
  end

  def handle_event("revoke_other_sessions", _params, socket) do
    tokens =
      Accounts.delete_other_sessions(socket.assigns.current_user, socket.assigns.current_token)

    Enum.each(tokens, &disconnect/1)

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Signed out of #{length(tokens)} other #{if length(tokens) == 1, do: "session", else: "sessions"}."
     )
     |> load_sessions()}
  end

  defp profile_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.flat_map(fn {field, msgs} -> Enum.map(msgs, &"#{field} #{&1}") end)
    |> List.first("invalid data")
  end

  defp upload_error_text(:too_large), do: "That file is larger than 2 MB."
  defp upload_error_text(:not_accepted), do: "Use a PNG, JPEG, GIF or WebP image."
  defp upload_error_text(:too_many_files), do: "Choose one image at a time."
  defp upload_error_text(_), do: "That file could not be uploaded."

  defp current_theme(assigns), do: assigns[:theme] || "system"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl">
      <div class="rounded-lg border bg-white dark:bg-gray-800 shadow p-6">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-1">
          Settings
        </h2>

        <p class="text-sm text-gray-500 dark:text-gray-400 mb-6">
          Connected wallet: <span class="break-all font-mono">{@current_user.address}</span>
        </p>

        <.simple_form for={@form} id="profile-form" phx-submit="save_profile">
          <div class="mb-6">
            <.input
              type="text"
              field={@form[:username]}
              label="Username"
              placeholder="How should we display your name?"
            />
          </div>

          <div class="mb-6">
            <.input type="text" field={@form[:bio]} label="Bio" placeholder="A short bio" />
          </div>

          <div class="mb-6">
            <.input
              type="text"
              field={@form[:photo_url]}
              label="Photo URL (used only when no picture is uploaded)"
              placeholder="https://..."
            />
          </div>

          <div class="flex justify-end gap-4">
            <.button type="submit">Save</.button>
          </div>
        </.simple_form>

        <section
          class="mt-8 border-t border-stroke pt-6 dark:border-strokedark"
          aria-labelledby="avatar-heading"
        >
          <h3 id="avatar-heading" class="text-sm font-medium text-gray-900 dark:text-white">
            Profile picture
          </h3>
          <div class="mt-3 flex flex-wrap items-start gap-6">
            <div>
              <img
                :if={Accounts.avatar_url(@current_user)}
                id="current-avatar"
                src={Accounts.avatar_url(@current_user)}
                alt="Your current profile picture"
                class="size-20 rounded-full border border-gray-200 object-cover dark:border-gray-700"
              />
              <p
                :if={!Accounts.avatar_url(@current_user)}
                class="flex size-20 items-center justify-center rounded-full border border-dashed border-gray-300 text-center text-xs text-gray-500 dark:border-gray-600 dark:text-gray-400"
              >
                No picture
              </p>
              <button
                :if={Accounts.avatar_name(@current_user)}
                type="button"
                phx-click="remove_avatar"
                class="mt-2 inline-flex min-h-6 items-center text-sm text-red-600 hover:underline dark:text-red-400"
              >
                Remove picture
              </button>
            </div>

            <form
              id="avatar-form"
              phx-submit="save_avatar"
              phx-change="validate_avatar"
              class="flex min-w-0 max-w-full flex-1 basis-56 flex-col gap-2"
            >
              <label for={@uploads.avatar.ref} class="text-sm text-gray-900 dark:text-white">
                Choose a PNG, JPEG, GIF or WebP image (up to 2 MB)
              </label>
              <.live_file_input
                upload={@uploads.avatar}
                class="w-full max-w-full text-sm text-gray-900 dark:text-white"
              />

              <div :for={entry <- @uploads.avatar.entries} class="flex items-center gap-3">
                <.live_img_preview
                  entry={entry}
                  alt="Preview of the selected picture"
                  class="size-16 rounded-full object-cover"
                />
                <button
                  type="button"
                  phx-click="cancel_avatar"
                  phx-value-ref={entry.ref}
                  class="inline-flex min-h-6 items-center text-sm text-gray-900 underline dark:text-white"
                >
                  Cancel
                </button>
                <p
                  :for={err <- upload_errors(@uploads.avatar, entry)}
                  class="text-sm text-red-600 dark:text-red-400"
                  role="alert"
                >
                  {upload_error_text(err)}
                </p>
              </div>
              <p
                :for={err <- upload_errors(@uploads.avatar)}
                class="text-sm text-red-600 dark:text-red-400"
                role="alert"
              >
                {upload_error_text(err)}
              </p>

              <button
                type="submit"
                disabled={@uploads.avatar.entries == []}
                class="w-fit rounded-lg bg-accent px-4 py-2 text-sm text-white hover:bg-accent-hover disabled:cursor-not-allowed disabled:opacity-60"
              >
                Upload picture
              </button>
            </form>
          </div>
        </section>

        <fieldset class="mt-8 border-t border-stroke pt-6 dark:border-strokedark">
          <legend class="mb-3 text-sm font-medium text-gray-900 dark:text-white">Appearance</legend>
          <form id="theme-form" phx-change="set_theme" class="flex flex-wrap gap-4">
            <label
              :for={{value, label} <- [{"system", "System"}, {"light", "Light"}, {"dark", "Dark"}]}
              class="flex items-center gap-2 text-sm text-gray-900 dark:text-white"
            >
              <input
                type="radio"
                name="theme"
                value={value}
                checked={current_theme(assigns) == value}
              />
              {label}
            </label>
          </form>
          <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">
            Stored in this browser only.
          </p>
        </fieldset>

        <section
          class="mt-8 border-t border-stroke pt-6 dark:border-strokedark"
          aria-labelledby="sessions-heading"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <h3 id="sessions-heading" class="text-sm font-medium text-gray-900 dark:text-white">
              Active sessions
            </h3>
            <button
              :if={Enum.count(@sessions, &(!&1.current?)) > 0}
              type="button"
              phx-click="revoke_other_sessions"
              class="text-sm text-red-600 hover:underline dark:text-red-400"
            >
              Sign out all other sessions
            </button>
          </div>
          <ul class="mt-3 divide-y divide-gray-200 text-sm dark:divide-gray-700">
            <li
              :for={session <- @sessions}
              id={"session-#{session.id}"}
              class="flex flex-wrap items-center justify-between gap-2 py-2"
            >
              <span class="text-gray-900 dark:text-white">
                Signed in {Calendar.strftime(session.inserted_at, "%Y-%m-%d %H:%M")} UTC
                <span
                  :if={session.current?}
                  class="ml-2 rounded bg-green-100 px-2 py-0.5 text-xs text-green-800 dark:bg-green-900 dark:text-green-100"
                >
                  This session
                </span>
              </span>
              <button
                :if={!session.current?}
                type="button"
                phx-click="revoke_session"
                phx-value-id={session.id}
                class="text-red-600 hover:underline dark:text-red-400"
              >
                Sign out
              </button>
            </li>
          </ul>
          <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">
            Sessions expire 60 days after sign-in. Device and location details are not recorded.
          </p>
        </section>

        <section
          class="mt-8 border-t border-stroke pt-6 dark:border-strokedark"
          aria-labelledby="data-heading"
        >
          <h3 id="data-heading" class="text-sm font-medium text-gray-900 dark:text-white">
            Your data
          </h3>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            Download your profile, generation runs, collections and chat messages as JSON.
          </p>
          <.link
            href={~p"/account/export.json"}
            class="mt-3 inline-block rounded-lg border border-stroke px-4 py-2 text-sm hover:bg-gray-100 dark:border-strokedark dark:text-white dark:hover:bg-white/5"
          >
            Download my data (JSON)
          </.link>
        </section>

        <section
          class="mt-8 rounded-lg border border-red-300 p-4 dark:border-red-800"
          aria-labelledby="danger-heading"
        >
          <h3 id="danger-heading" class="text-sm font-medium text-red-700 dark:text-red-400">
            Delete account
          </h3>
          <p class="mt-1 text-sm text-gray-700 dark:text-gray-300">
            This permanently deletes your profile, sessions, generation runs, collections, saved molecules and the chat messages you wrote. It cannot be undone. Consider downloading your data first.
          </p>
          <form action={~p"/account"} method="post" class="mt-3 flex flex-wrap items-end gap-3">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <div class="grow">
              <label for="delete-confirmation" class="text-sm text-gray-900 dark:text-white">
                Type your wallet address to confirm
              </label>
              <input
                id="delete-confirmation"
                type="text"
                name="confirmation"
                autocomplete="off"
                spellcheck="false"
                placeholder={@current_user.address}
                class="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 font-mono text-sm dark:border-gray-600 dark:bg-gray-900 dark:text-white"
              />
            </div>
            <button
              type="submit"
              class="rounded-lg bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600"
            >
              Delete my account
            </button>
          </form>
        </section>

        <div class="mt-8 border-t border-stroke pt-6 dark:border-strokedark">
          <form action={~p"/auth/sign-out"} method="post">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <button type="submit" class="text-sm text-red-600 dark:text-red-400 hover:underline">
              Sign out
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
