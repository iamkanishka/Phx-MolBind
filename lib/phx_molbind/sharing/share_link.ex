defmodule PhxMolbind.Sharing.ShareLink do
  @moduledoc "A revocable, optionally expiring, read-only link to one run or collection."
  use Ecto.Schema

  @kinds ~w(run collection)

  schema "share_links" do
    field :kind, :string
    field :target_id, :integer
    field :token_hash, :string
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :user, PhxMolbind.Accounts.User

    timestamps()
  end

  def kinds, do: @kinds

  @doc "active = not revoked and not expired."
  def active?(%__MODULE__{revoked_at: revoked, expires_at: expires}, now \\ DateTime.utc_now()) do
    is_nil(revoked) and (is_nil(expires) or DateTime.compare(expires, now) == :gt)
  end
end
