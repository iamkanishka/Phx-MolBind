defmodule PhxMolbindWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  The "root" layout is a skeleton rendered as part of the application router.
  The "app" layout wraps every LiveView and renders the application shell
  (sidebar, top bar, command palette, flash messages) when a user is signed
  in. Signed-out pages, such as the wallet sign-in, render without a shell.

  Because the shell lives in the layout rather than in a LiveComponent that
  each page re-mounts, it persists across live navigations, can know the
  current path, and its mobile drawer is toggled client-side with
  `Phoenix.LiveView.JS` (no server round trip).
  """
  use PhxMolbindWeb, :html

  embed_templates "layouts/*"

  @nav_items [
    %{icon: "hero-squares-2x2", label: "Dashboard", route: "/", group: :main},
    %{icon: "hero-beaker", label: "Generate", route: "/model", group: :main},
    %{icon: "hero-magnifying-glass", label: "Research", route: "/research", group: :main},
    %{icon: "hero-clock", label: "History", route: "/history", group: :main},
    %{icon: "hero-folder", label: "Collections", route: "/collections", group: :main},
    %{icon: "hero-archive-box", label: "Molecule Bank", route: "/molecule-bank", group: :main},
    %{icon: "hero-pencil-square", label: "Sketcher", route: "/sketcher", group: :main},
    %{icon: "hero-chat-bubble-left-right", label: "Messages", route: "/message", group: :main},
    %{icon: "hero-user-circle", label: "Profile", route: "/profile", group: :account},
    %{icon: "hero-cog-6-tooth", label: "Settings", route: "/settings", group: :account}
  ]

  @doc "All navigation entries shown in the sidebar and the command palette."
  def nav_items, do: @nav_items

  @doc """
  Whether `route` is the active navigation entry for `current_path`.

  `/` only matches exactly; every other route also matches its sub-paths.
  """
  def active_route?(route, current_path) when is_binary(current_path) do
    cond do
      route == "/" -> current_path == "/"
      true -> current_path == route or String.starts_with?(current_path, route <> "/")
    end
  end

  def active_route?(_route, _current_path), do: false

  @doc "Label of the navigation entry for `current_path`, or nil."
  def current_label(current_path) do
    case Enum.find(@nav_items, &active_route?(&1.route, current_path)) do
      nil -> nil
      item -> item.label
    end
  end

  @doc "Shortens a wallet address to `0x1234…abcd`."
  def short_address(address) when is_binary(address) and byte_size(address) > 12 do
    String.slice(address, 0, 6) <> "…" <> String.slice(address, -4, 4)
  end

  def short_address(address) when is_binary(address), do: address
  def short_address(_), do: ""

  @doc "Display name for the signed-in user: username, else shortened address."
  def display_name(%{username: username}) when is_binary(username) and username != "",
    do: username

  def display_name(%{address: address}), do: short_address(address)
  def display_name(_), do: ""

  def open_sidebar do
    JS.remove_class("-translate-x-full", to: "#app-sidebar")
    |> JS.remove_class("hidden", to: "#app-sidebar-backdrop")
    |> JS.set_attribute({"aria-expanded", "true"}, to: "#sidebar-toggle")
    |> JS.focus_first(to: "#app-sidebar")
  end

  def close_sidebar do
    JS.add_class("-translate-x-full", to: "#app-sidebar")
    |> JS.add_class("hidden", to: "#app-sidebar-backdrop")
    |> JS.set_attribute({"aria-expanded", "false"}, to: "#sidebar-toggle")
  end

  attr :current_path, :string, required: true

  def sidebar(assigns) do
    ~H"""
    <div
      id="app-sidebar-backdrop"
      class="fixed inset-0 z-[9998] hidden bg-black/50 lg:hidden"
      phx-click={close_sidebar()}
      aria-hidden="true"
    >
    </div>
    <aside
      id="app-sidebar"
      aria-label="Primary"
      phx-window-keydown={close_sidebar()}
      phx-key="Escape"
      class="fixed left-0 top-0 z-[9999] flex h-screen w-72.5 -translate-x-full flex-col overflow-y-auto bg-boxdark-2 duration-300 ease-linear motion-reduce:transition-none lg:translate-x-0"
    >
      <div class="flex items-center justify-between gap-2 px-6 py-5.5 lg:py-6.5">
        <.link navigate={~p"/"} phx-click={close_sidebar()}>
          <div class="flex flex-row items-center gap-2.5">
            <img width="34" height="34" src={~p"/images/logo.png"} alt="" />
            <p class="font-display text-lg font-semibold leading-tight text-white">
              Phoenix<br /><span class="text-sm font-medium text-bodydark2">Molecule Research</span>
            </p>
          </div>
        </.link>

        <button
          type="button"
          phx-click={close_sidebar()}
          aria-label="Close navigation"
          class="block rounded-md p-1 text-bodydark1 hover:bg-white/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary lg:hidden"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>
      </div>

      <nav class="mt-5 px-4 py-4 lg:mt-9 lg:px-6" aria-label="Main">
        <ul class="mb-6 flex flex-col gap-2">
          <li :for={item <- nav_items()} :if={item.group == :main}>
            <.nav_link item={item} current_path={@current_path} />
          </li>
        </ul>
        <h3 class="mb-4 ml-4 text-xs font-semibold uppercase tracking-wide text-bodydark2">
          Account
        </h3>
        <ul class="mb-6 flex flex-col gap-2">
          <li :for={item <- nav_items()} :if={item.group == :account}>
            <.nav_link item={item} current_path={@current_path} />
          </li>
        </ul>
      </nav>
    </aside>
    """
  end

  attr :item, :map, required: true
  attr :current_path, :string, required: true

  defp nav_link(assigns) do
    assigns = assign(assigns, :active, active_route?(assigns.item.route, assigns.current_path))

    ~H"""
    <.link
      navigate={@item.route}
      phx-click={close_sidebar()}
      aria-current={if @active, do: "page"}
      class={[
        "group relative flex items-center gap-2.5 rounded-md px-4 py-2 text-bodydark1 duration-300 ease-in-out hover:bg-white/5 hover:text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary motion-reduce:transition-none",
        @active && "bg-primary/10 text-white"
      ]}
    >
      <.icon name={@item.icon} class={if @active, do: "size-5 text-accent-light", else: "size-5"} />
      <span>{@item.label}</span>
      <span :if={@active} class="sr-only">(current page)</span>
    </.link>
    """
  end

  attr :current_user, :map, required: true
  attr :current_path, :string, required: true
  attr :page_title, :any, default: nil

  def topbar(assigns) do
    ~H"""
    <header class="sticky top-0 z-999 flex w-full border-b border-stroke bg-white dark:border-strokedark dark:bg-[#121212]">
      <div class="flex min-w-0 flex-grow items-center justify-between gap-3 px-4 py-3 md:px-6 2xl:px-11">
        <div class="flex min-w-0 items-center gap-3">
          <button
            id="sidebar-toggle"
            type="button"
            phx-click={open_sidebar()}
            aria-controls="app-sidebar"
            aria-expanded="false"
            aria-label="Open navigation"
            class="rounded-md border border-stroke bg-white p-2 shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary dark:border-strokedark dark:bg-boxdark lg:hidden"
          >
            <.icon name="hero-bars-3" class="size-5" />
          </button>
          <h1 class="truncate font-display text-lg font-semibold text-black dark:text-white">
            {current_label(@current_path) || "Phoenix Molecule Research"}
          </h1>
        </div>

        <div class="flex shrink-0 items-center gap-2 sm:gap-3">
          <button
            type="button"
            phx-click={JS.dispatch("palette:open", to: "#command-palette")}
            aria-label="Open command palette"
            aria-keyshortcuts="Control+K Meta+K"
            class="flex items-center gap-2 rounded-md border border-stroke px-3 py-1.5 text-sm text-body hover:bg-gray-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary dark:border-strokedark dark:text-bodydark dark:hover:bg-white/5"
          >
            <.icon name="hero-magnifying-glass" class="size-4" />
            <span class="hidden sm:inline">Search</span>
            <kbd class="hidden rounded border border-stroke px-1.5 font-mono text-xs dark:border-strokedark sm:inline">
              Ctrl K
            </kbd>
          </button>

          <.link
            navigate={~p"/profile"}
            class="max-w-[7rem] shrink-0 truncate rounded-full sm:max-w-[10rem] border border-stroke px-3 py-1.5 font-mono text-xs text-black hover:bg-gray-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary dark:border-strokedark dark:text-white dark:hover:bg-white/5"
            title={@current_user.address}
          >
            {display_name(@current_user)}
          </.link>
        </div>
      </div>
    </header>
    """
  end

  attr :id, :string, default: "command-palette"

  @doc """
  Ctrl/Cmd+K navigation palette. It lists the real navigation entries as
  ordinary links inside a native `<dialog>` (focus trap and Escape come from
  the browser); the `CommandPalette` hook only filters and moves the highlight.
  """
  def command_palette(assigns) do
    ~H"""
    <dialog
      id={@id}
      phx-hook="CommandPalette"
      aria-label="Command palette"
      class="m-auto w-[min(32rem,calc(100vw-2rem))] rounded-lg border border-stroke bg-white p-0 text-black shadow-xl backdrop:bg-black/50 dark:border-strokedark dark:bg-boxdark dark:text-white"
    >
      <div class="border-b border-stroke p-3 dark:border-strokedark">
        <label for={"#{@id}-input"} class="sr-only">Jump to</label>
        <input
          id={"#{@id}-input"}
          type="text"
          autocomplete="off"
          placeholder="Jump to…"
          role="combobox"
          aria-expanded="true"
          aria-controls={"#{@id}-list"}
          class="w-full rounded-md border border-stroke bg-transparent px-3 py-2 focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary dark:border-strokedark"
        />
      </div>
      <ul id={"#{@id}-list"} role="listbox" class="max-h-72 overflow-y-auto p-2">
        <li :for={item <- nav_items()} role="presentation" data-label={String.downcase(item.label)}>
          <.link
            navigate={item.route}
            role="option"
            data-palette-item
            class="flex items-center gap-3 rounded-md px-3 py-2 hover:bg-gray-2 aria-selected:bg-primary/10 dark:hover:bg-white/5"
          >
            <.icon name={item.icon} class="size-5" />
            <span>{item.label}</span>
          </.link>
        </li>
        <li data-palette-empty class="hidden px-3 py-2 text-sm text-body dark:text-bodydark">
          No matching pages.
        </li>
      </ul>
    </dialog>
    """
  end
end
