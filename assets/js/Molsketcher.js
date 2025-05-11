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

    // Handle export button
    this.handleEvent("get_molecule", (format) => {
      const mol = this.sketcher.getMolecule();
      let data;

      switch (format) {
        case "mol":
          data = mol.toMolfile();
          break;
        case "smiles":
          data = mol.toSMILES();
          break;
        default:
          data = "Unsupported format";
      }

      // Send to LiveView
      this.pushEvent("molecule_data", { format, data });
    });
  }
}
 
