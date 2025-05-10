export default {
  mounted() {
    const smiles = this.el.dataset.smiles;
    const canvasId = this.el.id;
    const drawer = new SmilesDrawer.Drawer({ width: 200, height: 200 });

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
