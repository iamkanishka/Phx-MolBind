defmodule PhxMolbindWeb.ProfileLive.Profile do
  use PhxMolbindWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-[970px]">
      <div class="overflow-hidden rounded-lg border border-stroke bg-white shadow-default dark:border-strokedark dark:bg-boxdark">
        <div class="relative z-20 h-[140px] md:h-[260px] bg-gradient-to-r from-blue-600 to-teal-500">
        </div>

        <div class="px-4 pb-6 text-center lg:pb-8 xl:pb-[46px]">
          <div class="relative z-30 mx-auto -mt-[88px] h-[120px] w-full max-w-[120px] rounded-full bg-white/20 p-1 backdrop-blur sm:h-[176px] sm:max-w-[176px] sm:p-3">
            <div class="relative drop-shadow-2">
              <%= if @photo_url do %>
                <img src={@photo_url} alt="profile" class="rounded-full" width="160" height="160" />
              <% else %>
                <div class="flex h-full w-full items-center justify-center rounded-full bg-primary/10 text-4xl font-semibold text-accent dark:text-accent-light">
                  {String.first(@display_name)}
                </div>
              <% end %>
            </div>
          </div>

          <div class="mt-4">
            <h2 class="mb-1.5 text-2xl font-semibold text-black dark:text-white">
              {@display_name}
            </h2>

            <p class="font-mono text-sm text-gray-500 dark:text-gray-400">
              {@current_user.address}
            </p>

            <div class="mx-auto max-w-[720px] mt-[18px]">
              <h3 class="font-semibold text-black dark:text-white">About Me</h3>

              <p class="mt-[18px]">
                {@bio || "No bio yet."}
              </p>
            </div>

            <div class="mt-6">
              <.link
                navigate={~p"/settings"}
                class="text-accent dark:text-accent-light hover:underline"
              >
                Edit profile
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    metadata = user.metadata || %{}

    display_name =
      case user.username do
        name when is_binary(name) and name != "" -> name
        _ -> short_address(user.address)
      end

    {:ok,
     socket
     |> assign(:display_name, display_name)
     |> assign(:bio, Map.get(metadata, "bio"))
     |> assign(:photo_url, PhxMolbind.Accounts.avatar_url(user))}
  end

  defp short_address("0x" <> rest) do
    "0x" <> String.slice(rest, 0, 4) <> "…" <> String.slice(rest, -4, 4)
  end

  defp short_address(address), do: address
end
