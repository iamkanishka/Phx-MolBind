defmodule PhxMolbindWeb.ProfileLive.Profile do
  use PhxMolbindWeb, :live_view

  def render(assigns) do
    ~H"""
       <DefaultLayout>
      <div class="mx-auto max-w-242.5">
        <Breadcrumb pageName="Profile" containActionButton={false} />

        <div class="overflow-hidden rounded-lg border border-stroke bg-white shadow-default dark:border-strokedark dark:bg-boxdark">
          <div class="relative z-20 h-35 md:h-65">
            <Image
              src={"/images/cover/cover-01.png"}
              alt="profile cover"
              class="h-full w-full rounded-tl-sm rounded-tr-sm object-cover object-center"
              width={970}
              height={260}
              style={{
                width: "auto",
                height: "auto",
              }}
            />
          </div>
          <div class="px-4 pb-6 text-center lg:pb-8 xl:pb-11.5">
            <div class="relative z-30 mx-auto -mt-22 h-30 w-full max-w-30 rounded-full bg-white/20 p-1 backdrop-blur sm:h-44 sm:max-w-44 sm:p-3">
              <div class="relative drop-shadow-2">
                <Image
                  src={user.photo}
                  width={160}
                  class="rounded-full"
                  height={160}
                  style={{
                    width: "auto",
                    height: "auto",
                  }}
                  alt="profile"
                />
                <label
                  htmlFor="profile"
                  class="absolute bottom-0 right-0 flex h-8.5 w-8.5 cursor-pointer items-center justify-center rounded-full bg-primary text-white hover:bg-opacity-90 sm:bottom-2 sm:right-2"
                >
                  <CameraIcon size={22} />
                  <input
                    type="file"
                    name="profile"
                    id="profile"
                    class="sr-only"
                  />
                </label>
              </div>
            </div>
            <div class="mt-4">
              <h3 class="mb-1.5 text-2xl font-semibold text-black dark:text-white">
                {user.firstName} {user.lastName}
              </h3>
              <p class="font-medium">Drug Researcher</p>
              <div class="mx-auto mb-5.5 mt-4.5 grid  w-max grid-cols-1 rounded-md border border-stroke py-2.5 shadow-1 dark:border-strokedark dark:bg-[#37404F]">
                <div class="flex flex-col items-center justify-center gap-1 border-r border-stroke px-4 dark:border-strokedark xsm:flex-row">
                  <span class="font-semibold text-black dark:text-white">
                    259
                  </span>
                  <span class="text-sm">Contributions</span>
                </div>
              </div>

              <div class="mx-auto max-w-180">
                <h4 class="font-semibold text-black dark:text-white">
                  About Me
                </h4>
                <p class="mt-4.5">{user.userBio}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </DefaultLayout>

    """
  end

  def mount(params, session, socket) do
    {:ok, socket}
  end
end
