defmodule PhxMolbind.EthAuth.AuthTest do
  use ExUnit.Case, async: false

  alias PhxMolbind.EthAuth.Auth
  alias PhxMolbind.EthSign.EthSignature

  # Real secp256k1 keypairs, freshly generated and cross-checked against
  # Python's `eth_account` (address derivation) so we know these actually
  # correspond to the addresses below, not just internally-consistent
  # values invented for this test.
  @private_key Base.decode16!(
                  "330227DFC4053FB5FD2FFA71EDD6D1A573162BF4035DC545796A0A03EBA194A4",
                  case: :mixed
                )
  @address "0xe62d9C2182e2aa59CAEf4844ddD846cACd4E22DA"

  # Signs `message` with @private_key exactly like personal_sign does,
  # using the audited libs directly (mirrors EthSignature.hash_message +
  # ExSecp256k1, but on the signing side instead of the recovery side).
  defp personal_sign(message) do
    {:ok, hash} = EthSignature.hash_message(message)
    {:ok, {r, s, recovery_id}} = ExSecp256k1.sign(hash, @private_key)
    "0x" <> Base.encode16(r <> s <> <<recovery_id + 27>>, case: :lower)
  end

  describe "nonce lifecycle" do
    test "verify_signature/2 fails when no nonce has been issued" do
      assert {:error, _} = Auth.verify_signature(@address, "0xdeadbeef")
    end

    test "generate_and_store_nonce/1 issues a fresh message each time" do
      message1 = Auth.generate_and_store_nonce(@address)
      message2 = Auth.generate_and_store_nonce(@address)
      assert message1 != message2
    end

    test "a real signature over the issued message verifies and recovers the signer" do
      message = Auth.generate_and_store_nonce(@address)
      signature = personal_sign(message)

      assert {:ok, %{address: recovered}} = Auth.verify_signature(@address, signature)
      assert String.downcase(recovered) == String.downcase(@address)
    end

    test "a nonce can only be used once (replay protection)" do
      message = Auth.generate_and_store_nonce(@address)
      signature = personal_sign(message)

      assert {:ok, _} = Auth.verify_signature(@address, signature)
      assert {:error, _} = Auth.verify_signature(@address, signature)
    end

    test "nonce lookup is not case-sensitive on the address" do
      # Regression test: the original implementation stored nonces keyed by
      # `String.downcase(address)` but then matched the ETS result against
      # `^address` (the original, possibly-mixed-case value) — so lookups
      # always failed for standard checksummed (mixed-case) addresses,
      # which is the normal address format wallets use.
      message = Auth.generate_and_store_nonce(@address)
      signature = personal_sign(message)

      assert {:ok, %{address: recovered}} =
               Auth.verify_signature(String.downcase(@address), signature)

      assert String.downcase(recovered) == String.downcase(@address)
    end

    test "a signature from the wrong wallet is rejected" do
      message = Auth.generate_and_store_nonce(@address)

      other_key =
        Base.decode16!(
          "11FEAA826AC949374B3DEFD00181B4642D2B853B06C83444932BD777516EF6A5",
          case: :mixed
        )

      {:ok, hash} = EthSignature.hash_message(message)
      {:ok, {r, s, recovery_id}} = ExSecp256k1.sign(hash, other_key)
      bad_signature = "0x" <> Base.encode16(r <> s <> <<recovery_id + 27>>, case: :lower)

      assert {:error, _} = Auth.verify_signature(@address, bad_signature)
    end
  end

  describe "login tickets" do
    test "create_login_ticket/1 mints a ticket that can be consumed exactly once" do
      ticket = Auth.create_login_ticket(123)
      assert {:ok, 123} = Auth.consume_login_ticket(ticket)
      assert :error = Auth.consume_login_ticket(ticket)
    end

    test "consume_login_ticket/1 rejects an unknown ticket" do
      assert :error = Auth.consume_login_ticket("not-a-real-ticket")
    end
  end
end
