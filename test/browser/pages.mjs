import { launch, newPage, login, connected, BASE } from "./lib.mjs";
const browser = await launch();
const pages = ["/", "/model", "/research", "/history", "/history/1", "/collections", "/collections/1", "/molecule-bank", "/molecule-bank?view=table", "/sketcher", "/message", "/profile", "/settings"];
const widths = [320, 375, 768, 1280];
const rows = [];
const page = await newPage(browser, 1280);
await login(page);
for (const w of widths) {
  await page.setViewport({ width: w, height: 900 });
  for (const path of pages) {
    page.log.console.length = 0; page.log.pageErrors.length = 0; page.log.failed.length = 0;
    const t0 = Date.now();
    let status = "ok";
    try { await page.goto(BASE + path, { waitUntil: "domcontentloaded" }); await connected(page); } catch (e) { status = "NOT-CONNECTED"; }
    const ttc = Date.now() - t0;
    await new Promise((r) => setTimeout(r, 700));
    let m; try { m = await page.evaluate(() => {
      const de = document.documentElement;
      const over = [...document.querySelectorAll("body *")].filter((el) => { const r = el.getBoundingClientRect(); return r.width > 0 && r.right > innerWidth + 1 && !el.closest("[class*=overflow-x-auto], dialog, #app-sidebar, [role=log]"); }).slice(0, 3).map((el) => el.tagName + "." + String(el.className).slice(0, 50));
      return { scrollW: de.scrollWidth, innerW: innerWidth, over, path: location.pathname };
    }); } catch (e) { m = { scrollW: 0, innerW: 1, over: [], path: "NAVIGATED-DURING-MEASURE" }; }
    if (w === 375 || path === "/" || path === "/model") await page.screenshot({ path: `/tmp/shots/${w}${path.replace(/[\/?=]/g, "_") || "_root"}.png` });
    rows.push({ w, path, status, ttcMs: ttc, hOverflow: m.scrollW > m.innerW, over: m.over, consoleErrs: [...page.log.console, ...page.log.pageErrors].slice(0, 3), failed: page.log.failed.slice(0, 2), redirectedTo: m.path !== path.split("?")[0] ? m.path : undefined });
  }
}
for (const r of rows.filter((r) => r.status !== "ok" || r.hOverflow || r.consoleErrs.length || r.failed.length || r.redirectedTo)) console.log("FAIL", r.w, r.path, r.status, r.hOverflow ? "overflow:" + r.over.join("|").slice(0,90) : "", r.consoleErrs.join(";").slice(0,80));
console.log("TOTAL page loads:", rows.length, "| all OK:", rows.every((r) => r.status === "ok" && !r.hOverflow && !r.consoleErrs.length && !r.failed.length && !r.redirectedTo));
console.log("external requests blocked:", [...new Set(page.log.external)].slice(0, 6));
const ttcs = rows.map((r) => r.ttcMs).sort((a, b) => a - b);
console.log("time-to-LiveView-connected ms: median", ttcs[Math.floor(ttcs.length / 2)], "p90", ttcs[Math.floor(ttcs.length * 0.9)], "max", ttcs.at(-1));
await browser.close();
