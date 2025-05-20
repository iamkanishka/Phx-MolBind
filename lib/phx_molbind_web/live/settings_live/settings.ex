defmodule PhxMolbindWeb.SettingsLive.Settings do
  use PhxMolbindWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:metamask_connected, false)
      |> assign(:user_exists, false)
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:user_address, nil)
      |> assign(:profile, %{
        first_name: "",
        last_name: "",
        email: "",
        user_bio: "",
        photo: "",
        id: "",
        phone: ""
      })

    {:ok, socket}
  end

  @impl true
  def handle_event("connect_metamask", _, socket) do
    {:noreply, push_event(socket, "request_metamask_connection", %{})}
  end

  @impl true
  def handle_event("save_profile", %{"profile" => profile_params}, socket) do
    if socket.assigns.user_exists do
      {:noreply, push_event(socket, "request_profile_update", %{profile: profile_params})}
    else
      {:noreply, push_event(socket, "request_profile_creation", %{profile: profile_params})}
    end
  end

  @impl true
  def handle_info(%{event: "metamask_connected", payload: %{address: address}}, socket) do
    {:noreply,
     socket
     |> assign(:metamask_connected, true)
     |> assign(:user_address, address)
     |> assign(:loading, true)}
  end

  def handle_info(
        %{event: "user_exists_check", payload: %{exists: exists, address: address}},
        socket
      ) do
    socket =
      socket
      |> assign(:user_exists, exists)
      |> assign(:loading, false)

    if exists do
      {:noreply, push_event(socket, "request_profile_retrieval", %{})}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "profile_retrieved", payload: %{profile: profile}}, socket) do
    {:noreply,
     socket
     |> assign(:profile, %{
       first_name: profile.firstName,
       last_name: profile.lastName,
       email: profile.email,
       user_bio: profile.userBio,
       photo: profile.photo,
       id: profile.id,
       phone: profile.phone
     })
     |> assign(:loading, false)}
  end

  def handle_info(%{event: "profile_created"}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Profile created successfully!")
     |> assign(:user_exists, true)
     |> assign(:loading, false)}
  end

  def handle_info(%{event: "profile_updated"}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Profile updated successfully!")
     |> assign(:loading, false)}
  end

  def handle_info(%{event: "metamask_error", payload: %{error: error}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "MetaMask error: #{error}")
     |> assign(:loading, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- <div class="container mx-auto px-4 py-8" phx-hook="MetamaskUser">
      <div class="max-w-2xl mx-auto">
        <h1 class="text-2xl font-bold mb-6">User Profile</h1>

        <%= if @loading do %>
          <div class="text-center py-8">
            <div class="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500 mx-auto"></div>
            <p class="mt-4">Loading...</p>
          </div>
        <% else %>
          <%= if @error do %>
            <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
              <%= @error %>
            </div>
          <% end %>

          <%= if not @metamask_connected do %>
            <div class="bg-blue-100 border border-blue-400 text-blue-700 px-4 py-3 rounded mb-4">
              <p class="mb-2">Please connect your MetaMask wallet to continue</p>
              <button
                phx-click="connect_metamask"
                class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
              >
                Connect MetaMask
              </button>
            </div>
          <% else %>
            <div class="mb-6">
              <p class="text-sm text-gray-600">Connected address:</p>
              <p class="font-mono text-sm break-all"><%= @user_address %></p>
            </div>

            <.form
              :let={f}
              for={:profile}
              phx-submit="save_profile"
              class="space-y-4"
            >
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <%= label f, :first_name, "First Name", class: "block text-sm font-medium text-gray-700" %>
                  <%= text_input f, :first_name, value: @profile.first_name, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm" %>
                </div>

                <div>
                  <%= label f, :last_name, "Last Name", class: "block text-sm font-medium text-gray-700" %>
                  <%= text_input f, :last_name, value: @profile.last_name, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm" %>
                </div>
              </div>

              <div>
                <%= label f, :email, "Email", class: "block text-sm font-medium text-gray-700" %>
                <%= text_input f, :email, value: @profile.email, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm" %>
              </div>

              <div>
                <%= label f, :user_bio, "Bio", class: "block text-sm font-medium text-gray-700" %>
                <%= textarea f, :user_bio, value: @profile.user_bio, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm" %>
              </div>

              <div>
                <%= label f, :photo, "Photo URL", class: "block text-sm font-medium text-gray-700" %>
                <%= text_input f, :photo, value: @profile.photo, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm" %>
              </div>

              <div>
                <%= label f, :id, "ID", class: "block text-sm font-medium text-gray-700" %>
                <%= text_input f, :id, value: @profile.id, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm" %>
              </div>

              <div>
                <%= label f, :phone, "Phone", class: "block text-sm font-medium text-gray-700" %>
                <%= text_input f, :phone, value: @profile.phone, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm" %>
              </div>

              <div class="pt-4">
                <button
                  type="submit"
                  class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded"
                >
                  <%= if @user_exists, do: "Update Profile", else: "Create Profile" %>
                </button>
              </div>
            </.form>
          <% end %>
        <% end %>
      </div>
    </div> --%>
    <div id="profile-root" class="mx-auto max-w-7xl" phx-hook="Profile">
      <div class="mb-4 flex items-center space-x-2">
        <%!-- <span>Toggle Theme</span> <.dark_mode_switcher /> --%>
      </div>

      <%= if @loading do %>
        <div class="text-center py-8">
          <div class="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500 mx-auto">
          </div>

          <p class="mt-4">Loading...</p>
        </div>
      <% else %>
        <%= if @error do %>
          <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
            {@error}
          </div>
        <% end %>

        <%= if not @metamask_connected do %>
          <div class="bg-blue-100 border border-blue-400 text-blue-700 px-4 py-3 rounded mb-4">
            <p class="mb-2">Please connect your MetaMask wallet to continue</p>

            <button
              phx-click="connect_metamask"
              class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
            >
              Connect MetaMask
            </button>
          </div>
        <% else %>
          <div class="mb-6">
            <p class="text-sm text-gray-600">Connected address:</p>

            <p class="font-mono text-sm break-all">{@user_address}</p>
          </div>
        <% end %>
      <% end %>

      <div class="grid grid-cols-5 gap-8">
        <div class="col-span-5 xl:col-span-3">
          <div class="rounded-lg border bg-white dark:bg-gray-800 shadow p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Personal Information
            </h3>

            <.simple_form for={@profile} phx-submit="save_info" phx-change="validate">
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-6 mb-6">
                <div>
                  <.label for="first_name">First Name</.label>
                   <.input type="text" name="first_name" value={@profile.first_name} />
                </div>

                <div>
                  <.label for="last_name">Last Name</.label>
                   <.input type="text" name="last_name" value={@profile.last_name} />
                </div>
              </div>

              <div class="mb-6">
                <.label for="email">Email Address</.label>
                 <.input type="email" name="email" value={@profile.email} readonly />
              </div>

              <div class="mb-6">
                <.label for="user_bio">BIO</.label>
                 <textarea
                  name="user_bio"
                  rows="6"
                  class="w-full rounded border px-3 py-2 dark:bg-gray-700 dark:text-white"
                >
              <%= @profile.user_bio %>
            </textarea>
              </div>

              <div class="flex justify-end gap-4">
                <.button type="button" phx-click="cancel">Cancel</.button>

                <.button type="submit">Save</.button>
              </div>
            </.simple_form>
          </div>
        </div>

        <div class="col-span-5 xl:col-span-2">
          <div class="rounded-lg border bg-white dark:bg-gray-800 shadow p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Your Photo
            </h3>

            <div class="mb-4 flex items-center gap-3">
              <div class="h-14 w-14 rounded-full overflow-hidden">
                <img
                  src={@profile.photo || "/images/default-avatar.jpg"}
                  class="w-full h-full object-cover"
                />
              </div>

              <div>
                <span>Edit your photo</span>
                <div class="flex space-x-2 text-sm text-blue-600">
                  <button phx-click="delete_photo" type="button">Delete</button>
                  <label phx-click="upload_photo" for="photo_upload" class="cursor-pointer">
                    Update
                  </label>
                </div>
              </div>
            </div>

            <%!-- <form phx-submit="upload_photo">
              <div class="mb-6">
                {live_file_input(@uploads.photo,
                  class: "border-dashed border-2 border-blue-400 w-full p-6 text-center text-gray-600"
                )}
                <p class="mt-2 text-sm">Click or drag to upload (SVG, PNG, JPG, GIF)</p>
              </div>

              <div class="flex justify-end gap-4">
                <.button type="button" phx-click="cancel">Cancel</.button>

                <.button type="submit">Save</.button>
              </div>
            </form> --%>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
