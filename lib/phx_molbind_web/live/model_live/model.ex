defmodule PhxMolbindWeb.ModelLive.Model do
  use PhxMolbindWeb, :live_view

  def render(assigns) do
    ~H"""

    <%!-- <DefaultLayout>
      <Breadcrumb pageName="Generate Molecules" />

      <div class="grid grid-cols-1 gap-9 sm:grid-cols-3">
        <div class="flex flex-col gap-9 sm:col-span-2">
          <div class="rounded-lg border border-stroke bg-white shadow-default dark:border-[#121212] dark:bg-[#181818]">
            <div class="border-b border-stroke px-6.5 py-4 dark:border-strokedark">
              <h3 class="font-medium text-black dark:text-white">
                SMILES to Molecule Generator
              </h3>
            </div>
            <form onSubmit={handleSubmit}>
              <div class="p-6.5">
                <div class="mb-4.5 flex flex-col gap-6 xl:flex-row">
                  <div class="w-full xl:w-1/2">
                    <label class="mb-3 block text-sm font-medium text-black dark:text-white">
                      SMILES String
                    </label>
                    <input
                      type="text"
                      value={smiles}
                      onChange={(e) => setSmiles(e.target.value)}
                      placeholder="Enter SMILES string"
                      class="w-full rounded-lg border-[1.5px] bg-transparent px-5 py-3 text-black outline-none transition focus:border-primary active:border-primary dark:border-gray-2 dark:bg-[#181818] dark:text-white dark:focus:border-primary"
                    />
                  </div>

                  <div class="w-full xl:w-1/2">
                    <label class="mb-3 block text-sm font-medium text-black dark:text-white">
                      Number of Molecules
                    </label>
                    <input
                      type="text"
                      value={numMolecules}
                      onChange={(e) => setNumMolecules(e.target.value)}
                      placeholder="Enter number of molecules"
                      class="w-full rounded-lg border-[1.5px] bg-transparent px-5 py-3 text-black outline-none transition focus:border-primary active:border-primary dark:border-gray-2 dark:bg-[#181818] dark:text-white dark:focus:border-primary"
                    />
                  </div>
                </div>

                <div class="mb-4.5">
                  <label class="mb-3 block text-sm font-medium text-black dark:text-white">
                    Minimum Similarity
                  </label>
                  <input
                    type="text"
                    value={minSimilarity}
                    onChange={(e) => setMinSimilarity(e.target.value)}
                    placeholder="Enter minimum similarity"
                    class="w-full rounded-lg border-[1.5px] bg-transparent px-5 py-3 text-black outline-none transition focus:border-primary active:border-primary dark:border-gray-2 dark:bg-[#181818] dark:text-white dark:focus:border-primary"
                  />
                </div>

                <div class="mb-4.5">
                  <label class="mb-3 block text-sm font-medium text-black dark:text-white">
                    Particles
                  </label>
                  <input
                    type="text"
                    value={particles}
                    onChange={(e) => setParticles(e.target.value)}
                    placeholder="Enter number of particles"
                    class="w-full rounded-lg border-[1.5px] bg-transparent px-5 py-3 text-black outline-none transition focus:border-primary active:border-primary dark:border-gray-2 dark:bg-[#181818] dark:text-white dark:focus:border-primary"
                  />
                </div>

                <div class="mb-4.5">
                  <label class="mb-3 block text-sm font-medium text-black dark:text-white">
                    Iterations
                  </label>
                  <input
                    type="text"
                    value={iterations}
                    onChange={(e) => setIterations(e.target.value)}
                    placeholder="Enter number of iterations"
                    class="w-full rounded-lg border-[1.5px] bg-transparent px-5 py-3 text-black outline-none transition focus:border-primary active:border-primary dark:border-gray-2 dark:bg-[#181818] dark:text-white dark:focus:border-primary"
                  />
                </div>

                <button
                  type="submit"
                  class="flex w-full justify-center rounded-lg bg-primary p-3 font-medium text-gray hover:bg-opacity-90"
                  disabled={loading}
                >
                  {loading ? "Generating..." : "Generate Molecules"}
                </button>
              </div>
            </form>
          </div>
        </div>

        <div class="flex flex-col gap-9">
          <div class="rounded-lg border border-stroke bg-white p-3 shadow-default dark:border-[#121212] dark:bg-[#181818]">
            <h3 class="font-medium text-black dark:text-white">
              Molecule Generation History
            </h3>
            <div class="mt-4 max-h-96 overflow-y-auto">
              {history.map((entry: any, index) => (
                <div key={index} class="border-b border-stroke py-3">
                  <p class="text-sm text-black dark:text-white">
                    <span class="font-bold">SMILES:</span> {entry.smiles}
                  </p>
                  <p class="text-sm text-black dark:text-white">
                    <span class="font-bold">Molecules:</span>{" "}
                    {entry.numMolecules}
                  </p>
                  <p class="text-sm text-black dark:text-white">
                    <span class="font-bold">Date:</span>{" "}
                    {new Date(entry.createdAt).toLocaleDateString()}
                  </p>
                  <div class="mt-3">
                    <button
                      class="text-primary hover:underline"
                      onClick={() => setMolecules(entry.generatedMolecules)}
                    >
                      View Molecules
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {molecules.length > 0 && (
        <div class="mt-8 rounded-lg bg-white p-2">
          <div class="mt-8 flex flex-col  gap-2">
            <div class="grid grid-cols-1 gap-2 sm:grid-cols-3">
              {molecules.map((mol: any, index) => (
                <MoleculeStructure
                  key={index}
                  id={`mol-${index + 1}`}
                  structure={mol.structure}
                  scores={mol.score}
                />
              ))}
            </div>
          </div>
        </div>
      )}
    </DefaultLayout> --%>

    """
  end

  def  mount(_params, _session, socket) do
    {:ok, socket}
  end
end
