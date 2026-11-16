defmodule PhxMolbindWeb.ShareLive.NotFound do
  @moduledoc """
  Raised for every share link that cannot be shown (unknown, malformed,
  revoked, expired or orphaned). Phoenix renders it as a plain 404, so
  visitors cannot tell which case applied.
  """
  defexception message: "share link not available", plug_status: 404
end
