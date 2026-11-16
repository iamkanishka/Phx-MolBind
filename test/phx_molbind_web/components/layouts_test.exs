defmodule PhxMolbindWeb.LayoutsTest do
  use ExUnit.Case, async: true

  alias PhxMolbindWeb.Layouts

  describe "active_route?/2" do
    test "root only matches exactly" do
      assert Layouts.active_route?("/", "/")
      refute Layouts.active_route?("/", "/model")
    end

    test "other routes match themselves and sub-paths, not look-alikes" do
      assert Layouts.active_route?("/model", "/model")
      assert Layouts.active_route?("/model", "/model/42")
      refute Layouts.active_route?("/model", "/modelling")
      refute Layouts.active_route?("/model", "/")
    end

    test "non-binary paths never match" do
      refute Layouts.active_route?("/model", nil)
    end
  end

  test "current_label/1 finds the nav entry for a path" do
    assert Layouts.current_label("/molecule-bank") == "Molecule Bank"
    assert Layouts.current_label("/history/12") == "History"
    assert Layouts.current_label("/nope") == nil
  end

  test "short_address/1 shortens long addresses and leaves short values alone" do
    address = "0x" <> String.duplicate("a", 38) <> "bcde"
    assert Layouts.short_address(address) == "0xaaaa…bcde"
    assert Layouts.short_address("0x12") == "0x12"
    assert Layouts.short_address(nil) == ""
  end

  test "display_name/1 prefers the username" do
    assert Layouts.display_name(%{username: "ada", address: "0x" <> String.duplicate("a", 40)}) ==
             "ada"

    assert Layouts.display_name(%{username: "", address: "0x" <> String.duplicate("a", 40)}) =~
             "…"
  end
end
