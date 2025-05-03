defmodule PhxMolbind.Auth.Auth do
  alias PhxMolbind.EthSign.EthSignature
  @nonce_table :nonce_store

  @spec start_link(any()) :: {:ok, %{}}
  def start_link(_opts) do
    :ets.new(@nonce_table, [:named_table, :public, :set])
    {:ok, %{}}
  end

  def generate_and_store_nonce(address) do
    IO.inspect(address, label: "generate_and_store_nonce")
    nonce = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    :ets.insert(@nonce_table, {String.downcase(address), nonce})
    nonce
  end

  def delete_nonce(address) do
    :ets.delete(@nonce_table, String.downcase(address))
  end

  def get_nonce(address) do
    case :ets.lookup(@nonce_table, String.downcase(address)) do
      [{^address, nonce}] -> {:ok, nonce}
      _ -> :error
    end
  end

  def verify_signature(address, signature_hex) do
    with {:ok, nonce} <- get_nonce(address),
         {:ok, sig_bin} <- decode_signature(signature_hex),
         {:ok, msg_hash} <- hash_message(nonce),
         {:ok, recovered_address} <- recover_address(sig_bin, msg_hash),
         true <- String.downcase(recovered_address) == String.downcase(address) do
      {:ok, %{address: recovered_address}}
    else
      _ -> {:error, "Invalid signature"}
    end
  end

  defp decode_signature("0x" <> hex) do
    {:ok, Base.decode16(hex, case: :mixed)}
  end

  # Sign a message on Metamask (or elsewhere)
  # 65 bytes signature

  defp hash_message(message) do
    {:ok, hash} = EthSignature.hash_message(message)
    {:ok, hash}
  end

  defp recover_address(signature, hash) do
    case EthSignature.recover_address(signature, hash) do
      {:ok, address} -> {:ok, address}
      {:error, reason} -> {:error, reason}
    end
  end

  # # Hash the message in Ethereum's special way
  # defp hash_message(message) do
  #   prefix = "\x19Ethereum Signed Message:\n" <> Integer.to_string(byte_size(message))
  #   full_msg = prefix <> message
  #   hash = Keccakf1600.hash_256(full_msg)  # Pure Elixir Keccak256
  #   {:ok, hash}
  # end

  # # Recover address from signature
  # defp recover_address(signature, hash) do
  #   <<r::binary-size(32), s::binary-size(32), v>> = signature

  #   v = case v do
  #     27 -> 0
  #     28 -> 1
  #     v when v in 0..1 -> v
  #   end

  #   case Secp256k1Elixir.recover_public_key(hash, <<r::binary, s::binary>>, v, :uncompressed) do
  #     {:ok, <<4, pubkey::binary-size(64)>>} ->
  #       <<x::binary-size(32), y::binary-size(32)>> = pubkey
  #       pubkey_no_prefix = <<x::binary, y::binary>>

  #       pubkey_hash = Keccakf1600.hash_256(pubkey_no_prefix)
  #       <<_::binary-size(12), addr::binary-size(20)>> = pubkey_hash
  #       {:ok, "0x" <> Base.encode16(addr, case: :lower)}

  #     _ ->
  #       {:error, :invalid_signature}
  #   end
  # end
end
