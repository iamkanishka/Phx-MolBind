defmodule PhxMolbindWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use PhxMolbindWeb, :html

  # Custom pages live in:
  #
  #   * lib/phx_molbind_web/controllers/error_html/404.html.heex
  #   * lib/phx_molbind_web/controllers/error_html/500.html.heex
  #
  embed_templates "error_html/*"
end
