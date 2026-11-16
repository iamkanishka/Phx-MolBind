defmodule PhxMolbindWeb.EthSessionController do
  use PhxMolbindWeb, :controller

  alias PhxMolbind.Accounts
  alias PhxMolbind.EthAuth.Auth
  alias PhxMolbindWeb.UserAuth

  @doc """
  Exchanges a one-time login ticket (minted by `PhxMolbindWeb.Auth.MetaMaskLogin`
  after a verified wallet signature) for a real session.

  LiveView sockets can't write to the Plug session directly, so the
  LiveView performs a full-page redirect here once the signature has
  checked out; this action is what actually calls `log_in_user/2` and sets
  the session cookie.
  """
  def create(conn, %{"ticket" => ticket}) do
    with {:ok, user_id} <- Auth.consume_login_ticket(ticket),
         %Accounts.User{} = user <- Accounts.get_user(user_id) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user)
    else
      _ ->
        conn
        |> put_flash(:error, "That sign-in link is invalid or has expired. Please try again.")
        |> redirect(to: ~p"/auth/sign-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
