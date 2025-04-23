defmodule PhxMolbindWeb.MoleculeBankLive.MoleculeBank do
  use PhxMolbindWeb, :live_view

  def render(assigns) do
    ~H"""

    <%!-- <DefaultLayout>
      <ComponetHeader pageName="Molecule Bank" containActionButton={true} />
      <div class="flex flex-col gap-10">
        <MoleculeBankTable />
      </div>
    </DefaultLayout> --%>

    """
  end

  def mount(params, session, socket) do
    {:ok, socket}
  end
end
