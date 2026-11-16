defmodule PhxMolbind.Avatars do
  @moduledoc """
  Storage and validation for uploaded profile pictures.

  Storage is the local filesystem under `config :phx_molbind, :avatar_dir`
  (set `AVATAR_DIR` in production and point it at a persistent volume; on
  hosts with an ephemeral disk, uploaded avatars are lost on redeploy).

  Safety rules:
    * File type comes from the file's *magic bytes*, never from its name or
      the browser-reported content type. Only PNG, JPEG, GIF and WebP are
      accepted; SVG is refused on purpose because it can carry scripts.
    * Stored names are server-generated (128 random bits + extension) and every
      path is rebuilt from a validated name, so no client-supplied string can
      reach the filesystem.
    * Size is capped at `max_bytes/0`.
  """

  @max_bytes 2_000_000
  @name_regex ~r/\A[a-f0-9]{32}\.(png|jpg|gif|webp)\z/
  @content_types %{
    "png" => "image/png",
    "jpg" => "image/jpeg",
    "gif" => "image/gif",
    "webp" => "image/webp"
  }

  def max_bytes, do: @max_bytes

  @doc "Directory avatars are stored in."
  def dir, do: Application.fetch_env!(:phx_molbind, :avatar_dir)

  @doc "Public URL path for a stored avatar name."
  def url(name) when is_binary(name), do: "/avatars/" <> name

  @doc "Whether `name` has exactly the shape this module generates."
  def valid_name?(name) when is_binary(name), do: Regex.match?(@name_regex, name)
  def valid_name?(_), do: false

  @doc "Content type for a *valid* stored name (nil otherwise)."
  def content_type(name) do
    if valid_name?(name),
      do: Map.fetch!(@content_types, name |> Path.extname() |> String.trim_leading(".")),
      else: nil
  end

  @doc "Absolute path of a stored avatar, or nil for an invalid name."
  def path(name), do: if(valid_name?(name), do: Path.join(dir(), name), else: nil)

  @doc """
  Identifies an image by its leading bytes: `{:ok, "png" | "jpg" | "gif" | "webp"}`
  or `:error`. Also enforces the size cap.
  """
  def detect(binary)
      when is_binary(binary) and byte_size(binary) > 12 and byte_size(binary) <= @max_bytes do
    case binary do
      <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _::binary>> -> {:ok, "png"}
      <<0xFF, 0xD8, 0xFF, _::binary>> -> {:ok, "jpg"}
      <<"GIF87a", _::binary>> -> {:ok, "gif"}
      <<"GIF89a", _::binary>> -> {:ok, "gif"}
      <<"RIFF", _size::binary-size(4), "WEBP", _::binary>> -> {:ok, "webp"}
      _ -> :error
    end
  end

  def detect(_), do: :error

  @doc "Validates and stores image bytes. Returns `{:ok, name}` or `{:error, reason}`."
  def store(binary) do
    with {:ok, ext} <- detect(binary) |> or_error(:unsupported),
         name = Base.encode16(:crypto.strong_rand_bytes(16), case: :lower) <> "." <> ext,
         :ok <- File.mkdir_p(dir()),
         :ok <- File.write(Path.join(dir(), name), binary, [:exclusive]) do
      {:ok, name}
    else
      {:error, :unsupported} -> {:error, :unsupported}
      {:error, _posix} -> {:error, :storage}
    end
  end

  defp or_error({:ok, _} = ok, _reason), do: ok
  defp or_error(:error, reason), do: {:error, reason}

  @doc "Deletes a stored avatar. Silently ignores invalid names and missing files."
  def delete(name) do
    case path(name) do
      nil -> :ok
      path -> File.rm(path) |> then(fn _ -> :ok end)
    end
  end
end
