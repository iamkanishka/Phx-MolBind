defmodule PhxMolbind.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
alias PhxMolbind.EthAuth.Auth

  use Application

  @impl true
  def start(_type, _args) do
    Auth.start_link([])
    children = [
      PhxMolbindWeb.Telemetry,
      PhxMolbind.Repo,
      {DNSCluster, query: Application.get_env(:phx_molbind, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhxMolbind.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: PhxMolbind.Finch},
      # Start a worker by calling: PhxMolbind.Worker.start_link(arg)
      # {PhxMolbind.Worker, arg},
      # Start to serve requests, typically the last entry
      PhxMolbindWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhxMolbind.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxMolbindWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
