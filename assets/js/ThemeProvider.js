export default {
  applyTheme(theme) {
    const root = document.documentElement
    if (theme === "system") {
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
      root.classList.toggle("dark", prefersDark)
    } else {
      root.classList.toggle("dark", theme === "dark")
    }
  },

  mounted() {
    let theme = localStorage.getItem("theme") || "system"
    this.applyTheme(theme)
    this.pushEvent("theme:init", { theme })

    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
      if ((localStorage.getItem("theme") || "system") === "system") {
        this.applyTheme("system")
      }
    })

    this.handleEvent("theme:set", ({ theme }) => {
      localStorage.setItem("theme", theme)
      this.applyTheme(theme)
    })
  }
};
