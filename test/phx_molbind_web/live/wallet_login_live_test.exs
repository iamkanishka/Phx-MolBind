defmodule PhxMolbindWeb.WalletLoginLiveTest do
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Nonces live in one global table keyed by address, so every test uses its
  # own address to stay independent of test order.
  defp random_address, do: "0x" <> Base.encode16(:crypto.strong_rand_bytes(20), case: :lower)

  test "renders inline status and install guidance containers, not alerts", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/auth/sign-in")
    assert html =~ ~s(id="wallet-status")
    assert html =~ ~s(aria-live="polite")
    assert html =~ "No wallet detected"
    assert html =~ "never triggers a transaction"
  end

  test "an expired or missing nonce is reported as expired, not as a bad signature", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/auth/sign-in")
    address = random_address()

    render_hook(view, "verify_signature", %{
      "address" => address,
      "signature" => "0x" <> String.duplicate("ab", 65)
    })

    assert_push_event(view, "login_failed", %{reason: "expired", message: message})
    assert message =~ "expired"
  end

  test "a bad signature over a valid nonce is reported as invalid", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/auth/sign-in")
    address = random_address()
    render_hook(view, "request_nonce", %{"address" => address})

    render_hook(view, "verify_signature", %{
      "address" => address,
      "signature" => "0x" <> String.duplicate("00", 65)
    })

    assert_push_event(view, "login_failed", %{reason: "invalid"})
  end

  test "request_nonce rejects malformed addresses", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/auth/sign-in")
    assert render_hook(view, "request_nonce", %{"address" => "nope"})
    refute_push_event(view, "login_failed", %{})
  end
end
