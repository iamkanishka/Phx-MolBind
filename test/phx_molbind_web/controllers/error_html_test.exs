defmodule PhxMolbindWeb.ErrorHTMLTest do
  use PhxMolbindWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders a useful 404 page with a way back" do
    html = render_to_string(PhxMolbindWeb.ErrorHTML, "404", "html", [])
    assert html =~ "We couldn't find that page"
    assert html =~ ~s(href="/")
    assert html =~ ~s(<main)
  end

  test "renders a 500 page that exposes no internals" do
    html = render_to_string(PhxMolbindWeb.ErrorHTML, "500", "html", [])
    assert html =~ "Something went wrong"
    refute html =~ ~r/stacktrace|\*\* \(|exception|\.ex:/i
  end
end
