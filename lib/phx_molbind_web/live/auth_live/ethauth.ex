defmodule PhxMolbindWeb.AuthLive.Ethauth do
  alias Ethers.Signature
  alias Ethers.Ethereum

  def verify_signature(message, signature, expected_address) do
    message_hash = hash_personal_message(message)

    with {:ok, recovered_address} <- Signature.recover_address(signature, message_hash) do
      String.downcase(recovered_address) == String.downcase(expected_address)
    else
      _ -> false
    end
  end

  defp hash_personal_message(message) do
    prefix = "\x19Ethereum Signed Message:\n#{byte_size(message)}"
    full_message = prefix <> message
    hash = :ex_keccak.hash_256(full_message)
    Ethereum.hex_prefix(hash)
  end
end
