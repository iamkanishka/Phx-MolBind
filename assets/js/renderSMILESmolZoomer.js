export default {
  mounted() {
    const canvas = this.el;
    const context = canvas.getContext("2d");
    const smiles = canvas.dataset.smiles;
    let scale = 1.0;
    let moleculeTree = null;

    const render = () => {
      context.clearRect(0, 0, canvas.width, canvas.height);

      const drawer = new SmilesDrawer.Drawer({
        width: canvas.width,
        height: canvas.height,
        scalingFactor: scale, // ← this is the correct way to zoom
      });

      drawer.draw(moleculeTree, canvas, "light", false);
    };

    SmilesDrawer.parse(
      smiles,
      (tree) => {
        moleculeTree = tree;
        SmilesDrawer.applyCoordinates(tree);
        render();
      },
      (err) => console.error("Error parsing SMILES:", err)
    );

    canvas.addEventListener("wheel", (event) => {
      event.preventDefault();
      const zoomFactor = 1.1;
      scale *= event.deltaY < 0 ? zoomFactor : 1 / zoomFactor;
      render();
    });
  },
};
