defmodule PhxMolbind.ImageFixtures do
  @moduledoc "Tiny byte strings with real image magic numbers, for upload tests."

  # A genuine 1x1 PNG.
  def png,
    do:
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
      )

  # Magic number + padding: enough for type detection, not a decodable image.
  def jpeg, do: <<0xFF, 0xD8, 0xFF, 0xE0>> <> :binary.copy(<<0>>, 40)
  def gif, do: "GIF89a" <> :binary.copy(<<0>>, 40)
  def webp, do: "RIFF" <> <<40, 0, 0, 0>> <> "WEBP" <> :binary.copy(<<0>>, 40)

  def svg,
    do:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" onload=\"alert(1)\"><script>alert(1)</script></svg>"

  def html, do: "<!DOCTYPE html><html><body><script>alert(1)</script></body></html>"
end
