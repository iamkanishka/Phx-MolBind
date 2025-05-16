defmodule PhxMolbindWeb.ResearchLive.Research do
  use PhxMolbindWeb, :live_view

  alias PhxMolbindWeb.ResearchLive.CompoundSearch

  def render(assigns) do
    ~H"""
    <.live_component module={PhxMolbindWeb.ComponentsLive.MainLayout} id={:main_layout}>
      <div class="container mx-auto h-[140dvh] p-0">
        <button phx-click="toggle-theme">Toggle Theme</button>
        <div class="mb-6 flex flex-col items-center md:flex-row md:justify-between">
          <h2 class="text-title-md2 font-semibold text-black dark:text-white">
            Compound Search
          </h2>

          <%!-- <input
            type="text"
            name="compound_name"
            value={@compound_name}
            phx-debounce="300"
            phx-keydown="search_compound"
            phx-input="update_compound"
            class="border-gray-300 w-full rounded-lg border bg-white p-3 pl-10 text-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Enter a compound name"
            autocomplete="off"
          /> --%>
          <div class="relative mt-4 flex flex-1 md:mt-0 md:justify-end" phx-click-away="hide_dropdown">
            <div class="relative w-full md:w-96">
              <form phx-change="update_compound" phx-submit="noop">
                <input
                  type="text"
                  name="compound_name"
                  value={@compound_name}
                  phx-debounce="500"
                  phx-focus="show_dropdown"
                  class="border-gray-300 w-full rounded-lg border bg-white p-3 pl-10 text-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Enter a compound name"
                  autocomplete="off"
                />
              </form>

              <span class="absolute inset-y-0 right-3 flex items-center">
                <.icon name="hero-search" class="text-gray-500" />
              </span>

              <ul
                :if={@show_dropdown and @suggestions != []}
                class="absolute z-10 mt-1 w-full bg-white border border-gray-300 rounded-lg shadow-lg"
              >
                <%= for compound <- @suggestions do %>
                  <li
                    phx-click="select_compound"
                    phx-value-name={compound}
                    class="cursor-pointer px-4 py-2 hover:bg-blue-100"
                  >
                    {compound}
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </div>

        <%= if @error do %>
          <p class="text-red-600 mt-6">{@error}</p>
        <% end %>

        <%= if @compound_data do %>
          <div class="mt-8 grid grid-cols-1 gap-6 md:grid-cols-2">

    <!-- Basic Information -->
            <div class="dark:bg-gray-800 space-y-3 rounded-lg bg-white dark:bg-black p-6 shadow-md">
              <h2 class="text-gray-700 mb-4 text-xl text-black dark:text-white">Basic Information</h2>

              <p>
                <strong class="text-gray-600 dark:text-white">Molecular Formula:</strong> {@compound_data[
                  "MolecularFormula"
                ]}
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">Molecular Weight:</strong> {@compound_data[
                  "MolecularWeight"
                ]} g/mol
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">InChIKey:</strong> {@compound_data[
                  "InChIKey"
                ]}
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">Canonical SMILES:</strong>
                <%!-- <.live_component
                  module={YourAppWeb.MoleculeStructureComponent}
                  id={@compound_data["CanonicalSMILES"]}
                  structure={@compound_data["CanonicalSMILES"]}
                /> --%>
                <canvas
                  id="smiles-canvas-research"
                  phx-hook="renderSMILESmol"
                  data-smiles={@compound_data["CanonicalSMILES"]}
                  width="200"
                  height="200"
                  data-width="200"
                  data-height="200"
                >
                </canvas>
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">Isomeric SMILES:</strong> {@compound_data[
                  "IsomericSMILES"
                ]}
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">IUPAC Name:</strong> {@compound_data[
                  "IUPACName"
                ]}
              </p>
            </div>

    <!-- Physical Properties -->
            <div class="dark:bg-gray-800 space-y-3 rounded-lg bg-white p-6 shadow-md">
              <h2 class="text-gray-700 mb-4 text-xl text-black dark:text-white">
                Physical Properties
              </h2>

              <p>
                <strong class="text-gray-600 dark:text-white">XLogP:</strong> {@compound_data[
                  "XLogP"
                ]}
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">Exact Mass:</strong> {@compound_data[
                  "ExactMass"
                ]} g/mol
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">Monoisotopic Mass:</strong> {@compound_data[
                  "MonoisotopicMass"
                ]} g/mol
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">
                  Topological Polar Surface Area (TPSA):
                </strong>
                 {@compound_data["TPSA"]} Å²
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">Complexity:</strong> {@compound_data[
                  "Complexity"
                ]}
              </p>

              <p>
                <strong class="text-gray-600 dark:text-white">Charge:</strong> {@compound_data[
                  "Charge"
                ]}
              </p>
            </div>

    <!-- Additional Information -->
            <div class="dark:bg-gray-800 space-y-3 rounded-lg bg-white p-6 shadow-md md:col-span-2">
              <h2 class="text-gray-700 mb-4 text-xl text-black dark:text-white">
                Additional Information
              </h2>

              <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
                <p>
                  <strong class="text-gray-600 dark:text-white">Hydrogen Bond Donors:</strong> {@compound_data[
                    "HBondDonorCount"
                  ]}
                </p>

                <p>
                  <strong class="text-gray-600 dark:text-white">Hydrogen Bond Acceptors:</strong> {@compound_data[
                    "HBondAcceptorCount"
                  ]}
                </p>

                <p>
                  <strong class="text-gray-600 dark:text-white">Rotatable Bonds:</strong> {@compound_data[
                    "RotatableBondCount"
                  ]}
                </p>

                <p>
                  <strong class="text-gray-600 dark:text-white">Heavy Atom Count:</strong> {@compound_data[
                    "HeavyAtomCount"
                  ]}
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </.live_component>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:compound_name, "")
     |> assign(:compound_data, nil)
     |> assign(:show_dropdown, false)
     |> assign(:suggestions, [])
     |> assign(:error, nil)}
  end

  def handle_event("search_compound", %{"key" => "Enter", "value" => input_value}, socket) do
    search(socket, input_value)
  end

  def handle_event("search_compound", _params, socket) do
    # Ignore other keys
    {:noreply, socket}
  end

  defp search(socket, value) do
    socket = assign(socket, compound_name: value, suggestions: [], show_dropdown: false)

    case CompoundSearch.lookup(value) do
      {:ok, data} ->
        {:noreply,
         socket
         |> assign(:compound_data, data)
         |> assign(:error, nil)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:compound_data, nil)
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_event("toggle-theme", _params, socket) do
    IO.inspect(socket.assigns[:theme])

    new_theme =
      case socket.assigns[:theme] do
        "light" -> "dark"
        "dark" -> "system"
        _ -> "light"
      end

    IO.inspect(new_theme)

    {:noreply,
     socket
     |> assign(:theme, new_theme)
     |> push_event("theme:set", %{theme: new_theme})}
  end

  def handle_event("theme:init", %{"theme" => theme}, socket) do
    # You can update assign or store the theme as needed.
    {:noreply, assign(socket, :theme, theme)}
  end

  @impl true
  def handle_event("update_compound", %{"compound_name" => name}, socket) do
    IO.inspect(name)
    suggestions = fetch_suggestions(name)
    IO.inspect(suggestions, label: "Suggestions")
    {:noreply, assign(socket, compound_name: name, suggestions: suggestions, show_dropdown: true)}
  end

  def handle_event("select_compound", %{"name" => name}, socket) do
    IO.inspect(name, label: "Selected Compound")
    search(socket, name)

    # {:noreply, assign(socket, compound_name: name, suggestions: [], show_dropdown: false)}
  end

  def handle_event("show_dropdown", _, socket) do
    {:noreply, assign(socket, show_dropdown: true)}
  end

  def handle_event("hide_dropdown", _, socket) do
    {:noreply, assign(socket, show_dropdown: false)}
  end

  # defp fetch_suggestions(query) when byte_size(query) < 2, do: []

  defp fetch_suggestions(query) do
    # Use Finch to fetch suggestions from PubChem
    # The endpoint is: https://pubchem.ncbi.nlm.nih.gov/rest/autocomplete/compound,gene,taxonomy/{query}
    # You can use the Finch library to make the HTTP request.
    # Make sure to add Finch as a dependency in your mix.exs file.
    # {:ok, response} = Finch.request(:get, url, headers: headers)
    IO.inspect(query, label: "Query for suggestions")

    url =
      "https://pubchem.ncbi.nlm.nih.gov/rest/autocomplete/compound,gene,taxonomy/#{URI.encode(query)}"

    headers = [
      {"NCBI-PHID", "95B7506F824A39291747389517618SID.06"},
      {"User-Agent", "Mozilla/5.0"},
      {"Referer", "https://pubchem.ncbi.nlm.nih.gov"},
      {"Accept", "application/json"}
    ]

    case Finch.build(:get, url, headers) |> Finch.request(PhxMolbind.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        IO.inspect(JSON.decode(body), label: "Response Body")

        case Jason.decode(body) do
          {:ok, %{"dictionary_terms" => %{"compound" => compounds}}} ->
            Enum.take(compounds, 10)

          _ ->
            []
        end

      _ ->
        []
    end
  end
end
