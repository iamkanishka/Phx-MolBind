defmodule PhxMolbindWeb.ModelLive.Model do
  use PhxMolbindWeb, :live_view
  alias PhxMolbind.Molecules.Molecules
  @new_entry
  def render(assigns) do
    ~H"""
    <.live_component module={PhxMolbindWeb.ComponentsLive.MainLayout} id={:main_layout}>
      <div class="grid grid-cols-1 gap-9 sm:grid-cols-3">
        <div class="flex flex-col gap-9 sm:col-span-2">
          <div class="rounded-lg border border-stroke bg-white shadow-default dark:border-[#121212] dark:bg-[#181818]">
            <div class="border-b border-stroke px-6.5 py-4 dark:border-strokedark">
              <h3 class="font-medium text-black dark:text-white">
                SMILES to Molecule Generator
              </h3>
            </div>

            <.simple_form for={@form} id="moelcule-form" phx-submit="submit">
              <div class="p-6.5">
                <div class="mb-4.5 flex flex-col gap-6 xl:flex-row">
                  <div class="w-full xl:w-1/2">
                    <.input
                      type="text"
                      field={@form[:smiles]}
                      label="SMILES String"
                      placeholder="Enter SMILES string"
                    />
                  </div>

                  <div class="w-full xl:w-1/2">
                    <.input
                      type="text"
                      field={@form[:num_molecules]}
                      label="Number of Molecules"
                      placeholder="Enter number of molecules"
                    />
                  </div>
                </div>

                <div class="mb-4.5">
                  <.input
                    type="text"
                    field={@form[:min_similarity]}
                    label="Minimum Similarity"
                    placeholder="Enter minimum similarity"
                  />
                </div>

                <div class="mb-4.5">
                  <.input
                    type="text"
                    field={@form[:particles]}
                    label="Particles"
                    placeholder="Enter number of particles"
                  />
                </div>

                <div class="mb-4.5">
                  <.input
                    type="text"
                    field={@form[:iterations]}
                    label="Iterations"
                    placeholder="Enter number of iterations"
                  />
                </div>

                <button
                  type="submit"
                  class="flex w-full justify-center rounded-lg bg-primary p-3 font-medium text-gray hover:bg-opacity-90"
                  disabled={@loading}
                >
                  {if @loading, do: "Generating...", else: "Generate Molecules"}
                </button>
              </div>
            </.simple_form>
          </div>
        </div>

        <div class="flex flex-col gap-9">
          <div class="rounded-lg border border-stroke bg-white p-3 shadow-default dark:border-[#121212] dark:bg-[#181818]">
            <h3 class="font-medium text-black dark:text-white">
              Molecule Generation History
            </h3>

            <div class="mt-4 max-h-96 overflow-y-auto">
              <%= for {entry, index} <- Enum.with_index(@history) do %>
                <div class="border-b border-stroke py-3">
                  <p class="text-sm text-black dark:text-white">
                    <span class="font-bold">SMILES:</span> {entry.smiles}
                  </p>

                  <p class="text-sm text-black dark:text-white">
                    <span class="font-bold">Molecules:</span> {entry.numMolecules}
                  </p>

                  <p class="text-sm text-black dark:text-white">
                    <span class="font-bold">Date:</span> {Timex.format!(
                      entry.createdAt,
                      "%Y-%m-%d",
                      :strftime
                    )}
                  </p>

                  <div class="mt-3">
                    <button
                      type="button"
                      class="text-primary hover:underline"
                      phx-click="view_molecules"
                      phx-value-index={index}
                    >
                      View Molecules
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%= if length(@molecules) > 0 do %>
        <div class="mt-8 rounded-lg bg-white p-2">
          <div class="mt-8 flex flex-col gap-2">
            <div class="grid grid-cols-1 gap-2 sm:grid-cols-3">
              <%= for {molecule, index} <- Enum.with_index(@molecules) do %>
                <%!-- <%= IO.inspect(mol.structure) %>
                <.live_component
                  module={PhxMolbindWeb.ComponentsLive.MoleculeRender.MoleculeRender}
                  id={"selected_smiles-canvas-#{index}"}
                  smiles_structure={mol.structure}
                />
              <% end %> --%>
                <canvas
                  id={"smiles-canvas-model-#{index}"}
                  phx-hook="renderSMILESmol"
                  data-smiles={molecule.structure}
                  width="300"
                  height="300"
                  data-width="300"
                  data-height="300"
                >
                </canvas>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </.live_component>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:history, [])
     |> assign(:molecules, [])
     |> assign_form()}
  end

  defp assign_form(socket) do
    form = Phoenix.HTML.FormData.to_form(%{}, as: :form)
    assign(socket, %{form: form})
  end

  def handle_event("theme:init", %{"theme" => theme}, socket) do
    # You can update assign or store the theme as needed.
    {:noreply, assign(socket, :theme, theme)}
  end

  def handle_event("submit", %{"form" => form_params}, socket) do
    socket = assign(socket, :loading, true)

    payload = %{
      "algorithm" => "CMA-ES",
      "num_molecules" => String.to_integer(form_params["num_molecules"]),
      "property_name" => "QED",
      "minimize" => false,
      "min_similarity" => String.to_float(form_params["min_similarity"]),
      "particles" => String.to_integer(form_params["particles"]),
      "iterations" => String.to_integer(form_params["iterations"]),
      "smi" => form_params["smiles"]
    }

    case Molecules.generate_molecules(payload) do
      {:ok, molecules} ->
        IO.inspect(molecules, label: "Generated Molecules")

        # @new_entry = %{
        #   smiles: payload["smiles"],
        #   num_molecules: payload["numMolecules"],
        #   algorithm: "CMA-ES",
        #   num_molecules: String.to_integer(form_params["num_molecules"]),
        #   property_name: "QED",
        #   minimize: false,
        #   min_similarity: String.to_float(form_params["min_similarity"]),
        #   particles: String.to_integer(form_params["particles"]),
        #   iterations: String.to_integer(form_params["iterations"]),
        #   smiles: form_params["smiles"],
        #   generated_molecules: molecules
        # }

        {:noreply,
         socket
         |> assign(:molecules, molecules)
         |> assign(:loading, false)}

      {:error, reason} ->
        # You can log or display this in the UI with a flash
        IO.inspect(reason, label: "Molecule generation failed")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to generate molecules.")
         |> assign(:loading, false)}
    end
  end
end
