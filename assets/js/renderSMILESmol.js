export default {
  // mounted() {
  //   this.canvas = new ChemDoodle.StructureCanvas(this.el.id, 500, 300);

  //   // Read data attributes from the element
  //   // const name = this.el.dataset.name;
  //   const smiles = this.el.dataset.smiles;
  //   // const weight = this.el.dataset.weight;
  //   // const usage = this.el.dataset.usage;

  //   if (smiles) {
  //     const mol = ChemDoodle.readSMILES(smiles);
  //     this.canvas.loadMolecule(mol);

  //     // const infoBox = document.getElementById("molecule-info");
  //     // infoBox.innerHTML = `
  //     //   <strong>${name}</strong><br>
  //     //   <b>SMILES:</b> ${smiles}<br>
  //     //   <b>Mol. Weight:</b> ${weight} g/mol<br>
  //     //   <b>Usage:</b> ${usage}
  //     // `;
  //   }
  // },

  mounted() {
    const smiles = this.el.dataset.smiles;
    const canvasId = this.el.id;
    const drawer = new SmilesDrawer.Drawer({ width: 300, height: 300 });

    SmilesDrawer.parse(
      smiles,
      function (tree) {
        drawer.draw(tree, canvasId, "light", false);
      },
      function (err) {
        console.error("SMILES parse error:", err);
      }
    );
  },
};
