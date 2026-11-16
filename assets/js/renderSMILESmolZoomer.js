import { loadSmilesDrawer } from "./loadScript";

export default {
  async mounted() {
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

    try {
      await loadSmilesDrawer();
    } catch (err) {
      console.error(err);
      return;
    }

    SmilesDrawer.parse(
      smiles,
      (tree) => {
        moleculeTree = tree;
        SmilesDrawer.applyCoordinates(tree);
        render();
      },
      (err) => console.error("Error parsing SMILES:", err)
    );

    this.onWheel = (event) => {
      event.preventDefault();
      const zoomFactor = 1.1;
      scale *= event.deltaY < 0 ? zoomFactor : 1 / zoomFactor;
      render();
    };
    canvas.addEventListener("wheel", this.onWheel, { passive: false });
  },

  destroyed() {
    if (this.onWheel) this.el.removeEventListener("wheel", this.onWheel);
  },
};
