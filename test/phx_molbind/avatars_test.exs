defmodule PhxMolbind.AvatarsTest do
  use PhxMolbind.DataCase, async: true

  alias PhxMolbind.{Accounts, Avatars}
  import PhxMolbind.AccountsFixtures
  import PhxMolbind.ImageFixtures

  defp stored?(name), do: File.exists?(Path.join(Avatars.dir(), name))

  describe "detect/1 (magic bytes, not names)" do
    test "recognises the four supported formats" do
      assert Avatars.detect(png()) == {:ok, "png"}
      assert Avatars.detect(jpeg()) == {:ok, "jpg"}
      assert Avatars.detect(gif()) == {:ok, "gif"}
      assert Avatars.detect(webp()) == {:ok, "webp"}
      assert Avatars.detect("GIF87a" <> :binary.copy(<<0>>, 20)) == {:ok, "gif"}
    end

    test "refuses SVG, HTML, text, empty and truncated input" do
      for bad <- [
            svg(),
            html(),
            "just some text, not an image",
            "",
            "x",
            <<0x89, "PNG">>,
            nil,
            123
          ] do
        assert Avatars.detect(bad) == :error
      end
    end

    test "a RIFF file that is not WebP is refused" do
      wav = "RIFF" <> <<40, 0, 0, 0>> <> "WAVE" <> :binary.copy(<<0>>, 40)
      assert Avatars.detect(wav) == :error
    end

    test "enforces the size cap" do
      assert {:ok, "png"} =
               Avatars.detect(
                 png() <> :binary.copy(<<0>>, Avatars.max_bytes() - byte_size(png()))
               )

      assert :error = Avatars.detect(png() <> :binary.copy(<<0>>, Avatars.max_bytes()))
    end
  end

  describe "names and paths" do
    test "only the exact server-generated shape is valid" do
      good = String.duplicate("a1", 16) <> ".png"
      assert Avatars.valid_name?(good)
      assert Avatars.path(good) == Path.join(Avatars.dir(), good)

      for bad <- [
            "../" <> good,
            "x/" <> good,
            String.upcase(good),
            String.duplicate("a", 31) <> ".png",
            String.duplicate("a", 32) <> ".exe",
            String.duplicate("a", 32) <> ".svg",
            String.duplicate("a", 32) <> ".png/",
            String.duplicate("a", 32) <> ".png\n",
            "",
            nil,
            :atom
          ] do
        refute Avatars.valid_name?(bad)
        assert Avatars.path(bad) == nil
        assert Avatars.content_type(bad) == nil
      end
    end

    test "content types follow the extension of a valid name" do
      assert Avatars.content_type(String.duplicate("a", 32) <> ".jpg") == "image/jpeg"
      assert Avatars.content_type(String.duplicate("a", 32) <> ".webp") == "image/webp"
    end
  end

  describe "store/1 and delete/1" do
    test "stores validated bytes under a random name" do
      assert {:ok, name} = Avatars.store(png())
      assert Avatars.valid_name?(name) and String.ends_with?(name, ".png")
      assert File.read!(Path.join(Avatars.dir(), name)) == png()

      assert {:ok, other} = Avatars.store(png())
      assert other != name

      Avatars.delete(name)
      Avatars.delete(other)
    end

    test "rejects non-images without writing anything" do
      File.mkdir_p!(Avatars.dir())
      before = File.ls!(Avatars.dir()) |> length()

      assert {:error, :unsupported} = Avatars.store(svg())
      assert {:error, :unsupported} = Avatars.store(html())
      assert File.ls!(Avatars.dir()) |> length() == before
    end

    test "delete removes the file and ignores invalid names" do
      {:ok, name} = Avatars.store(png())
      assert stored?(name)
      assert :ok = Avatars.delete(name)
      refute stored?(name)

      assert :ok = Avatars.delete(name)
      assert :ok = Avatars.delete("../mix.exs")
      assert :ok = Avatars.delete(nil)
      assert File.exists?("mix.exs")
    end
  end

  describe "Accounts avatar helpers" do
    setup do
      %{user: user_fixture()}
    end

    test "set_avatar stores the file and references it", %{user: user} do
      assert {:ok, user} = Accounts.set_avatar(user, png())
      name = Accounts.avatar_name(user)
      assert name && stored?(name)
      assert Accounts.avatar_url(user) == "/avatars/" <> name
      Avatars.delete(name)
    end

    test "replacing an avatar deletes the previous file", %{user: user} do
      {:ok, user} = Accounts.set_avatar(user, png())
      old = Accounts.avatar_name(user)
      {:ok, user} = Accounts.set_avatar(user, jpeg())
      new = Accounts.avatar_name(user)

      assert new != old and String.ends_with?(new, ".jpg")
      refute stored?(old)
      assert stored?(new)
      Avatars.delete(new)
    end

    test "garbage is refused and leaves the user and disk unchanged", %{user: user} do
      {:ok, user} = Accounts.set_avatar(user, png())
      name = Accounts.avatar_name(user)

      assert {:error, :unsupported} = Accounts.set_avatar(user, svg())
      assert Accounts.avatar_name(Accounts.get_user(user.id)) == name
      assert stored?(name)
      Avatars.delete(name)
    end

    test "clear_avatar removes file and reference", %{user: user} do
      {:ok, user} = Accounts.set_avatar(user, gif())
      name = Accounts.avatar_name(user)
      assert {:ok, cleared} = Accounts.clear_avatar(user)
      assert Accounts.avatar_name(cleared) == nil
      refute stored?(name)
    end

    test "a tampered metadata value is never trusted", %{user: user} do
      {:ok, user} = Accounts.update_user(user, %{metadata: %{"avatar" => "../../etc/passwd"}})
      assert Accounts.avatar_name(user) == nil
      assert Accounts.avatar_url(user) == nil
    end

    test "the profile photo URL is the fallback", %{user: user} do
      {:ok, user} =
        Accounts.update_profile(user, %{
          "username" => "ada",
          "photo_url" => "https://example.com/a.png"
        })

      assert Accounts.avatar_url(user) == "https://example.com/a.png"

      {:ok, user} = Accounts.set_avatar(user, png())
      assert Accounts.avatar_url(user) =~ "/avatars/"
      Avatars.delete(Accounts.avatar_name(user))
    end

    test "saving the profile keeps the avatar", %{user: user} do
      {:ok, user} = Accounts.set_avatar(user, png())
      name = Accounts.avatar_name(user)
      {:ok, user} = Accounts.update_profile(user, %{"username" => "grace", "bio" => "hi"})
      assert Accounts.avatar_name(user) == name
      Avatars.delete(name)
    end

    test "deleting the account deletes the file", %{user: user} do
      {:ok, user} = Accounts.set_avatar(user, png())
      name = Accounts.avatar_name(user)
      assert {:ok, _} = Accounts.delete_account(user)
      refute stored?(name)
    end
  end
end
