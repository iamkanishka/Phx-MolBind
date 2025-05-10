export default {
  mounted() {
    // Customize Jmol colors
    ChemDoodle.ELEMENT["H"].jmolColor = "black";
    ChemDoodle.ELEMENT["S"].jmolColor = "#B9A130";

    // Initialize the sketcher
    this.sketcher = new ChemDoodle.SketcherCanvas("sketcher", 500, 300, {
      useServices: true,
    });

    // Set sketcher styles
    this.sketcher.styles.atoms_displayTerminalCarbonLabels_2D = true;
    this.sketcher.styles.atoms_useJMOLColors = true;
    this.sketcher.styles.bonds_clearOverlaps_2D = true;
    this.sketcher.styles.shapes_color = "#c10000";

    // Force re-render
    this.sketcher.repaint();
  },
};
