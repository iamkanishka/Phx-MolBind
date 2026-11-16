// Scroll behaviour for the chat log (put on the phx-update="stream" container).
//
//   * Stay pinned to the newest message while the reader is at the bottom.
//   * If the reader has scrolled up, never move their view; instead reveal
//     the "New messages" button (id in data-jump).
//   * When older messages are prepended at the top, keep the same messages
//     in view instead of jumping.
const NEAR_BOTTOM_PX = 48;

export default {
  mounted() {
    this.jump = document.getElementById(this.el.dataset.jump);
    this.onScroll = () => {
      if (this.atBottom()) this.hideJump();
    };
    this.onJump = () => {
      this.scrollToBottom();
      this.hideJump();
    };
    this.el.addEventListener("scroll", this.onScroll, { passive: true });
    this.jump?.addEventListener("click", this.onJump);
    this.scrollToBottom();
  },

  beforeUpdate() {
    this.wasAtBottom = this.atBottom();
    this.prevHeight = this.el.scrollHeight;
    this.prevTop = this.el.scrollTop;
    this.prevFirstId = this.el.firstElementChild ? this.el.firstElementChild.id : null;
  },

  updated() {
    if (this.wasAtBottom) {
      this.scrollToBottom();
      return;
    }
    const grew = this.el.scrollHeight - this.prevHeight;
    if (grew <= 0) return;

    // A different first message means older history was prepended at the
    // top: keep the reader looking at the same messages. Otherwise content
    // was appended at the bottom: leave the view alone and offer the jump.
    const firstId = this.el.firstElementChild ? this.el.firstElementChild.id : null;
    if (firstId !== this.prevFirstId) {
      this.el.scrollTop = this.prevTop + grew;
    } else {
      this.showJump();
    }
  },

  destroyed() {
    this.el.removeEventListener("scroll", this.onScroll);
    this.jump?.removeEventListener("click", this.onJump);
  },

  atBottom() {
    const { scrollTop, scrollHeight, clientHeight } = this.el;
    return scrollHeight - scrollTop - clientHeight <= NEAR_BOTTOM_PX;
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  },

  showJump() {
    this.jump?.classList.remove("hidden");
  },

  hideJump() {
    this.jump?.classList.add("hidden");
  },
};
