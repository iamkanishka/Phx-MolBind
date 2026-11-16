// Ctrl/Cmd+K navigation palette.
//
// The server renders the palette as a native <dialog> containing ordinary
// <a> links (see Layouts.command_palette/1). This hook only:
//   * opens/closes the dialog (Ctrl/Cmd+K, the top bar button's
//     "palette:open" event, Escape handled natively by <dialog>)
//   * filters the links by the typed text
//   * moves the highlighted option with ArrowUp/ArrowDown and activates it on Enter
// Activating an option clicks the real link, so LiveView performs its normal
// live navigation — no private LiveSocket APIs are used.
export default {
  mounted() {
    this.input = this.el.querySelector("input");
    this.empty = this.el.querySelector("[data-palette-empty]");
    this.active = -1;

    this.onKeydownWindow = (event) => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        this.el.open ? this.close() : this.open();
      }
    };
    this.onOpenRequest = () => this.open();
    this.onInput = () => this.filter();
    this.onKeydownInput = (event) => this.handleKey(event);
    this.onClickDialog = (event) => {
      // Click on the backdrop (the dialog element itself) closes it.
      if (event.target === this.el) this.close();
      // Following a link closes the palette.
      if (event.target.closest("[data-palette-item]")) this.close();
    };

    window.addEventListener("keydown", this.onKeydownWindow);
    this.el.addEventListener("palette:open", this.onOpenRequest);
    this.input.addEventListener("input", this.onInput);
    this.input.addEventListener("keydown", this.onKeydownInput);
    this.el.addEventListener("click", this.onClickDialog);
  },

  destroyed() {
    window.removeEventListener("keydown", this.onKeydownWindow);
    this.el.removeEventListener("palette:open", this.onOpenRequest);
    this.input.removeEventListener("input", this.onInput);
    this.input.removeEventListener("keydown", this.onKeydownInput);
    this.el.removeEventListener("click", this.onClickDialog);
    if (this.el.open) this.el.close();
  },

  items() {
    return Array.from(this.el.querySelectorAll("[data-palette-item]")).filter(
      (item) => !item.closest("li").classList.contains("hidden")
    );
  },

  open() {
    if (this.el.open) return;
    this.previousFocus = document.activeElement;
    this.input.value = "";
    this.filter();
    this.el.showModal();
    this.input.focus();
  },

  close() {
    if (this.el.open) this.el.close();
    if (this.previousFocus && this.previousFocus.focus) this.previousFocus.focus();
  },

  filter() {
    const query = this.input.value.trim().toLowerCase();
    let visible = 0;
    this.el.querySelectorAll("li[data-label]").forEach((li) => {
      const match = query === "" || li.dataset.label.includes(query);
      li.classList.toggle("hidden", !match);
      if (match) visible += 1;
    });
    this.empty.classList.toggle("hidden", visible !== 0);
    this.setActive(visible > 0 ? 0 : -1);
  },

  setActive(index) {
    const items = this.items();
    items.forEach((item) => item.removeAttribute("aria-selected"));
    this.active = index;
    if (index >= 0 && items[index]) {
      items[index].setAttribute("aria-selected", "true");
      items[index].scrollIntoView({ block: "nearest" });
      this.input.setAttribute("aria-activedescendant", items[index].id || "");
    }
  },

  handleKey(event) {
    const items = this.items();
    if (items.length === 0) return;
    if (event.key === "ArrowDown") {
      event.preventDefault();
      this.setActive((this.active + 1) % items.length);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      this.setActive((this.active - 1 + items.length) % items.length);
    } else if (event.key === "Enter" && items[this.active]) {
      event.preventDefault();
      items[this.active].click();
    }
  },
};
