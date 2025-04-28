defmodule PhxMolbindWeb.MoleculeBankLive.MoleculeBank do
  use PhxMolbindWeb, :live_view



  @molecule_bank [
    %{
      molecule_name: "Aspirin",
      smiles_structure: "CC(=O)OC1=CC=CC=C1C(O)=O",
      molecular_weight: 180.16,
      category_usage: "Pain reliever/NSAID"
    },
    %{
      molecule_name: "Caffeine",
      smiles_structure: "CN1C=NC2=C1C(=O)N(C(=O)N2C)C",
      molecular_weight: 194.19,
      category_usage: "Stimulant"
    },
    %{
      molecule_name: "Benzene",
      smiles_structure: "C1=CC=CC=C1",
      molecular_weight: 78.11,
      category_usage: "Industrial solvent"
    },
    %{
      molecule_name: "Glucose",
      smiles_structure: "C(C1C(C(C(C(O1)O)O)O)O)O",
      molecular_weight: 180.16,
      category_usage: "Energy source/sugar"
    },
    %{
      molecule_name: "Penicillin",
      smiles_structure: "CC1(C2C(C(C(O2)N1C(=O)COC(=O)C)C)S)C=O",
      molecular_weight: 334.39,
      category_usage: "Antibiotic"
    },
    %{
      molecule_name: "Ibuprofen",
      smiles_structure: "CC(C)CC1=CC=C(C=C1)C(C)C(=O)O",
      molecular_weight: 206.28,
      category_usage: "Pain reliever/NSAID"
    },
    %{
      molecule_name: "Acetaminophen",
      smiles_structure: "CC(=O)NC1=CC=C(O)C=C1",
      molecular_weight: 151.16,
      category_usage: "Pain reliever/Antipyretic"
    },
    %{
      molecule_name: "Morphine",
      smiles_structure: "CN1CCC23C4C1CC(C2C3O)OC5=CC=CC=C45",
      molecular_weight: 285.34,
      category_usage: "Pain reliever/Opiate"
    },
    %{
      molecule_name: "Nicotine",
      smiles_structure: "CN1CCCC1C2=CN=CC=C2",
      molecular_weight: 162.23,
      category_usage: "Stimulant"
    },
    %{
      molecule_name: "Ethanol",
      smiles_structure: "CCO",
      molecular_weight: 46.07,
      category_usage: "Alcohol/Disinfectant"
    }
  ]




  def render(assigns) do
    ~H"""
    <div class="rounded-lg border border-stroke bg-white px-5 pb-2.5 pt-6 shadow-default dark:border-[#181818] dark:bg-[#181818] sm:px-7.5 xl:pb-1">
      <h4 class="mb-6 text-xl font-semibold text-black dark:text-white">
        Molecules
      </h4>

      <form phx-change="search_molecule">
        <input
          type="search"
          placeholder="Search molecule"
          name="search_query"
          value={@search_query}
          phx-debounce="300"
          class="border-gray-300 text-gray-700 placeholder-gray-400 dark:border-gray-600 dark:placeholder-gray-500 text-md mb-4 w-full rounded-lg border bg-white px-4 py-3 shadow-sm outline-none focus:border-primary focus:ring-primary dark:bg-[#181818] dark:text-white"
        />
      </form>

      <div class="flex flex-col">
        <div class="grid grid-cols-3 rounded-lg bg-gray-2 dark:bg-[#121212] sm:grid-cols-4">
          <div class="p-2.5 xl:p-5">
            <h5 class="text-sm font-medium uppercase xsm:text-base">Molecule name</h5>
          </div>

          <div class="p-2.5 text-center xl:p-5">
            <h5 class="text-sm font-medium uppercase xsm:text-base">Smile Structure Image</h5>
          </div>

          <div class="p-2.5 text-center xl:p-5">
            <h5 class="text-sm font-medium uppercase xsm:text-base">Molecular Weights (g/mol)</h5>
          </div>

          <div class="hidden p-2.5 text-center sm:block xl:p-5">
            <h5 class="text-sm font-medium uppercase xsm:text-base">Category Usage</h5>
          </div>
        </div>

        <%= for {molecule, index} <- Enum.with_index(@filtered_molecules) do %>
          <div class={"grid grid-cols-3 sm:grid-cols-4 #{if index != length(@filtered_molecules) - 1, do: "border-b border-stroke dark:border-strokedark", else: ""}"}>
            <div class="flex items-center justify-center p-2.5 xl:p-5">
              <p class="text-black dark:text-white">
                {molecule.molecule_name}
              </p>
            </div>

            <div class="flex items-center gap-3 p-2.5 xl:p-5">
              <div class="flex-shrink-0">
                <%!-- <.molecule_structure id={index} structure={molecule.smiles_structure} /> --%>
              </div>
            </div>

            <div class="hidden items-center justify-center p-2.5 sm:flex xl:p-5">
              <p class="text-black dark:text-white">
                {molecule.molecular_weight}
              </p>
            </div>

            <div class="hidden items-center justify-center p-2.5 sm:flex xl:p-5">
              <p class="text-black dark:text-white">
                {molecule.category_usage}
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def  mount(_params, _session, socket) do
    {:ok, socket}
  end
end
