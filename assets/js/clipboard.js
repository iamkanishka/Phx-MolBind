// Copy text to the clipboard. Uses the async Clipboard API on secure
// contexts and falls back to a hidden textarea + execCommand elsewhere.
// Resolves to true on success, false otherwise (never throws).
export async function copyText(text) {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch (_err) {
    // fall through to the legacy path
  }
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
}
