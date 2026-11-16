defmodule PhxMolbindWeb.Router do
  use PhxMolbindWeb, :router

  import PhxMolbindWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhxMolbindWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  # Share links carry a secret in the URL: keep it out of Referer headers,
  # caches and search indexes.
  pipeline :share do
    plug :put_share_headers
  end

  defp put_share_headers(conn, _opts) do
    conn
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("x-robots-tag", "noindex, nofollow")
    |> put_resp_header("cache-control", "no-store")
  end

  ## Avatars (public, no session)

  scope "/", PhxMolbindWeb do
    get "/avatars/:name", AvatarController, :show
  end

  ## Public share links (no sign-in)

  scope "/", PhxMolbindWeb do
    pipe_through [:browser, :share]

    live_session :public_share do
      live "/s/:token", ShareLive.Show, :show
    end
  end

  ## Wallet sign-in

  scope "/", PhxMolbindWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{PhxMolbindWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/auth/sign-in", Auth.MetaMaskLogin, :new
    end
  end

  scope "/", PhxMolbindWeb do
    pipe_through :browser

    get "/__sandbox_login/:id", SandboxLoginController, :login

    # Exchanges a one-time ticket (minted by MetaMaskLogin after a verified
    # wallet signature) for a real session. This has to be a plain
    # controller action, not a LiveView route: LiveView sockets can't write
    # to the Plug session directly.
    get "/auth/session/:ticket", EthSessionController, :create
    delete "/auth/sign-out", EthSessionController, :delete
  end

  ## The app itself — everything below requires a signed-in wallet

  scope "/", PhxMolbindWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/account/export.json", AccountController, :export
    delete "/account", AccountController, :delete
    get "/history/:id/export.csv", ExportController, :run
    get "/collections/:id/export.csv", ExportController, :collection

    live_session :require_authenticated_user,
      on_mount: [{PhxMolbindWeb.UserAuth, :ensure_authenticated}] do
      live "/", DashboardLive.Dashboard, :home
      live "/molecule-bank", MoleculeBankLive.MoleculeBank, :home
      live "/model", ModelLive.Model, :home
      live "/history", HistoryLive.Index, :index
      live "/history/compare", HistoryLive.Compare, :compare
      live "/history/:id", HistoryLive.Show, :show
      live "/collections", CollectionsLive.Index, :index
      live "/collections/:id", CollectionsLive.Show, :show
      live "/research", ResearchLive.Research, :home
      live "/sketcher", MolsketcherLive.Molsketcher, :home
      live "/profile", ProfileLive.Profile, :home
      live "/settings", SettingsLive.Settings, :home
      live "/message", MessagesLive.Chat, :home
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phx_molbind, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhxMolbindWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
