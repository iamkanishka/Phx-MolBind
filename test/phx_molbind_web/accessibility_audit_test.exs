defmodule PhxMolbindWeb.AccessibilityAuditTest do
  @moduledoc """
  Static accessibility audit of server-rendered HTML for every page.

  This checks things that are decidable from markup: names and labels,
  headings, landmarks, duplicate ids, canvases. It cannot judge colour
  contrast, focus order, screen-reader output or responsive layout; those need
  a browser and assistive technology. Passing here is NOT a WCAG conformance
  claim.
  """
  use PhxMolbindWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PhxMolbind.{Collections, Messages}
  alias PhxMolbind.Molecules.Molecules

  @pages ~w(/ /model /research /history /collections /molecule-bank /sketcher /message /profile /settings)

  setup :register_and_log_in_user

  setup %{user: user} do
    {:ok, run} =
      Molecules.create_history(
        %{
          algorithm: "CMA-ES",
          num_molecules: 1,
          property_name: "QED",
          minimize: false,
          min_similarity: 0.5,
          particles: 10,
          iterations: 2,
          smiles: "CCO",
          generated_molecules: %{"molecules" => [%{"structure" => "CCN", "score" => 0.4}]}
        },
        user.id
      )

    {:ok, c} = Collections.create_collection(user.id, %{name: "Picks"})

    {:ok, _} =
      Collections.add_item(user.id, c.id, %{smiles: "CCN", score: 0.4, property_name: "QED"})

    {:ok, parent} = Messages.create_message(%{"body" => "hello"}, user.id)

    {:ok, _} =
      Messages.create_message(%{"body" => "a reply", "reply_to_id" => parent.id}, user.id)

    {:ok, _} = Messages.share_molecule(user.id, "CCN", "a shared molecule card")
    {:ok, _} = Messages.toggle_reaction(user.id, parent.id, "👍")
    %{run: run, collection: c}
  end

  defp pages(%{run: run, collection: c}) do
    @pages ++ ["/history/#{run.id}", "/collections/#{c.id}"]
  end

  defp doc(conn, path) do
    {:ok, _view, html} = live(conn, path)
    {:ok, doc} = Floki.parse_document(html)
    doc
  end

  defp findings(doc) do
    List.flatten([
      ids(doc),
      names(doc),
      labels(doc),
      headings(doc),
      canvases(doc),
      landmarks(doc)
    ])
  end

  defp ids(doc) do
    doc
    |> Floki.attribute("[id]", "id")
    |> Enum.frequencies()
    |> Enum.filter(fn {_id, n} -> n > 1 end)
    |> Enum.map(fn {id, n} -> "duplicate id #{inspect(id)} used #{n} times" end)
  end

  # Buttons and links need a name from text, aria-label, aria-labelledby or title.
  defp names(doc) do
    for {tag, attrs, _} = el <- Floki.find(doc, "button, a[href]"),
        not named?(el, attrs),
        do: "#{tag} without an accessible name: #{snippet(el)}"
  end

  defp named?(el, attrs) do
    text = el |> Floki.text(sep: " ") |> String.trim()

    text != "" or Enum.any?(~w(aria-label aria-labelledby title), &attr(attrs, &1)) or
      Floki.find(el, "[class*=sr-only]") != []
  end

  defp labels(doc) do
    label_for = doc |> Floki.attribute("label", "for") |> MapSet.new()

    # Controls nested inside a <label> are implicitly labelled.
    nested =
      doc
      |> Floki.find("label")
      |> Enum.flat_map(&Floki.find(&1, "input, select, textarea"))
      |> MapSet.new()

    for {tag, attrs, _} = el <- Floki.find(doc, "input, select, textarea"),
        type = attr(attrs, "type") || "text",
        type not in ~w(hidden submit button),
        not (MapSet.member?(nested, el) or labelled?(el, attrs, label_for)),
        do: "#{tag}[type=#{type}] without a label: #{snippet(el)}"
  end

  defp labelled?(_el, attrs, label_for) do
    attr(attrs, "aria-label") != nil or attr(attrs, "aria-labelledby") != nil or
      (attr(attrs, "id") != nil and MapSet.member?(label_for, attr(attrs, "id")))
  end

  defp headings(doc) do
    levels =
      doc
      |> Floki.find("h1, h2, h3, h4, h5, h6")
      |> Enum.map(fn {tag, _, _} -> tag |> String.trim_leading("h") |> String.to_integer() end)

    h1s = Enum.count(levels, &(&1 == 1))

    skips =
      levels
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [a, b] -> b > a + 1 end)
      |> Enum.map(fn [a, b] -> "heading level skips from h#{a} to h#{b}" end)

    h1_finding =
      cond do
        h1s == 0 -> ["no h1"]
        h1s > 1 -> ["#{h1s} h1 elements (expected 1)"]
        true -> []
      end

    h1_finding ++ skips
  end

  defp canvases(doc) do
    for {_, attrs, _} = el <- Floki.find(doc, "canvas"),
        attr(attrs, "role") not in ["img", "application"] or blank?(attr(attrs, "aria-label")),
        do: "canvas without role=img|application and aria-label: #{snippet(el)}"
  end

  defp landmarks(doc) do
    lang = doc |> Floki.find("html") |> Floki.attribute("lang")

    [
      if(lang == [] or lang == [""], do: "html has no lang"),
      if(Floki.find(doc, "main") == [], do: "no <main> landmark"),
      if(Floki.find(doc, "nav, [role=navigation]") == [], do: "no navigation landmark")
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp attr(attrs, name) do
    case List.keyfind(attrs, name, 0) do
      {_, value} -> value
      nil -> nil
    end
  end

  defp blank?(nil), do: true
  defp blank?(value), do: String.trim(value) == ""

  defp snippet(el), do: el |> Floki.raw_html() |> String.slice(0, 140)

  test "every page passes the static accessibility checks", %{conn: conn} = ctx do
    report =
      for path <- pages(ctx),
          found = findings(doc(conn, path)),
          found != [],
          do: {path, Enum.uniq(found)}

    assert report == [], "Accessibility findings:\n" <> format(report)
  end

  test "public share pages pass too (run and collection)", %{run: run, collection: c, user: user} do
    {:ok, _, run_token} = PhxMolbind.Sharing.create_link(user.id, "run", run.id)
    {:ok, _, col_token} = PhxMolbind.Sharing.create_link(user.id, "collection", c.id)

    for token <- [run_token, col_token] do
      doc = doc(Phoenix.ConnTest.build_conn(), "/s/#{token}")
      found = Enum.reject(findings(doc), &(&1 == "no navigation landmark"))
      assert found == [], "Accessibility findings on /s: " <> inspect(found)
    end
  end

  test "the signed-out wallet sign-in page passes too" do
    doc = doc(Phoenix.ConnTest.build_conn(), "/auth/sign-in")
    # No app shell here, so there is no navigation landmark to require.
    found = Enum.reject(findings(doc), &(&1 == "no navigation landmark"))
    assert found == [], "Accessibility findings: " <> inspect(found)
  end

  defp format(report) do
    Enum.map_join(report, "\n", fn {path, items} ->
      "#{path}\n" <> Enum.map_join(items, "\n", &("  - " <> &1))
    end)
  end
end
