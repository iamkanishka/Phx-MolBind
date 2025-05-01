defmodule PhxMolbindWeb.ResearchLive.Research do
  use PhxMolbindWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="container mx-auto h-[140dvh] p-0">
      <div class="mb-6 flex flex-col items-center md:flex-row md:justify-between">
        <h2 class="text-title-md2 font-semibold text-black dark:text-white">
          Compound Search
        </h2>

        <div class="relative mt-4 flex flex-1 md:mt-0 md:justify-end">
          <input
            type="text"
            name="compound_name"
            value={@compound_name}
            phx-debounce="300"
            phx-keydown="search_compound"
            phx-change="update_compound"
            class="border-gray-300 w-full rounded-lg border bg-white p-3 pl-10 text-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 md:w-96"
            placeholder="Enter a compound name"
          />
          <span class="absolute inset-y-0 right-3 flex items-center">
            <.icon name="search" class="text-gray-500" />
          </span>
        </div>
      </div>

      <%= if @error do %>
        <p class="text-red-600 mt-6">{@error}</p>
      <% end %>

      <%= if @compound_data do %>
        <div class="mt-8 grid grid-cols-1 gap-6 md:grid-cols-2">

    <!-- Basic Information -->
          <div class="dark:bg-gray-800 space-y-3 rounded-lg bg-white p-6 shadow-md">
            <h2 class="text-gray-700 mb-4 text-xl text-black dark:text-white">Basic Information</h2>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">Molecular Formula:</strong> {@compound_data[
                "MolecularFormula"
              ]}
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">Molecular Weight:</strong> {@compound_data[
                "MolecularWeight"
              ]} g/mol
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">InChIKey:</strong> {@compound_data[
                "InChIKey"
              ]}
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">Canonical SMILES:</strong>
              <.live_component
                module={YourAppWeb.MoleculeStructureComponent}
                id={@compound_data["CanonicalSMILES"]}
                structure={@compound_data["CanonicalSMILES"]}
              />
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">Isomeric SMILES:</strong> {@compound_data[
                "IsomericSMILES"
              ]}
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">IUPAC Name:</strong> {@compound_data[
                "IUPACName"
              ]}
            </p>
          </div>

    <!-- Physical Properties -->
          <div class="dark:bg-gray-800 space-y-3 rounded-lg bg-white p-6 shadow-md">
            <h2 class="text-gray-700 mb-4 text-xl text-black dark:text-white">Physical Properties</h2>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">XLogP:</strong> {@compound_data[
                "XLogP"
              ]}
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">Exact Mass:</strong> {@compound_data[
                "ExactMass"
              ]} g/mol
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">Monoisotopic Mass:</strong> {@compound_data[
                "MonoisotopicMass"
              ]} g/mol
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">
                Topological Polar Surface Area (TPSA):
              </strong> {@compound_data["TPSA"]} Å²
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">Complexity:</strong> {@compound_data[
                "Complexity"
              ]}
            </p>

            <p>
              <strong class="text-gray-600 dark:text-gray-300">Charge:</strong> {@compound_data[
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
                <strong class="text-gray-600 dark:text-gray-300">Hydrogen Bond Donors:</strong> {@compound_data[
                  "HBondDonorCount"
                ]}
              </p>

              <p>
                <strong class="text-gray-600 dark:text-gray-300">Hydrogen Bond Acceptors:</strong> {@compound_data[
                  "HBondAcceptorCount"
                ]}
              </p>

              <p>
                <strong class="text-gray-600 dark:text-gray-300">Rotatable Bonds:</strong> {@compound_data[
                  "RotatableBondCount"
                ]}
              </p>

              <p>
                <strong class="text-gray-600 dark:text-gray-300">Heavy Atom Count:</strong> {@compound_data[
                  "HeavyAtomCount"
                ]}
              </p>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end



  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:compound_name, "")
     |> assign(:compound_data, nil)
     |> assign(:error, nil)}
  end

  def handle_event("update_compound", %{"compound_name" => name}, socket) do
    {:noreply, assign(socket, :compound_name, name)}
  end

  def handle_event("search_compound", %{"key" => "Enter"}, socket) do
    search(socket)
  end

  def handle_event("search_compound", _params, socket) do
    # Ignore other keys
    {:noreply, socket}
  end



  defp search(socket) do
    compound_name = socket.assigns.compound_name

    case CompoundSearch.lookup(compound_name) do
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

end
