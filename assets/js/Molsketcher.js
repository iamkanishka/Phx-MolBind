export default {
  mounted() {
    // Initialize sketcher
    ChemDoodle.ELEMENT['H'].jmolColor = 'black';
    ChemDoodle.ELEMENT['S'].jmolColor = '#B9A130';
    
    this.sketcher = new ChemDoodle.SketcherCanvas('sketcher', 500, 300, { useServices: true });
    this.sketcher.styles.atoms_displayTerminalCarbonLabels_2D = true;
    this.sketcher.styles.atoms_useJMOLColors = true;
    this.sketcher.styles.bonds_clearOverlaps_2D = true;
    this.sketcher.styles.shapes_color = '#000000';
    this.sketcher.repaint();

    // ChemDoodle builds its toolbar with title-only controls, which screen
    // readers may not announce. Mirror each title into aria-label, now and
    // whenever the widget adds more controls (dropdowns open lazily).
    const labelWidgets = () => {
      document
        .querySelectorAll("[id^='sketcher_'] [title], [id^='sketcher_'][title]")
        .forEach((el) => {
          if (!el.hasAttribute("aria-label") && el.title) el.setAttribute("aria-label", el.title);
        });
    };
    labelWidgets();
    this.labelObserver = new MutationObserver(labelWidgets);
    this.labelObserver.observe(document.body, { childList: true, subtree: true });

    // Export on request from the LiveView. Failures are reported back so the
    // page can show them instead of silently doing nothing.
    this.handleEvent("get_molecule", ({ format }) => {
      try {
        const mol = this.sketcher.getMolecule();
        if (!mol || !mol.atoms || mol.atoms.length === 0) {
          this.pushEvent("molecule_error", { message: "The canvas is empty. Draw a molecule first." });
          return;
        }

        let data;
        switch (format) {
          case "mol":
            // toMolfile() is what this page used before; writeMOL is
            // ChemDoodle's documented writer. Neither could be exercised
            // without a browser, so fall back between them and fail loudly.
            data =
              typeof mol.toMolfile === "function"
                ? mol.toMolfile()
                : ChemDoodle.writeMOL(mol);
            break;
          case "smiles":
            if (typeof mol.toSMILES !== "function") {
              this.pushEvent("molecule_error", { message: "This sketcher build cannot export SMILES." });
              return;
            }
            data = mol.toSMILES();
            break;
          default:
            this.pushEvent("molecule_error", { message: `Unsupported export format: ${format}` });
            return;
        }

        if (typeof data !== "string" || data.trim() === "") {
          this.pushEvent("molecule_error", { message: "The sketcher could not produce this format for the drawn structure." });
          return;
        }
        this.pushEvent("molecule_data", { format, data });
      } catch (err) {
        console.error("Sketcher export failed:", err);
        this.pushEvent("molecule_error", { message: "Export failed. The structure may contain features this format cannot represent." });
      }
    });
  },

  destroyed() {
    if (this.labelObserver) this.labelObserver.disconnect();
  },
}
