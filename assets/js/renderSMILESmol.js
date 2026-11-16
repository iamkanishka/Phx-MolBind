import { loadSmilesDrawer } from "./loadScript";

// Draws data-smiles onto the hook's <canvas>. smiles-drawer is loaded lazily
// the first time a structure is needed, and the canvas is redrawn whenever
// LiveView patches a new data-smiles onto the same element (previously a
// second generation run kept showing the first run's structures).
function message(canvas, text) {
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#555";
  ctx.font = "12px sans-serif";
  ctx.textAlign = "center";
  ctx.fillText(text, canvas.width / 2, canvas.height / 2);
}

export default {
  mounted() {
    this.lastSmiles = null;
    this.draw();
  },

  updated() {
    this.draw();
  },

  destroyed() {
    this.destroyed_ = true;
  },

  async draw() {
    const canvas = this.el;
    const smiles = canvas.dataset.smiles;
    if (!smiles || smiles === this.lastSmiles) return;
    this.lastSmiles = smiles;

    try {
      await loadSmilesDrawer();
    } catch (err) {
      console.error(err);
      message(canvas, "Structure viewer unavailable");
      return;
    }
    if (this.destroyed_ || canvas.dataset.smiles !== smiles) return;

    const width = Number(canvas.dataset.width) || canvas.width;
    const height = Number(canvas.dataset.height) || canvas.height;
    const drawer = new window.SmilesDrawer.Drawer({ width, height });

    window.SmilesDrawer.parse(
      smiles,
      (tree) => {
        if (this.destroyed_ || canvas.dataset.smiles !== smiles) return;
        canvas.getContext("2d").clearRect(0, 0, canvas.width, canvas.height);
        drawer.draw(tree, canvas, "light", false);
      },
      (err) => {
        console.error("SMILES parse error:", err);
        // Keep the original text; never alter the user's structure.
        message(canvas, "Cannot draw this SMILES");
      }
    );
  },
};
