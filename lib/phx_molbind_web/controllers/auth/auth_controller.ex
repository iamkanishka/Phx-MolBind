defmodule PhxMolbindWeb.Auth.AuthController do
  alias PhxMolbind.Auth.Auth
  use PhxMolbindWeb, :controller

  def nonce(conn, %{"address" => address}) do
    nonce = Auth.generate_and_store_nonce(address)
    json(conn, %{nonce: nonce})
  end

  def metamask(conn, %{"address" => address, "signature" => signature}) do
    IO.inspect(signature, label: "Signature")
    IO.inspect(address, label: "Address")
    # conn
    # |> fetch_session()   # 👈 **important**
    # |> put_session(:eth_address,  address) # 👈 Store the Ethereum address
    # |> json(%{status: "authenticated", address: signature})

    case Auth.verify_signature(address, signature) do
      # {:ok, user_info} ->
      #   # You can optionally create a session or a token here
      #   # json(conn, %{status: "authenticated", user: user_info})
      #   conn
      #   # 👈 Store the Ethereum address
      #   |> put_session(:eth_address, user_info.address)
      #   |> json(%{status: "authenticated", address: user_info.address})

      {:ok, %{address: address}} ->
        Auth.delete_nonce(address) # 👈 Delete the nonce after successful verification
        # Login the user, set session, etc
        conn
        # 👈 Store the Ethereum address
        |> put_session(:eth_address, address)

        json(conn, %{status: "authenticated"})

      {:error, reason} ->
        conn
        # 👈 **important**
        |> fetch_session()
        |> put_status(:unauthorized)
        |> json(%{error: reason})
    end
  end

  # case Auth.verify_signature(address, signature) do
  #   {:ok, %{address: _address}} ->
  #     :ets.delete(Auth.nonce_table(), String.downcase(address))
  #     # Login the user, set session, etc
  #     json(conn, %{status: "authenticated"})

  #   {:error, reason} ->
  #     conn
  #     |> put_status(401)
  #     |> json(%{error: reason})
  # end
end

# defmodule MyAppWeb.AuthController do
#   use MyAppWeb, :controller

#   alias :libsecp256k1, as: Secp256k1
#   require Logger

#   def verify(conn, %{"address" => address, "signature" => signature_hex}) do
#     case :ets.lookup(:wallet_nonces, address) do
#       [{^address, nonce}] ->
#         with {:ok, pubkey} <- recover_public_key(nonce, signature_hex),
#              {:ok, recovered_address} <- pubkey_to_address(pubkey),
#              true <- String.downcase(recovered_address) == String.downcase(address) do
#           json(conn, %{status: "ok"})
#         else
#           _ -> json(conn, %{error: "Unauthorized"}, status: 401)
#         end

#       _ ->
#         json(conn, %{error: "Nonce not found"}, status: 400)
#     end
#   end

#   defp recover_public_key(nonce, signature_hex) do
#     # 1. Prepare message
#     message = "\x19Ethereum Signed Message:\n#{String.length(nonce)}#{nonce}"

#     # 2. Hash with Keccak-256
#     msg_hash = Keccakf1600.hash_256(message)

#     # 3. Decode signature
#     <<r::binary-size(32), s::binary-size(32), v::unsigned-integer-size(8)>> =
#       Base.decode16!(signature_hex, case: :mixed)

#     v = if v >= 27, do: v - 27, else: v

#     # 4. Recover pubkey
#     case Secp256k1.recover_compact(msg_hash, <<r::binary, s::binary>>, v) do
#       {:ok, pubkey} -> {:ok, pubkey}
#       _ -> {:error, :invalid_signature}
#     end
#   end

#   defp pubkey_to_address(pubkey) do
#     # pubkey is 65 bytes: 0x04 || X || Y
#     # Ethereum address = last 20 bytes of keccak256(pubkey[1:])
#     pubkey_body = binary_part(pubkey, 1, 64)
#     hash = Keccakf1600.hash_256(pubkey_body)
#     address = "0x" <> Base.encode16(binary_part(hash, -20, 20), case: :lower)
#     {:ok, address}
#   end
# end
