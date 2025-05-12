export default {
  mounted() {
    const smiles = this.el.dataset.smiles;
    const cheight = this.el.dataset.height;
    const cwidth = this.el.dataset.width;

    const canvasId = this.el.id;
    const drawer = new SmilesDrawer.Drawer({ width: cwidth, height: cheight });

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
