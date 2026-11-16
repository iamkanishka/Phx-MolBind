// Downloads the <canvas> named by data-canvas-id as a PNG
// (filename from data-filename). The canvas is drawn on a transparent
// background by smiles-drawer, so it is composited onto white first.
export default {
  mounted() {
    this.original = this.el.textContent;
    this.onClick = () => {
      const source = document.getElementById(this.el.dataset.canvasId);
      if (!source) return this.report("Not ready");

      const out = document.createElement("canvas");
      out.width = source.width;
      out.height = source.height;
      const ctx = out.getContext("2d");
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, out.width, out.height);
      ctx.drawImage(source, 0, 0);

      out.toBlob((blob) => {
        if (!blob) return this.report("Download failed");
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = this.el.dataset.filename || "structure.png";
        document.body.appendChild(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
      }, "image/png");
    };
    this.el.addEventListener("click", this.onClick);
  },

  report(text) {
    this.el.textContent = text;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => (this.el.textContent = this.original), 1800);
  },

  destroyed() {
    clearTimeout(this.timer);
    this.el.removeEventListener("click", this.onClick);
  },
};
