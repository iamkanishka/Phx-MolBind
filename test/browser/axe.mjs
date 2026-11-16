import fs from "fs";
import { launch, newPage, login, connected, BASE } from "./lib.mjs";
const axeSrc = fs.readFileSync("node_modules/axe-core/axe.min.js", "utf8");
const browser = await launch();
const pages = ["/", "/model", "/research", "/history", "/history/1", "/history/compare?a=1&b=2", "/collections", "/collections/1", "/molecule-bank", "/sketcher", "/message", "/profile", "/settings"];
console.log("pages scanned per theme: " + (pages.length + 1) + " (incl. public share page)");
const summary = {};
for (const theme of ["light", "dark"]) {
  const page = await newPage(browser, 1280);
  await page.evaluateOnNewDocument((t) => localStorage.setItem("theme", t), theme);
  await login(page);
  for (const path of pages) {
    await page.goto(BASE + path, { waitUntil: "domcontentloaded" });
    try { await connected(page); } catch (e) { console.log("no connect", path); continue; }
    await new Promise((r) => setTimeout(r, 1200));
    await page.evaluate(axeSrc);
    const res = await page.evaluate(async () => {
      const r = await axe.run(document, { runOnly: { type: "tag", values: ["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa", "best-practice"] } });
      return r.violations.map((v) => ({ id: v.id, impact: v.impact, help: v.help, n: v.nodes.length, sample: v.nodes.slice(0, 2).map((n) => n.target.join(" ").slice(0, 70) + " :: " + (n.any[0]?.message || n.all[0]?.message || n.none[0]?.message || "").slice(0, 90)) }));
    });
    for (const v of res) {
      const key = `${v.impact}|${v.id}`;
      summary[key] ??= { help: v.help, themes: new Set(), pages: new Set(), nodes: 0, sample: v.sample[0] };
      summary[key].themes.add(theme); summary[key].pages.add(path); summary[key].nodes += v.n;
    }
  }
  // Public share page, scanned as an anonymous visitor in the same theme.
  await page.goto(BASE + "/history/1", { waitUntil: "domcontentloaded" }); await connected(page);
  await new Promise((r) => setTimeout(r, 600));
  await page.select("#share-panel-expiry", "1");
  await page.click("#share-panel form button[type=submit]");
  await page.waitForSelector("#share-panel-url");
  const shareUrl = await page.$eval("#share-panel-url", (e) => e.value);
  const visitor = await newPage(browser, 1280);
  await visitor.evaluateOnNewDocument((t) => localStorage.setItem("theme", t), theme);
  await visitor.goto(shareUrl, { waitUntil: "domcontentloaded" }); await connected(visitor);
  await new Promise((r) => setTimeout(r, 1500));
  await visitor.evaluate(axeSrc);
  const pub = await visitor.evaluate(async () => { const r = await axe.run(document, { runOnly: { type: "tag", values: ["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa", "best-practice"] } }); return r.violations.map((v) => ({ id: v.id, impact: v.impact, help: v.help, n: v.nodes.length, sample: v.nodes.slice(0, 2).map((n) => n.target.join(" ").slice(0, 70) + " :: " + (n.any[0]?.message || n.all[0]?.message || n.none[0]?.message || "").slice(0, 90)) })); });
  for (const v of pub) { const key = `${v.impact}|${v.id}`; summary[key] ??= { help: v.help, themes: new Set(), pages: new Set(), nodes: 0, sample: v.sample[0] }; summary[key].themes.add(theme); summary[key].pages.add("/s/:token"); summary[key].nodes += v.n; }
  await visitor.ctx.close();
  // revoke so repeated runs do not accumulate live links
  await page.click("#share-panel button[phx-click=revoke]").catch(() => {});
  await page.ctx.close();
}
const order = { critical: 0, serious: 1, moderate: 2, minor: 3 };
const rows = Object.entries(summary).sort((a, b) => order[a[0].split("|")[0]] - order[b[0].split("|")[0]] || b[1].nodes - a[1].nodes);
for (const [k, v] of rows) console.log(`${k}  nodes=${v.nodes} themes=${[...v.themes]} pages=${v.pages.size}\n    ${v.help}\n    e.g. ${v.sample}`);
console.log("\nviolation types:", rows.length, "| pages x themes scanned:", pages.length * 2);
await browser.close();
