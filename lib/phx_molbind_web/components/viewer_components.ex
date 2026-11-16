defmodule PhxMolbindWeb.ViewerComponents do
  @moduledoc """
  Shared 2D structure viewer used wherever a molecule is inspected.

  The `StructureViewer` hook draws the structure with smiles-drawer and
  provides zoom, pan, fit, label-all-carbons, background, full screen, PNG
  download and Copy SMILES. The toolbar and viewport are `phx-update="ignore"`
  so server re-renders never reset the user's zoom or toggles.

  3D: MolBind stores no 3D coordinates and never computes them, so the "3D"
  control only explains that, rather than showing an invented conformation.
  """
  use Phoenix.Component

  @doc """
  Renders a structure viewer.

  ## Attributes

    * `id` – unique DOM id (required; the hook needs it)
    * `smiles` – the structure to draw (required)
    * `canvas_id` – id for the inner canvas (so existing PNG buttons that
      target a canvas keep working); defaults to `"\#{id}-canvas"`
    * `size` – square size in CSS pixels (default 280)
    * `export` – include the PNG and Copy SMILES buttons (default true); pages
      that already offer those actions pass `false`
    * `filename` – download name for the PNG
  """
  attr :id, :string, required: true
  attr :smiles, :string, required: true
  attr :canvas_id, :string, default: nil
  attr :size, :integer, default: 280
  attr :export, :boolean, default: true
  attr :filename, :string, default: "molbind-structure.png"
  attr :label, :string, default: nil

  def structure_viewer(assigns) do
    assigns =
      assigns
      |> assign_new(:cid, fn -> assigns.canvas_id || "#{assigns.id}-canvas" end)
      |> assign(:name, assigns.label || "Structure: #{assigns.smiles}")

    ~H"""
    <div
      id={@id}
      phx-hook="StructureViewer"
      data-smiles={@smiles}
      data-width={@size}
      data-height={@size}
      data-filename={@filename}
      class="mx-auto mt-2 w-full max-w-full rounded border border-stroke bg-white dark:border-strokedark dark:bg-[#181818]"
      style={"max-width: #{@size + 2}px"}
    >
      <div
        id={"#{@id}-toolbar"}
        phx-update="ignore"
        role="toolbar"
        aria-label={"Viewer controls for " <> @name}
        class="flex flex-wrap gap-1 border-b border-stroke p-1 text-xs dark:border-strokedark"
      >
        <.tool action="zoom-in" label="Zoom in">+</.tool>
        <.tool action="zoom-out" label="Zoom out">−</.tool>
        <.tool action="fit" label="Reset zoom and position">Fit</.tool>
        <.tool action="labels" label="Label every carbon atom" pressed>C</.tool>
        <.tool action="background" label="Dark background" pressed>◐</.tool>
        <.tool action="fullscreen" label="Full screen" pressed>⛶</.tool>
        <.tool :if={@export} action="png" label="Download PNG">PNG</.tool>
        <.tool :if={@export} action="copy" label="Copy SMILES">Copy</.tool>
        <.tool action="3d" label="About 3D view" pressed>3D</.tool>
      </div>

      <div
        id={"#{@id}-viewport"}
        phx-update="ignore"
        data-viewport
        tabindex="0"
        role="group"
        aria-label={"Drawing of " <> @name <> ". Press plus or minus to zoom, zero to reset, arrow keys to pan when zoomed."}
        class="relative overflow-hidden focus-visible:outline focus-visible:outline-2 focus-visible:outline-accent"
        style={"height: #{@size}px"}
      >
        <div data-stage class="h-full w-full">
          <canvas
            id={@cid}
            data-canvas
            width={@size * 2}
            height={@size * 2}
            role="img"
            aria-label={@name}
            class="mx-auto origin-center touch-none"
            style={"width: #{@size}px; height: #{@size}px"}
          >
          </canvas>
        </div>
      </div>

      <p id={"#{@id}-status"} data-status role="status" aria-live="polite" class="sr-only"></p>
      <p
        id={"#{@id}-note"}
        data-note-3d
        phx-update="ignore"
        class="hidden border-t border-stroke p-2 text-xs text-gray-700 dark:border-strokedark dark:text-gray-300"
      >
        3D is not available for this molecule. MolBind stores no 3D coordinates and does not compute them, and a 2D drawing is not a conformation. The Molecule Bank's 3D view asks ChemDoodle's cloud service to generate coordinates for catalog entries.
      </p>
    </div>
    """
  end

  attr :action, :string, required: true
  attr :label, :string, required: true
  attr :pressed, :boolean, default: false
  slot :inner_block, required: true

  defp tool(assigns) do
    ~H"""
    <button
      type="button"
      data-action={@action}
      aria-label={@label}
      title={@label}
      aria-pressed={if @pressed, do: "false"}
      class="min-h-8 min-w-8 rounded border border-stroke px-2 py-1 hover:bg-gray-2 aria-pressed:bg-accent/10 dark:border-strokedark dark:text-white dark:hover:bg-white/5"
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
