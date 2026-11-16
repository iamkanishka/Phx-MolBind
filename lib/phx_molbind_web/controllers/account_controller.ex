defmodule PhxMolbindWeb.AccountController do
  @moduledoc """
  Account-level actions that need a real HTTP request: downloading the data
  export and deleting the account (which must also clear the Plug session,
  something a LiveView socket cannot do).
  """
  use PhxMolbindWeb, :controller

  alias PhxMolbind.{Accounts, DataExport}
  alias PhxMolbindWeb.UserAuth

  def export(conn, _params) do
    json = conn.assigns.current_user |> DataExport.build() |> Jason.encode!(pretty: true)

    send_download(conn, {:binary, json},
      filename: "molbind-export-#{Date.utc_today()}.json",
      content_type: "application/json"
    )
  end

  @doc """
  Deletes the signed-in user's account. The caller must type their wallet
  address as confirmation; anything else leaves the account untouched.
  """
  def delete(conn, params) do
    user = conn.assigns.current_user

    typed =
      params |> Map.get("confirmation", "") |> to_string() |> String.trim() |> String.downcase()

    if typed == String.downcase(user.address) do
      case Accounts.delete_account(user) do
        {:ok, _user} ->
          conn
          |> put_flash(:info, "Your account and its data have been deleted.")
          |> UserAuth.log_out_user()

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Your account could not be deleted. Please try again.")
          |> redirect(to: ~p"/settings")
      end
    else
      conn
      |> put_flash(:error, "The address you typed does not match, so nothing was deleted.")
      |> redirect(to: ~p"/settings")
    end
  end
end
