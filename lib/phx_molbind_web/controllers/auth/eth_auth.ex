defmodule PhxMolbindWeb.Auth.EthAuth do
  alias ExKeccak
  require Logger

  @prefix "\x19Ethereum Signed Message:\n"

  def verify_signature(message, signature, expected_address) do
    message_hash = hash_message(message)

    with {:ok, recovered_address} <- recover_address(message_hash, signature),
         true <- String.downcase(recovered_address) == String.downcase(expected_address) do
      {:ok, recovered_address}
    else
      _ -> {:error, :invalid_signature}
    end
  end

  defp hash_message(message) do
    prefix = @prefix <> Integer.to_string(byte_size(message))
    full_message = prefix <> message
    ExKeccak.hash_256(full_message)
  end

  defp recover_address(message_hash, signature) do
    <<r::binary-size(32), s::binary-size(32), v_raw>> = Base.decode16!(signature, case: :mixed)
    v = if v_raw < 27, do: v_raw + 27, else: v_raw

    case ExSecp256k1.recover_compact(message_hash, <<r::binary, s::binary>>, v - 27) do
      {:ok, pubkey} ->
        <<_::binary-size(1), rest::binary>> = pubkey

        address =
          rest |> ExKeccak.hash_256() |> binary_part(-20, 20) |> Base.encode16(case: :lower)

        {:ok, "0x" <> address}

      _ ->
        {:error, :recovery_failed}
    end
  end
end
