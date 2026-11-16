defmodule PhxMolbindWeb.AvatarController do
  @moduledoc """
  Serves uploaded avatars. Public by design (avatars are shown to other users
  in chat), but only names that exactly match the server-generated shape are
  honoured, and the response is locked down so an uploaded file can never be
  interpreted as anything but an inert image.
  """
  use PhxMolbindWeb, :controller

  alias PhxMolbind.Avatars

  def show(conn, %{"name" => name}) do
    with true <- Avatars.valid_name?(name),
         path when is_binary(path) <- Avatars.path(name),
         true <- File.regular?(path) do
      conn
      |> put_resp_content_type(Avatars.content_type(name), nil)
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("content-security-policy", "default-src 'none'; sandbox")
      # Names are random and change with every upload, but a *removed* picture
      # should stop showing up reasonably soon in other people's caches, so
      # the lifetime is one day rather than "immutable for a year".
      |> put_resp_header("cache-control", "public, max-age=86400")
      |> send_file(200, path)
    else
      _ -> conn |> put_status(:not_found) |> text("Not found")
    end
  end
end
