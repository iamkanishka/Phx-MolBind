defmodule PhxMolbind.Accounts.User do
  @moduledoc """
  A wallet-authenticated user.

  Users are identified by their Ethereum address (lowercased on write, see
  `changeset/2`). There is no password: identity is proven by signing a
  server-issued nonce with the wallet's private key — see
  `PhxMolbind.EthAuth.Auth`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :address, :string
    field :username, :string
    field :metadata, :map, default: %{}
    field :last_login_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:address, :username, :metadata, :last_login_at])
    |> validate_required([:address])
    |> update_change(:address, &normalize_address/1)
    |> validate_format(:address, ~r/^0x[0-9a-f]{40}$/,
      message: "must be a valid Ethereum address"
    )
    |> unique_constraint(:address)
  end

  @doc """
  Changeset for user-edited profile fields only. Stricter than `changeset/2`
  on purpose: `changeset/2` also runs on every login, and tightening it could
  lock out users whose previously stored profile data predates these rules.
  """
  def profile_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> validate_length(:username, max: 40)
    |> validate_profile_metadata()
  end

  # Bio and photo_url live in free-form metadata, so bound them here. The
  # photo URL is rendered as an <img src>, so only http(s) URLs are accepted.
  defp validate_profile_metadata(changeset) do
    case get_field(changeset, :metadata) do
      %{} = metadata ->
        changeset
        |> validate_bio(Map.get(metadata, "bio"))
        |> validate_photo_url(Map.get(metadata, "photo_url"))

      _ ->
        changeset
    end
  end

  defp validate_bio(changeset, bio) when is_binary(bio) and byte_size(bio) > 500,
    do: add_error(changeset, :metadata, "bio must be at most 500 characters")

  defp validate_bio(changeset, _), do: changeset

  defp validate_photo_url(changeset, url) when is_binary(url) and url != "" do
    uri = URI.parse(url)

    if byte_size(url) <= 2048 and uri.scheme in ["http", "https"] and is_binary(uri.host) and
         uri.host != "" do
      changeset
    else
      add_error(changeset, :metadata, "photo URL must be a valid http(s) address")
    end
  end

  defp validate_photo_url(changeset, _), do: changeset

  defp normalize_address(address) when is_binary(address), do: String.downcase(address)
  defp normalize_address(address), do: address
end
