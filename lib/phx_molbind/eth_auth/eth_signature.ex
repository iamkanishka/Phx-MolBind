defmodule PhxMolbind.EthSign.EthSignature do
  @moduledoc """
  Ethereum `personal_sign` message hashing and address recovery.

  This delegates the actual cryptography to audited NIFs instead of
  hand-rolled elliptic-curve math:

    * `ex_keccak` — Keccak-256 (already a transitive dependency via `ethers`,
      previously unused; the old code hashed with `:crypto.hash(:sha3_256,
      ...)`, which is NIST SHA3-256 — a *different* algorithm from Keccak-256
      with different padding, so it would never recover a real MetaMask
      signature to the correct address).
    * `ex_secp256k1` — wraps `libsecp256k1` (the same C library Bitcoin Core
      and go-ethereum use) for signature recovery, replacing a pure-Elixir
      implementation that had multiple correctness bugs.
  """

  @doc """
  Hashes `message` the way MetaMask's `personal_sign` does:

      keccak256("\\x19Ethereum Signed Message:\\n" <> byte_size(message) <> message)
  """
  @spec hash_message(binary()) :: {:ok, binary()}
  def hash_message(message) when is_binary(message) do
    prefix = "\x19Ethereum Signed Message:\n" <> Integer.to_string(byte_size(message))
    {:ok, ExKeccak.hash_256(prefix <> message)}
  end

  @doc """
  Recovers the checksummed Ethereum address that produced `signature` (the
  raw 65-byte `r || s || v` signature MetaMask returns) over `message_hash`.
  """
  @spec recover_address(binary(), binary()) ::
          {:ok, String.t()} | {:error, atom()}
  def recover_address(<<r::binary-size(32), s::binary-size(32), v>>, message_hash) do
    with {:ok, recovery_id} <- normalize_recovery_id(v),
         {:ok, pubkey} <- ExSecp256k1.recover(message_hash, r, s, recovery_id) do
      {:ok, Ethers.Utils.public_key_to_address(pubkey)}
    else
      {:error, _reason} -> {:error, :recovery_failed}
    end
  end

  def recover_address(_signature, _message_hash), do: {:error, :invalid_signature_length}

  # MetaMask/geth use 27/28. Some libraries emit the raw recovery id (0/1)
  # directly. EIP-155-style values (>=35) are for transaction signatures,
  # not personal_sign, but are handled defensively.
  defp normalize_recovery_id(v) when v in [27, 28], do: {:ok, v - 27}
  defp normalize_recovery_id(v) when v in [0, 1], do: {:ok, v}
  defp normalize_recovery_id(v) when is_integer(v) and v >= 35, do: {:ok, rem(v - 35, 2)}
  defp normalize_recovery_id(_v), do: {:error, :invalid_recovery_id}
end
