defmodule PhxMolbindWeb.Auth.EthAuthController do
  use PhxMolbindWeb, :controller
  alias PhxMolbind.Accounts.Accounts
  alias PhxMolbind.Accounts.User
  alias PhxMolbindWeb.Auth.EthereumAuth

  def get_nonce(conn, %{"address" => address}) do
    nonce = generate_nonce()

    {:ok, user} =
      case Accounts.get_user_by_address(address) do
        nil -> Accounts.create_user(%{address: address, nonce: nonce})
        user -> Accounts.update_user(user, %{nonce: nonce})
      end

    json(conn, %{nonce: user.nonce})
  end

  def login(conn, %{"address" => address, "signature" => signature}) do
    with %User{nonce: nonce} = user <- Accounts.get_user_by_address(address),
         {:ok, _} <- EthereumAuth.verify_signature("Login nonce: #{nonce}", signature, address),
         {:ok, _user} <- Accounts.update_user(user, %{nonce: generate_nonce()}) do
      conn
      |> put_session(:user_id, user.id)
      |> json(%{message: "Logged in", address: address})
    else
      _ -> conn |> put_status(:unauthorized) |> json(%{error: "Invalid signature"})
    end
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> json(%{message: "Logged out"})
  end

  defp generate_nonce, do: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
end
