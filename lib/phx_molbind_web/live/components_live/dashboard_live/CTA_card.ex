defmodule PhxMolbindWeb.ComponentsLive.DashboardLive.CTACard do
  use PhxMolbindWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="rounded-lg border border-stroke bg-white px-10 py-6 shadow-sm dark:border-[#181818] dark:bg-[#181818] ">
      <div class="flex h-11.5 w-11.5 items-center justify-center rounded-full bg-meta-2 dark:bg-meta-4">
        <.icon name={"hero-#{@icon}"} class="h-5 w-5" />
      </div>

      <div class="mt-4 flex items-end justify-between">
        <div>
          <h4 class="text-title-md font-semibold text-black dark:text-white">
            {@title}
          </h4>
           <span class="text-sm font-medium">{@subtitle}</span>
        </div>
      </div>

      <div class="mt-2 w-min cursor-pointer rounded-full bg-[#64748b] p-2">
        <span class=" text-sm text-white ">
          <.icon name="hero-arrow-right" />
        </span>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end
end
