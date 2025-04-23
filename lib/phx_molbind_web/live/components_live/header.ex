defmodule PhxMolbindWeb.ComponentsLive.Header do
  use PhxMolbindWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <header class="sticky top-0 z-999 flex w-full bg-white drop-shadow-1 dark:bg-[#121212] dark:drop-shadow-xl">
      <div class="flex flex-grow items-center justify-between px-4 py-4 shadow-2 md:px-6 2xl:px-11">

    <!-- Sidebar toggle button (Mobile) -->
        <div class="flex items-center gap-2 sm:gap-4 lg:hidden">
          <button
            phx-click="toggle_sidebar"
            class="z-99999 block rounded-sm border border-stroke bg-white p-1.5 shadow-sm dark:border-strokedark dark:bg-boxdark lg:hidden"
          >
            <span class="relative block h-5.5 w-5.5 cursor-pointer">
              <span class="du-block absolute right-0 h-full w-full">
                <span class={
                "relative left-0 top-0 my-1 block h-0.5 w-0 rounded-sm bg-black delay-[0] duration-200 ease-in-out dark:bg-white" <>
                if !@sidebar_open, do: "!w-full delay-300", else: ""
              } />
                <span class={
                "relative left-0 top-0 my-1 block h-0.5 w-0 rounded-sm bg-black delay-150 duration-200 ease-in-out dark:bg-white" <>
                if !@sidebar_open, do: "delay-400 !w-full" , else: ""
              } />
                <span class={
                "relative left-0 top-0 my-1 block h-0.5 w-0 rounded-sm bg-black delay-200 duration-200 ease-in-out dark:bg-white" <>
                if !@sidebar_open, do: "!w-full delay-500", else: ""
              } />
              </span>

              <span class="absolute right-0 h-full w-full rotate-45">
                <span class={
                "absolute left-2.5 top-0 block h-full w-0.5 rounded-sm bg-black delay-300 duration-200 ease-in-out dark:bg-white" <>
                if !@sidebar_open, do: "!h-0 !delay-[0]", else: ""
              } />
                <span class={
                "delay-400 absolute left-0 top-2.5 block h-0.5 w-full rounded-sm bg-black duration-200 ease-in-out dark:bg-white" <>
                if !@sidebar_open, do: "!h-0 !delay-200", else: ""
              } />
              </span>
            </span>
          </button>
        </div>

        <%!--
    <!-- Search Box -->
    <div class="hidden sm:block">
      <form action="https://formbold.com/s/unique_form_id" method="POST">
        <div class="relative">
          <button class="absolute left-0 top-1/2 -translate-y-1/2">
            <%= live_component @socket, MyAppWeb.Icons.SearchIcon %>
          </button>
          <input
            type="text"
            placeholder="Type to search..."
            class="w-full bg-transparent pl-9 pr-4 font-medium focus:outline-none xl:w-125"
          />
        </div>
      </form>
    </div>

    <!-- Icons & Dropdowns -->
    <div class="flex items-center gap-3 2xsm:gap-7">
      <ul class="flex items-center gap-2 2xsm:gap-4">
        <%= live_component @socket, MyAppWeb.Components.DropdownMessage %>
      </ul>

      <%= live_component @socket, MyAppWeb.Components.DropdownUser %>
    </div>
    </div>

    --%>
      </div>
    </header>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end
end
