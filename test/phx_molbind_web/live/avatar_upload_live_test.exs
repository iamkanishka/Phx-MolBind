defmodule PhxMolbindWeb.AvatarUploadLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PhxMolbind.ImageFixtures

  alias PhxMolbind.{Accounts, Avatars}

  setup :register_and_log_in_user

  defp pick(view, name, content, type \\ "image/png") do
    file_input(view, "#avatar-form", :avatar, [%{name: name, content: content, type: type}])
  end

  test "uploading a real image saves it, shows it, and appears on the profile", %{
    conn: conn,
    user: user
  } do
    {:ok, view, html} = live(conn, ~p"/settings")
    assert html =~ "No picture"

    input = pick(view, "me.png", png())
    assert render_upload(input, "me.png") =~ "Upload picture"
    html = view |> form("#avatar-form") |> render_submit()

    assert html =~ "Profile picture updated."
    assert html =~ ~s(id="current-avatar")
    name = user.id |> Accounts.get_user() |> Accounts.avatar_name()
    assert name && File.exists?(Path.join(Avatars.dir(), name))

    {:ok, _view, profile} = live(conn, ~p"/profile")
    assert profile =~ "/avatars/" <> name

    Avatars.delete(name)
  end

  test "a file that only claims to be a PNG is rejected and nothing is stored", %{
    conn: conn,
    user: user
  } do
    {:ok, view, _} = live(conn, ~p"/settings")
    input = pick(view, "innocent.png", html())
    render_upload(input, "innocent.png")
    html = view |> form("#avatar-form") |> render_submit()

    assert html =~ "not a PNG, JPEG, GIF or WebP image"
    assert Accounts.avatar_name(Accounts.get_user(user.id)) == nil
  end

  test "SVG is rejected even with an image extension and content type", %{conn: conn, user: user} do
    {:ok, view, _} = live(conn, ~p"/settings")
    input = pick(view, "logo.png", svg(), "image/svg+xml")
    render_upload(input, "logo.png")
    html = view |> form("#avatar-form") |> render_submit()

    assert html =~ "not a PNG, JPEG, GIF or WebP image"
    assert Accounts.avatar_name(Accounts.get_user(user.id)) == nil
  end

  test "wrong extensions and oversized files are refused before upload", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/settings")

    exe = pick(view, "payload.exe", png(), "application/x-msdownload")
    assert {:error, [[_, :not_accepted]]} = render_upload(exe, "payload.exe")

    {:ok, view, _} = live(conn, ~p"/settings")
    big = pick(view, "big.png", png() <> :binary.copy(<<0>>, Avatars.max_bytes()))
    assert {:error, [[_, :too_large]]} = render_upload(big, "big.png")
  end

  test "the client's file name and type never decide what is stored", %{conn: conn, user: user} do
    # LiveView's `accept` is advisory (a matching mime type is enough), so the
    # real guarantees come from the magic-byte check and the generated name.
    {:ok, view, _} = live(conn, ~p"/settings")
    input = pick(view, "../../evil.exe", png(), "image/png")
    render_upload(input, "../../evil.exe")
    view |> form("#avatar-form") |> render_submit()

    name = user.id |> Accounts.get_user() |> Accounts.avatar_name()
    assert Avatars.valid_name?(name)
    assert String.ends_with?(name, ".png")
    refute name =~ "evil"
    assert File.read!(Path.join(Avatars.dir(), name)) == png()
    Avatars.delete(name)
  end

  test "submitting with nothing chosen explains what to do", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/settings")
    html = render_submit(view, "save_avatar", %{})
    assert html =~ "Choose an image first."
  end

  test "removing the picture deletes it", %{conn: conn, user: user} do
    {:ok, user} = Accounts.set_avatar(user, png())
    name = Accounts.avatar_name(user)

    {:ok, view, html} = live(conn, ~p"/settings")
    assert html =~ "Remove picture"

    html = view |> element("button", "Remove picture") |> render_click()
    assert html =~ "Profile picture removed."
    refute File.exists?(Path.join(Avatars.dir(), name))
    assert Accounts.avatar_name(Accounts.get_user(user.id)) == nil
  end
end
