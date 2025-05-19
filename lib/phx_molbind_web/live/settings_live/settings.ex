defmodule PhxMolbindWeb.SettingsLive.Settings do
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Accounts
  alias PhxMolbindWeb.Router.Helpers, as: Routes

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:page_name, "settings")
     |> assign(:sidebar_open, true)
     |> assign(:user, Accounts.get_user!(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully.")
         |> redirect(to: Routes.settings_path(socket, :index))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update user.")
         |> assign(:changeset, changeset)}
    end
  end
end
