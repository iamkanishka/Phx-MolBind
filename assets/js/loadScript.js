// Loads a third-party script once, on demand, and resolves when it is ready.
// Concurrent callers share one <script> tag/promise. A failed load is not
// cached, so a later call can retry (e.g. after a transient network error).
const pending = new Map();

export default function loadScript(src, isReady) {
  if (isReady && isReady()) return Promise.resolve();
  if (pending.has(src)) return pending.get(src);

  const promise = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => {
      pending.delete(src);
      script.remove();
      reject(new Error(`Failed to load script: ${src}`));
    };
    document.head.appendChild(script);
  });

  pending.set(src, promise);
  return promise;
}

export const SMILES_DRAWER_SRC =
  "https://unpkg.com/smiles-drawer@2.0.1/dist/smiles-drawer.min.js";

export const loadSmilesDrawer = () =>
  loadScript(SMILES_DRAWER_SRC, () => typeof window.SmilesDrawer !== "undefined");
