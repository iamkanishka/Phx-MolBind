defmodule PhxMolbind.EthSign.EthSignature do
  @moduledoc """
  Pure Elixir Ethereum signature verification and address recovery.

  ✅ No dependencies.
  ✅ Works with standard Ethereum signatures (r, s, v).
  """

  @secp_p 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
  @secp_n 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
  @secp_gx 55_066_263_022_277_343_669_578_718_895_168_534_326_250_603_453_777_594_175_500_187_360_389_116_729_240
  @secp_gy 32_670_510_020_758_816_978_083_085_130_507_043_184_471_273_380_659_243_275_938_904_335_757_337_482_424
  @g {@secp_gx, @secp_gy}

  @doc """
  Hash a message as per Ethereum ("\\x19Ethereum Signed Message:\\n" + len + message).

  Returns: `{:ok, hashed_message}`
  """
  def hash_message(message) do
    prefix = "\x19Ethereum Signed Message:\n" <> Integer.to_string(byte_size(message))
    full_msg = prefix <> message
    hash = :crypto.hash(:sha3_256, full_msg)
    {:ok, hash}
  end

  @spec recover_address(<<_::520>>, any()) ::
          {:error, :decompression_failed | :invalid_recovery_id}
  @doc """
  Recovers the Ethereum address from a signature and a hashed message.

  Returns: `{:ok, "0x..."}` or `{:error, reason}`
  """
  def recover_address(signature, message_hash) do
    <<r::binary-size(32), s::binary-size(32), v>> = signature

    recovery_id =
      cond do
        v in [27, 28] -> v - 27
        v in 0..1 -> v
        v >= 35 -> rem(v - 35, 2)
        true -> :invalid
      end

    if recovery_id == :invalid do
      {:error, :invalid_recovery_id}
    else
      with {:ok, pubkey} <- recover_public_key(message_hash, r, s, recovery_id) do
        <<4, pubkey_xy::binary>> = pubkey
        pubkey_hash = :crypto.hash(:sha3_256, pubkey_xy)
        <<_::binary-size(12), addr::binary-size(20)>> = pubkey_hash
        {:ok, "0x" <> Base.encode16(addr, case: :lower)}
      end
    end
  end

  ## --- Internal ECC math ---

  defp recover_public_key(msg_hash, r_bin, s_bin, v) do
    r = :binary.decode_unsigned(r_bin)
    s = :binary.decode_unsigned(s_bin)

    x = r + v * @secp_n
    if x >= @secp_p, do: {:error, :x_too_big}, else: :ok

    case decompress_point(x, rem(v, 2)) do
      {:ok, R} ->
        e = :binary.decode_unsigned(msg_hash)
        r_inv = mod_inv(r, @secp_n)
        sR = point_mul(s, R)
        eG = point_mul(e, @g)
        neg_eG = {elem(eG, 0), @secp_p - elem(eG, 1)}
        pubkey_point = point_mul(r_inv, point_add(sR, neg_eG))
        {:ok, encode_uncompressed(pubkey_point)}

      _ ->
        {:error, :decompression_failed}
    end
  end

  defp decompress_point(x, y_parity) do
    y2 = rem(x * x * x + 7, @secp_p)
    y = mod_sqrt(y2, @secp_p)

    cond do
      y == nil -> {:error, :no_square_root}
      rem(y, 2) == y_parity -> {:ok, {x, y}}
      true -> {:ok, {x, @secp_p - y}}
    end
  end

  ## --- Modular math ---

  defp mod_inv(x, m) do
    {g, inv, _} = extended_gcd(x, m)
    if g != 1, do: raise("modular inverse does not exist"), else: rem(inv + m, m)
  end

  defp extended_gcd(0, b), do: {b, 0, 1}

  defp extended_gcd(a, b) do
    {g, y, x} = extended_gcd(rem(b, a), a)
    {g, x - div(b, a) * y, y}
  end

  defp mod_sqrt(a, p) do
    case pow(a, div(p + 1, 4), p) do
      x when rem(x * x, p) == rem(a, p) -> x
      _ -> nil
    end
  end

  defp pow(_a, 0, _p), do: 1

  defp pow(a, e, p) do
    cond do
      rem(e, 2) == 1 ->
        rem(a * pow(a, e - 1, p), p)

      true ->
        half = pow(a, div(e, 2), p)
        rem(half * half, p)
    end
  end

  ## --- Elliptic curve math ---

  defp point_add({x1, y1}, {x2, y2}) do
    cond do
      x1 == :infinity ->
        {x2, y2}

      x2 == :infinity ->
        {x1, y1}

      x1 == x2 and rem(y1 + y2, @secp_p) == 0 ->
        :infinity

      true ->
        s =
          if x1 == x2 do
            (rem(3 * x1 * x1, @secp_p) * mod_inv(2 * y1, @secp_p)) |> rem(@secp_p)
          else
            (rem(y2 - y1, @secp_p) * mod_inv(rem(x2 - x1, @secp_p), @secp_p)) |> rem(@secp_p)
          end

        x3 = rem(s * s - x1 - x2, @secp_p)
        y3 = rem(s * (x1 - x3) - y1, @secp_p)
        {x3, y3}
    end
  end

  defp point_mul(k, point), do: do_point_mul(k, point, :infinity)

  defp do_point_mul(0, _p, acc), do: acc

  defp do_point_mul(k, p, acc) do
    acc = if rem(k, 2) == 1, do: point_add(acc, p), else: acc
    do_point_mul(div(k, 2), point_add(p, p), acc)
  end

  defp encode_uncompressed({x, y}) do
    <<4, pad32(x)::binary, pad32(y)::binary>>
  end

  defp pad32(val) do
    bin = :binary.encode_unsigned(val)
    String.pad_leading(bin, 32, <<0>>)
  end
end
