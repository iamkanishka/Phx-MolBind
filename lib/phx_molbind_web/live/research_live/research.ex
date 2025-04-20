defmodule PhxMolbindWeb.ResearchLive.Research do
   use PhxMolbindWeb, :live_view;

   def render(assigns) do
    ~H"""

    <DefaultLayout>
      <div class="container mx-auto h-[140dvh] p-0">
        <div class="mb-6 flex flex-col items-center md:flex-row md:justify-between">
          <h2 class="text-title-md2 font-semibold text-black dark:text-white">
            Compound Search{" "}
          </h2>
          <div class="relative mt-4 flex flex-1 md:mt-0 md:justify-end">
            <input
              type="text"
              value={compoundName}
              onChange={(e) => setCompoundName(e.target.value)}
              onKeyDown={handleKeyDown}
              class="border-gray-300 w-full rounded-lg border bg-white p-3 pl-10 text-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 md:w-96"
              placeholder="Enter a compound name"
            />
            <span class="absolute inset-y-0 right-3 flex items-center">
              <Search class="text-gray-500" />
            </span>
          </div>
        </div>

        {error && <p class="text-red-600 mt-6">{error}</p>}

        {compoundData && (
          <div class="mt-8 grid grid-cols-1 gap-6 md:grid-cols-2">
            <div class="dark:bg-gray-800  space-y-3 rounded-lg bg-white p-6  shadow-md">
              <h2 class="text-gray-700 mb-4 text-xl text-black  dark:text-white">
                Basic Information
              </h2>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  Molecular Formula:
                </strong>{" "}
                {compoundData.MolecularFormula}
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  Molecular Weight:
                </strong>{" "}
                {compoundData.MolecularWeight} g/mol
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  InChIKey:
                </strong>{" "}
                {compoundData.InChIKey}
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  Canonical SMILES:
                </strong>{" "}
                <MoleculeStructure
                  id={`${compoundData.CanonicalSMILES}`}
                  structure={compoundData.CanonicalSMILES}
                />
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  Isomeric SMILES:
                </strong>{" "}
                {compoundData.IsomericSMILES}
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  IUPAC Name:
                </strong>{" "}
                {compoundData.IUPACName}
              </p>
            </div>

            <div class="dark:bg-gray-800 space-y-3 rounded-lg bg-white p-6 shadow-md">
              <h2 class="text-gray-700 mb-4 text-xl text-black  dark:text-white">
                Physical Properties
              </h2>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  XLogP:
                </strong>{" "}
                {compoundData.XLogP}
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  Exact Mass:
                </strong>{" "}
                {compoundData.ExactMass} g/mol
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  Monoisotopic Mass:
                </strong>{" "}
                {compoundData.MonoisotopicMass} g/mol
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  Topological Polar Surface Area (TPSA):
                </strong>{" "}
                {compoundData.TPSA} Å²
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  Complexity:
                </strong>{" "}
                {compoundData.Complexity}
              </p>
              <p>
                <strong class="text-gray-600 dark:text-gray-300">
                  Charge:
                </strong>{" "}
                {compoundData.Charge}
              </p>
            </div>

            <div class="dark:bg-gray-800 space-y-3 rounded-lg bg-white p-6 shadow-md md:col-span-2">
              <h2 class="text-gray-700 mb-4 text-xl text-black  dark:text-white">
                Additional Information
              </h2>
              <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
                <p>
                  <strong class="text-gray-600 dark:text-gray-300">
                    Hydrogen Bond Donors:
                  </strong>{" "}
                  {compoundData.HBondDonorCount}
                </p>
                <p>
                  <strong class="text-gray-600 dark:text-gray-300">
                    Hydrogen Bond Acceptors:
                  </strong>{" "}
                  {compoundData.HBondAcceptorCount}
                </p>
                <p>
                  <strong class="text-gray-600 dark:text-gray-300">
                    Rotatable Bonds:
                  </strong>{" "}
                  {compoundData.RotatableBondCount}
                </p>
                <p>
                  <strong class="text-gray-600 dark:text-gray-300">
                    Heavy Atom Count:
                  </strong>{" "}
                  {compoundData.HeavyAtomCount}
                </p>
              </div>
            </div>
          </div>
        )}
      </div>
    </DefaultLayout>

    """
   end


   def mount(params, session, socket) do
    {:ok, socket}

   end

end
