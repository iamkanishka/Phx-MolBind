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

    this.media = window.matchMedia("(prefers-color-scheme: dark)")
    this.onMediaChange = () => {
      if ((localStorage.getItem("theme") || "system") === "system") {
        this.applyTheme("system")
      }
    }
    this.media.addEventListener("change", this.onMediaChange)

    this.handleEvent("theme:set", ({ theme }) => {
      localStorage.setItem("theme", theme)
      this.applyTheme(theme)
    })
  },

  destroyed() {
    if (this.media) this.media.removeEventListener("change", this.onMediaChange)
  }
};
