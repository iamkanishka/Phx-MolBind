defmodule PhxMolbindWeb.ProfileLive.Profile do
  use PhxMolbindWeb, :live_view

  def render(assigns) do
    ~H"""
    <.live_component module={PhxMolbindWeb.ComponentsLive.MainLayout} id={:main_layout}>
      <div class="mx-auto max-w-[970px]">
        <div class="overflow-hidden rounded-lg border border-stroke bg-white shadow-default dark:border-strokedark dark:bg-boxdark">
          <div class="relative z-20 h-[140px] md:h-[260px]">
            <img
              src="https://www.shutterstock.com/image-photo/medical-technology-genetics-science-pharmaceutical-260nw-2430491931.jpg"
              alt="profile cover"
              class="h-full w-full rounded-tl-sm rounded-tr-sm object-cover object-center"
              width="970"
              height="260"
            />
          </div>

          <div class="px-4 pb-6 text-center lg:pb-8 xl:pb-[46px]">
            <div class="relative z-30 mx-auto -mt-[88px] h-[120px] w-full max-w-[120px] rounded-full bg-white/20 p-1 backdrop-blur sm:h-[176px] sm:max-w-[176px] sm:p-3">
              <div class="relative drop-shadow-2">
                <img src={@user.photo} alt="profile" class="rounded-full" width="160" height="160" />
                <label
                  for="profile"
                  class="absolute bottom-0 right-0 flex h-[34px] w-[34px] cursor-pointer items-center justify-center rounded-full bg-primary text-white hover:bg-opacity-90 sm:bottom-2 sm:right-2"
                >
                  <.icon name="hero-camera" class="h-5 w-5" />
                  <input type="file" name="profile" id="profile" class="sr-only" />
                </label>
              </div>
            </div>

            <div class="mt-4">
              <h3 class="mb-1.5 text-2xl font-semibold text-black dark:text-white">
                {@user.first_name} {@user.last_name}
              </h3>

              <p class="font-medium">Drug Researcher</p>

              <div class="mx-auto mb-[22px] mt-[18px] grid w-max grid-cols-1 rounded-md border border-stroke py-2.5 shadow-1 dark:border-strokedark dark:bg-[#37404F]">
                <div class="flex flex-col items-center justify-center gap-1 border-r border-stroke px-4 dark:border-strokedark xsm:flex-row">
                  <span class="font-semibold text-black dark:text-white">259</span>
                  <span class="text-sm">Contributions</span>
                </div>
              </div>

              <div class="mx-auto max-w-[720px]">
                <h4 class="font-semibold text-black dark:text-white">About Me</h4>

                <p class="mt-[18px]">{@user.user_bio}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.live_component>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:user, %{
       first_name: "John",
       last_name: "Doe",
       user_bio: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
       photo: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSNReL6xDGucbtDRXCHl83TK0fO3lTbLw8NuA&s"
     })}
  end
end
