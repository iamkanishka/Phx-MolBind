defmodule PhxMolbind.EthAuth.Auth do
  @moduledoc """
  Wallet sign-in: nonce issuance + signature verification.

  Flow:

    1. Client asks for a nonce for their address (`generate_and_store_nonce/1`).
    2. Client signs a message containing that nonce via MetaMask's
       `personal_sign`.
    3. Server verifies the signature recovers to the claimed address
       (`verify_signature/2`) and, on success, mints a short-lived one-time
       login ticket (`create_login_ticket/1`). A plain HTTP redirect
       exchanges the ticket for a real session — LiveView sockets can't
       write to the Plug session directly, so this hand-off happens through
       `PhxMolbindWeb.EthSessionController`.

  Nonces and tickets live in ETS tables owned by this GenServer, so their
  lifetime is tied to the supervision tree (previously `start_link/1` was
  invoked as a bare function call from `Application.start/2`, outside the
  supervisor's children list, which is not how OTP processes are meant to be
  started).
  """
  use GenServer

  alias PhxMolbind.EthSign.EthSignature

  @nonce_table :eth_auth_nonce_store
  @ticket_table :eth_auth_login_ticket_store

  # How long a client has to sign the nonce and send it back.
  @nonce_ttl_seconds 300
  # How long the LiveView -> controller hand-off redirect has to complete.
  @ticket_ttl_seconds 60

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    :ets.new(@nonce_table, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(@ticket_table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  @doc """
  Issues a fresh, single-use nonce for `address`, stores it with an expiry,
  and returns the exact message the client must sign with `personal_sign`.
  Verification hashes this same message format — see `message_for_nonce/1`
  — so the signed text and the verified text can never drift apart.
  """
  def generate_and_store_nonce(address) do
    nonce = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    :ets.insert(@nonce_table, {normalize(address), nonce, expires_at(@nonce_ttl_seconds)})
    message_for_nonce(nonce)
  end

  @doc """
  Verifies that `signature_hex` is a valid `personal_sign` signature, by
  `address`, over the nonce previously issued for that address. The nonce is
  consumed (deleted) on success so it cannot be replayed.
  """
  def verify_signature(address, signature_hex) do
    key = normalize(address)

    with {:ok, nonce} <- fetch_valid_nonce(key),
         {:ok, sig_bin} <- decode_signature(signature_hex),
         {:ok, msg_hash} <- EthSignature.hash_message(message_for_nonce(nonce)),
         {:ok, recovered} <- EthSignature.recover_address(sig_bin, msg_hash),
         true <- normalize(recovered) == key do
      :ets.delete(@nonce_table, key)
      {:ok, %{address: recovered}}
    else
      # Distinct message so the UI can tell the user to restart sign-in
      # instead of blaming their signature. Still an {:error, _} tuple.
      {:error, :nonce_expired} -> {:error, "Sign-in request expired"}
      _ -> {:error, "Invalid signature"}
    end
  end

  @doc "Mints a one-time ticket that exchanges for a real session."
  def create_login_ticket(user_id) do
    ticket = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    :ets.insert(@ticket_table, {ticket, user_id, expires_at(@ticket_ttl_seconds)})
    ticket
  end

  @doc "Consumes (single-use) a login ticket, returning the associated user id."
  def consume_login_ticket(ticket) do
    case :ets.take(@ticket_table, ticket) do
      [{^ticket, user_id, expiry}] -> if fresh?(expiry), do: {:ok, user_id}, else: :error
      [] -> :error
    end
  end

  defp fetch_valid_nonce(key) do
    case :ets.lookup(@nonce_table, key) do
      [{^key, nonce, expiry}] ->
        if fresh?(expiry), do: {:ok, nonce}, else: {:error, :nonce_expired}

      [] ->
        {:error, :nonce_expired}
    end
  end

  defp decode_signature("0x" <> hex), do: Base.decode16(hex, case: :mixed)
  defp decode_signature(_), do: :error

  defp normalize(address) when is_binary(address), do: String.downcase(address)

  defp expires_at(ttl_seconds), do: System.system_time(:second) + ttl_seconds
  defp fresh?(expiry), do: System.system_time(:second) <= expiry

  # Single source of truth for the exact text a wallet signs, so the
  # message shown to the user and the message verified server-side can
  # never drift apart.
  defp message_for_nonce(nonce) do
    """
    Sign this message to log in to Phoenix Molecule Research.

    This request will not trigger a blockchain transaction or cost any gas.

    Nonce: #{nonce}
    """
  end
end
