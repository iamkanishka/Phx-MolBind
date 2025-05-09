export default {
  mounted() {
    const smiles = this.el.dataset.smiles;
    const viewerId = this.el.id;

    // Fetch MOL format from NIH Cactus (SMILES → MOL)
    fetch(
      `https://cactus.nci.nih.gov/chemical/structure/${encodeURIComponent(
        smiles
      )}/sdf`
    )
      .then((res) => res.text())
      .then((data) => {
        const element = this.el;
        const config = { backgroundColor: "white" };
        const viewer = $3Dmol.createViewer(element, config);

        viewer.addModel(data, "sdf");
        viewer.setStyle({}, { stick: {}, sphere: { scale: 0.3 } });
        viewer.zoomTo();
        viewer.render();
      })
      .catch((err) => console.error("3D rendering error:", err));
  },
};

Molecule3DHook;
