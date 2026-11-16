// Keyboard navigation for a suggestions listbox rendered by the server.
//
// Put the hook on a wrapper containing the text input and a
// <ul role="listbox"> whose <li role="option"> items carry phx-click.
//   ArrowDown/ArrowUp  move the highlight (aria-selected)
//   Enter              activates the highlighted option (clicks it); with no
//                      highlight the form submits normally
//   Escape             pushes "hide_dropdown"
// Highlight is reset whenever LiveView re-renders the list.
export default {
  mounted() {
    this.active = -1;
    this.onKeydown = (event) => {
      if (event.target.tagName !== "INPUT") return;
      const options = this.options();
      if (event.key === "Escape") {
        this.pushEvent("hide_dropdown", {});
        return;
      }
      if (options.length === 0) return;
      if (event.key === "ArrowDown") {
        event.preventDefault();
        this.setActive((this.active + 1) % options.length);
      } else if (event.key === "ArrowUp") {
        event.preventDefault();
        this.setActive((this.active - 1 + options.length) % options.length);
      } else if (event.key === "Enter" && this.active >= 0 && options[this.active]) {
        event.preventDefault();
        options[this.active].click();
      }
    };
    this.el.addEventListener("keydown", this.onKeydown);
  },

  updated() {
    this.active = -1;
  },

  destroyed() {
    this.el.removeEventListener("keydown", this.onKeydown);
  },

  options() {
    return Array.from(this.el.querySelectorAll('[role="option"]'));
  },

  setActive(index) {
    const options = this.options();
    options.forEach((o) => o.removeAttribute("aria-selected"));
    this.active = index;
    const option = options[index];
    if (option) {
      option.setAttribute("aria-selected", "true");
      option.scrollIntoView({ block: "nearest" });
      const input = this.el.querySelector("input");
      if (input && option.id) input.setAttribute("aria-activedescendant", option.id);
    }
  },
};
