defmodule PhxMolbindWeb.ComponentsLive.Sidebar.Sidebar do
  use PhxMolbindWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- <aside
        class={`fixed left-0 top-0 z-9999 flex h-screen w-72.5 flex-col overflow-y-hidden bg-black duration-300 ease-linear dark:bg-[#000000] lg:translate-x-0 ${
          sidebarOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div class="flex items-center justify-between gap-2 px-6 py-5.5 lg:py-6.5">
          <Link href="/">
            <div class="flex flex-row items-center justify-center space-x-2">
              <div class="ml-2 rounded-lg bg-[#3c4fe0] p-1">
                <Image
                  width={32}
                  height={32}
                  src={"/images/logo/dna.svg"}
                  alt="Logo"
                  priority
                />
              </div>
              <p class="text-xl font-semibold text-white">ProteinBind</p>
            </div>
          </Link>

          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            aria-controls="sidebar"
            class="block lg:hidden"
          >
            <ChevronLeft />
          </button>
        </div>

        <div class="no-scrollbar flex flex-col overflow-y-auto duration-300 ease-linear">
          <nav class="mt-5 px-4 py-4 lg:mt-9 lg:px-6">
            {menuGroups.map((group, groupIndex) => (
              <div key={groupIndex}>
                <h3 class="mb-4 ml-4 text-sm font-semibold text-bodydark2">
                  {group.name}
                </h3>


              </div>
            ))}
          </nav>
        </div>
      </aside> --%>
    """
  end
end
