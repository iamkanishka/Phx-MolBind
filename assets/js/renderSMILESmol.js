let Hooks = {}

Hooks.ChemDoodleViewer = {
  mounted() {
    this.canvas = new ChemDoodle.StructureCanvas(this.el.id, 500, 300);

    this.handleEvent("render_molecule", ({ name, smiles, weight, usage }) => {
      const mol = ChemDoodle.readSMILES(smiles);
      this.canvas.loadMolecule(mol);

      const infoBox = document.getElementById("molecule-info");
      infoBox.innerHTML = `
        <strong>${name}</strong><br>
        <b>SMILES:</b> ${smiles}<br>
        <b>Mol. Weight:</b> ${weight} g/mol<br>
        <b>Usage:</b> ${usage}
      `;
    });
  }
};

export default Hooks;
