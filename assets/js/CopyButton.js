// Copies the element's data-copy value to the clipboard and reports the
// outcome on the button itself (and to assistive tech via the label change).
export default {
  mounted() {
    this.original = this.el.textContent;
    this.onClick = async () => {
      const text = this.el.dataset.copy || "";
      let ok = false;
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
          ok = true;
        }
      } catch (_err) {
        ok = false;
      }
      if (!ok) ok = this.legacyCopy(text);
      this.el.textContent = ok ? "Copied" : "Copy failed";
      clearTimeout(this.timer);
      this.timer = setTimeout(() => (this.el.textContent = this.original), 1800);
    };
    this.el.addEventListener("click", this.onClick);
  },

  legacyCopy(text) {
    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    let ok = false;
    try {
      ok = document.execCommand("copy");
    } catch (_err) {
      ok = false;
    }
    area.remove();
    return ok;
  },

  destroyed() {
    clearTimeout(this.timer);
    this.el.removeEventListener("click", this.onClick);
  },
};
