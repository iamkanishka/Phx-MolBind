defmodule PhxMolbind.EthSign.EthSignatureTest do
  use ExUnit.Case, async: true

  alias PhxMolbind.EthSign.EthSignature

  # A real personal_sign vector, generated and independently cross-checked
  # with two separate Python libraries (eth_account and coincurve) against
  # the well-known Hardhat/Anvil default test private key
  # 0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318
  # so this test catches a wrong hashing/recovery algorithm, not just a
  # self-consistent round trip against our own code.
  @message "Hello world"
  @address "0x2c7536E3605D9C16a7a3D7b1898e529396a65c23"
  @signature_hex "0x7ed00b5cdc0714d137a2e2794b041486ee6b7eb7a19675220e8dfd89fdde2746203a707a004c6cabce6d47584d92cfc2f9729d3add5c2f2ba96f4613a7b9896c1c"

  describe "hash_message/1" do
    test "matches the Keccak-256 digest for a known message, independently computed" do
      {:ok, hash} = EthSignature.hash_message(@message)
      assert byte_size(hash) == 32

      assert Base.encode16(hash, case: :lower) ==
               "8144a6fa26be252b86456491fbcd43c1de7e022241845ffea1c3df066f7cfede"
    end
  end

  describe "recover_address/2" do
    test "recovers the correct address from a known-good personal_sign signature" do
      {:ok, hash} = EthSignature.hash_message(@message)
      "0x" <> hex = @signature_hex
      {:ok, sig_bin} = Base.decode16(hex, case: :mixed)

      assert {:ok, recovered} = EthSignature.recover_address(sig_bin, hash)
      assert String.downcase(recovered) == String.downcase(@address)
    end

    test "a signature over a different message does not recover the same address" do
      {:ok, wrong_hash} = EthSignature.hash_message("Hello world!")
      "0x" <> hex = @signature_hex
      {:ok, sig_bin} = Base.decode16(hex, case: :mixed)

      assert {:ok, recovered} = EthSignature.recover_address(sig_bin, wrong_hash)
      refute String.downcase(recovered) == String.downcase(@address)
    end

    test "rejects a malformed signature instead of crashing" do
      {:ok, hash} = EthSignature.hash_message(@message)

      assert {:error, :invalid_signature_length} =
               EthSignature.recover_address(<<1, 2, 3>>, hash)
    end
  end
end
