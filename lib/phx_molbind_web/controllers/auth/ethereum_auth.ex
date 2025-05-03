defmodule PhxMolbindWeb.Auth.EthereumAuth do
  alias Ethers.Utils
  require Logger

  @prefix "\x19Ethereum Signed Message:\n"

  def verify_signature(message, signature_hex, expected_address) do
    eth_message = @prefix <> Integer.to_string(byte_size(message)) <> message
    message_hash = ExKeccak.hash_256(eth_message)

    with {:ok, signature_bin} <- decode_signature(signature_hex),
         {:ok, recovered_pubkey} <- Utils.recover_public_key(message_hash, signature_bin),
         recovered_address <- Utils.public_key_to_address(recovered_pubkey),
         true <- String.downcase(recovered_address) == String.downcase(expected_address) do
      {:ok, recovered_address}
    else
      _ -> {:error, :invalid_signature}
    end
  end

  defp decode_signature("0x" <> hex), do: Base.decode16(hex, case: :mixed)
  defp decode_signature(_), do: {:error, :invalid_format}
end
