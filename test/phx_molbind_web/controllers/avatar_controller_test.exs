defmodule PhxMolbindWeb.AvatarControllerTest do
  use PhxMolbindWeb.ConnCase, async: true

  alias PhxMolbind.Avatars
  import PhxMolbind.ImageFixtures

  setup do
    on_exit(fn -> :ok end)
    :ok
  end

  test "serves a stored avatar publicly with locked-down headers", %{conn: conn} do
    {:ok, name} = Avatars.store(png())
    resp = get(conn, ~p"/avatars/#{name}")

    assert response(resp, 200) == png()
    assert get_resp_header(resp, "content-type") == ["image/png"]
    assert get_resp_header(resp, "x-content-type-options") == ["nosniff"]
    assert get_resp_header(resp, "content-security-policy") == ["default-src 'none'; sandbox"]
    assert get_resp_header(resp, "cache-control") == ["public, max-age=86400"]
    # No session or CSRF machinery for a public image.
    assert get_resp_header(resp, "set-cookie") == []

    Avatars.delete(name)
  end

  test "content type follows the stored format", %{conn: conn} do
    for {bytes, type} <- [{jpeg(), "image/jpeg"}, {gif(), "image/gif"}, {webp(), "image/webp"}] do
      {:ok, name} = Avatars.store(bytes)
      assert get(conn, ~p"/avatars/#{name}") |> get_resp_header("content-type") == [type]
      Avatars.delete(name)
    end
  end

  test "anything that is not a server-generated name is a 404", %{conn: conn} do
    missing = String.duplicate("ab", 16) <> ".png"

    for name <- [
          "..%2F..%2Fmix.exs",
          "mix.exs",
          "x.png",
          String.upcase(missing),
          String.duplicate("ab", 16) <> ".svg",
          missing
        ] do
      assert conn |> get("/avatars/" <> name) |> response(404)
    end
  end

  test "a file placed in the directory with a bad extension is still not served", %{conn: conn} do
    File.mkdir_p!(Avatars.dir())
    bad = String.duplicate("cd", 16) <> ".svg"
    File.write!(Path.join(Avatars.dir(), bad), svg())

    assert conn |> get("/avatars/" <> bad) |> response(404)
    File.rm!(Path.join(Avatars.dir(), bad))
  end
end
