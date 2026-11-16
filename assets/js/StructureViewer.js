import { loadSmilesDrawer } from "./loadScript";
import { copyText } from "./clipboard";

// Interactive 2D structure viewer (see ViewerComponents.structure_viewer/1).
//
//   zoom      buttons, "+" / "-" keys, Ctrl+wheel     (50% - 400%)
//   pan       drag, or arrow keys while zoomed
//   fit       button or "0" key: back to 100%, centred
//   labels    toggles smiles-drawer's terminalCarbons (label every carbon)
//   dark bg   redraws with smiles-drawer's dark theme
//   fullscreen, PNG download (current background), Copy SMILES
//   3D        explains why there is no 3D view (no coordinates are stored)
//
// The drawing is rendered at 2x resolution so zoom up to 200% stays crisp.
// Client state (zoom, pan, toggles) lives on this hook; the toolbar and
// viewport are phx-update="ignore" so server patches don't reset it.
const MIN = 0.5;
const MAX = 4;
const STEP = 1.25;
const DENSITY = 2;

export default {
  mounted() {
    this.smiles = this.el.dataset.smiles;
    this.w = Number(this.el.dataset.width) || 300;
    this.h = Number(this.el.dataset.height) || 300;
    this.zoom = 1;
    this.panX = 0;
    this.panY = 0;
    this.labels = false;
    this.dark = false;

    this.viewport = this.el.querySelector("[data-viewport]");
    // Client-owned stage inside the phx-update="ignore" viewport. LiveView strips
    // attributes it did not render from patched elements, so all client state
    // (background, zoom mirror, cursor) lives here, where it is never patched.
    this.stage = this.el.querySelector("[data-stage]");
    this.canvas = this.el.querySelector("[data-canvas]");
    this.status = this.el.querySelector("[data-status]");
    this.note3d = this.el.querySelector("[data-note-3d]");

    this.onClick = (event) => {
      const button = event.target.closest("button[data-action]");
      if (button && this.el.contains(button)) this.act(button.dataset.action, button);
    };
    this.onKey = (event) => this.key(event);
    this.onWheel = (event) => {
      if (!event.ctrlKey) return; // plain scroll keeps scrolling the page
      event.preventDefault();
      this.setZoom(this.zoom * (event.deltaY < 0 ? STEP : 1 / STEP));
    };
    this.onDown = (event) => this.dragStart(event);
    this.onMove = (event) => this.dragMove(event);
    this.onUp = () => (this.drag = null);
    this.onFullscreen = () => this.syncFullscreen();

    this.el.addEventListener("click", this.onClick);
    this.viewport.addEventListener("keydown", this.onKey);
    this.viewport.addEventListener("wheel", this.onWheel, { passive: false });
    this.viewport.addEventListener("pointerdown", this.onDown);
    window.addEventListener("pointermove", this.onMove);
    window.addEventListener("pointerup", this.onUp);
    document.addEventListener("fullscreenchange", this.onFullscreen);

    this.applyLayout();
    this.draw();

    // Re-fit when the container changes size (window resize, sidebar, etc.).
    if (window.ResizeObserver) {
      this.resizeObserver = new ResizeObserver(() => this.applyLayout());
      this.resizeObserver.observe(this.el);
    }
  },

  updated() {
    const next = this.el.dataset.smiles;
    if (next !== this.smiles) {
      this.smiles = next;
      this.draw();
    }
  },

  destroyed() {
    this.destroyed_ = true;
    if (this.resizeObserver) this.resizeObserver.disconnect();
    window.removeEventListener("pointermove", this.onMove);
    window.removeEventListener("pointerup", this.onUp);
    document.removeEventListener("fullscreenchange", this.onFullscreen);
  },

  // ---- rendering -------------------------------------------------------
  async draw() {
    const smiles = this.smiles;
    if (!smiles) return;
    try {
      await loadSmilesDrawer();
    } catch (err) {
      console.error(err);
      return this.fail("The structure viewer library could not be loaded.");
    }
    if (this.destroyed_ || smiles !== this.smiles) return;

    // smiles-drawer sizes its output from the canvas's CSS size (offsetWidth)
    // and resets the canvas dimensions itself. Give it the 2x CSS size for the
    // draw, then shrink the display back (applyLayout) so the 2x bitmap is
    // shown crisply at the normal size. Drawing at 2x into a 1x-sized canvas
    // would crop the molecule.
    this.canvas.style.width = `${this.w * DENSITY}px`;
    this.canvas.style.height = `${this.h * DENSITY}px`;
    const drawer = new window.SmilesDrawer.Drawer({
      width: this.w * DENSITY,
      height: this.h * DENSITY,
      terminalCarbons: this.labels,
    });
    window.SmilesDrawer.parse(
      smiles,
      (tree) => {
        if (this.destroyed_ || smiles !== this.smiles) return;
        this.canvas.getContext("2d").clearRect(0, 0, this.canvas.width, this.canvas.height);
        drawer.draw(tree, this.canvas, this.dark ? "dark" : "light", false);
        this.applyLayout();
      },
      (err) => {
        console.error("SMILES parse error:", err);
        this.fail("This SMILES string could not be drawn.");
      }
    );
  },

  fail(message) {
    this.applyLayout();
    const ctx = this.canvas.getContext("2d");
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.fillStyle = this.dark ? "#ddd" : "#555";
    ctx.font = `${12 * DENSITY}px sans-serif`;
    ctx.textAlign = "center";
    ctx.fillText(message.slice(0, 40), this.canvas.width / 2, this.canvas.height / 2);
    this.say(message);
  },

  applyLayout() {
    // The viewer is responsive: it never exceeds its container, so structures
    // are not cropped in narrow cards or on phones.
    const fs = document.fullscreenElement === this.el;
    const available = this.viewport.clientWidth || this.w;
    const side = fs
      ? Math.min(window.innerWidth, window.innerHeight - 64)
      : Math.max(120, Math.min(this.w, available));
    this.viewport.style.width = fs ? "100%" : "";
    this.viewport.style.height = fs ? "calc(100vh - 64px)" : `${side}px`;
    this.canvas.style.width = `${side}px`;
    this.canvas.style.height = `${side}px`;
    this.stage.style.background = this.dark ? "#1f2937" : "#ffffff";
    this.apply();
  },

  apply() {
    this.canvas.style.transform = `translate(${this.panX}px, ${this.panY}px) scale(${this.zoom})`;
    this.stage.style.cursor = this.zoom > 1 ? "grab" : "default";
    this.stage.dataset.zoom = String(Math.round(this.zoom * 100));
  },

  say(text) {
    if (this.status) this.status.textContent = text;
  },

  // ---- interaction -----------------------------------------------------
  setZoom(value) {
    this.zoom = Math.min(MAX, Math.max(MIN, value));
    if (this.zoom <= 1) {
      this.panX = 0;
      this.panY = 0;
    }
    this.apply();
    this.say(`Zoom ${Math.round(this.zoom * 100)}%`);
  },

  async act(action, button) {
    switch (action) {
      case "zoom-in":
        return this.setZoom(this.zoom * STEP);
      case "zoom-out":
        return this.setZoom(this.zoom / STEP);
      case "fit":
        this.panX = 0;
        this.panY = 0;
        this.setZoom(1);
        return this.say("Reset to 100%");
      case "labels":
        this.labels = !this.labels;
        button.setAttribute("aria-pressed", String(this.labels));
        this.say(this.labels ? "Labelling every carbon" : "Default labels");
        return this.draw();
      case "background":
        this.dark = !this.dark;
        button.setAttribute("aria-pressed", String(this.dark));
        this.applyLayout();
        this.say(this.dark ? "Dark background" : "Light background");
        return this.draw();
      case "fullscreen":
        return this.toggleFullscreen();
      case "png":
        return this.download();
      case "copy": {
        const ok = await copyText(this.smiles);
        return this.say(ok ? "SMILES copied" : "Copy failed: your browser blocked clipboard access");
      }
      case "3d": {
        const open = this.note3d.classList.toggle("hidden") === false;
        button.setAttribute("aria-pressed", String(open));
        return;
      }
    }
  },

  key(event) {
    const pan = 24;
    const handled = {
      "+": () => this.setZoom(this.zoom * STEP),
      "=": () => this.setZoom(this.zoom * STEP),
      "-": () => this.setZoom(this.zoom / STEP),
      "0": () => this.act("fit"),
      ArrowLeft: () => this.zoom > 1 && ((this.panX += pan), this.apply()),
      ArrowRight: () => this.zoom > 1 && ((this.panX -= pan), this.apply()),
      ArrowUp: () => this.zoom > 1 && ((this.panY += pan), this.apply()),
      ArrowDown: () => this.zoom > 1 && ((this.panY -= pan), this.apply()),
    }[event.key];
    if (handled) {
      event.preventDefault();
      handled();
    }
  },

  dragStart(event) {
    if (this.zoom <= 1) return;
    this.drag = { x: event.clientX, y: event.clientY, panX: this.panX, panY: this.panY };
    this.stage.style.cursor = "grabbing";
  },

  dragMove(event) {
    if (!this.drag) return;
    this.panX = this.drag.panX + (event.clientX - this.drag.x);
    this.panY = this.drag.panY + (event.clientY - this.drag.y);
    this.apply();
  },

  async toggleFullscreen() {
    if (document.fullscreenElement === this.el) return document.exitFullscreen();
    if (!this.el.requestFullscreen) return this.say("Full screen is not available in this browser");
    try {
      await this.el.requestFullscreen();
    } catch (_err) {
      this.say("Full screen was blocked by the browser");
    }
  },

  syncFullscreen() {
    const on = document.fullscreenElement === this.el;
    const button = this.el.querySelector("[data-action=fullscreen]");
    if (button) button.setAttribute("aria-pressed", String(on));
    this.applyLayout();
  },

  download() {
    const out = document.createElement("canvas");
    out.width = this.canvas.width;
    out.height = this.canvas.height;
    const ctx = out.getContext("2d");
    ctx.fillStyle = this.dark ? "#1f2937" : "#ffffff";
    ctx.fillRect(0, 0, out.width, out.height);
    ctx.drawImage(this.canvas, 0, 0);
    out.toBlob((blob) => {
      if (!blob) return this.say("PNG export failed");
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = this.el.dataset.filename || "molbind-structure.png";
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      this.say("PNG downloaded");
    }, "image/png");
  },
};
