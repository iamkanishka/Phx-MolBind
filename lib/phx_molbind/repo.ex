defmodule PhxMolbind.Repo do
  use Ecto.Repo,
    otp_app: :phx_molbind,
    adapter: Ecto.Adapters.Postgres
end
