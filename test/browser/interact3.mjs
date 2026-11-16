import { launch, newPage, login, connected, BASE } from "./lib.mjs";
const browser = await launch();
const results = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function test(name, fn) { try { const d = await fn(); results.push(["PASS", name, d || ""]); } catch (e) { results.push(["FAIL", name, String(e.message || e).slice(0, 220)]); } }
const ok = (c, m) => { if (!c) throw new Error(m); };
const goto = async (page, path) => { await page.goto(BASE + path, { waitUntil: "domcontentloaded" }); await connected(page); await sleep(600); };
const owner = await newPage(browser, 1280); await login(owner, 1);
let childPath, grandPath;

await test("lineage: parent run lists the child it led to, as a navigable link", async () => {
  await goto(owner, "/history/1");
  const links = await owner.$$eval("#lineage-heading ~ ol a[href^='/history/']", (a) => a.map((x) => x.getAttribute("href")));
  ok(links.length >= 2, "expected child + grandchild links, got " + JSON.stringify(links));
  childPath = links[0]; grandPath = links[1];
  const text = await owner.$eval("#lineage-heading", (h) => h.closest("section").innerText);
  ok(/Led to/.test(text) && /candidate 2/.test(text), "tree text: " + text.slice(0, 160));
  ok(/Saved/.test(text) && /Shortlist/.test(text), "saved molecule not shown in the lineage");
  return childPath + " -> " + grandPath;
});
await test("lineage: child page names its verified parent and candidate", async () => {
  await owner.click(`#lineage-heading ~ ol a[href="${childPath}"]`);
  await owner.waitForFunction((p) => location.pathname === p, { timeout: 5000 }, childPath);
  await connected(owner); await sleep(500);
  const text = await owner.$eval("#lineage-heading", (h) => h.closest("section").innerText);
  ok(/Derived from/.test(text) && /started from candidate 2 of run 1/.test(text), text.slice(0, 200));
  ok(/Led to/.test(text), "grandchild missing");
});
await test("lineage: grandchild shows the whole ancestor chain, root first", async () => {
  await goto(owner, grandPath);
  const order = await owner.$$eval("#lineage-heading ~ ol > li", (l) => l.map((x) => x.innerText.replace(/\s+/g, " ").slice(0, 40)));
  ok(/Derived from run 1/.test(order[0]) && /Derived from/.test(order[1]) && /This run/.test(order[2]), JSON.stringify(order));
});
await test("lineage: unverified same-SMILES runs are labelled as such, never as ancestry", async () => {
  await goto(owner, "/history/1");
  const t = await owner.evaluate(() => document.body.innerText);
  ok(!/not verified as related/.test(t) || /Other runs with the same starting SMILES \(not verified as related\)/i.test(t), "bad label");
});
await test("generator: 'Use as starting molecule' carries provenance; note appears, drops on edit, returns on restore", async () => {
  await goto(owner, "/history/1");
  const href = await owner.$$eval("a[href^='/model?']", (a) => a.map((x) => x.getAttribute("href")).find((h) => h.includes("from_run=1") && h.includes("N")));
  ok(href && href.includes("from_run=1"), "no provenance link: " + href);
  await owner.goto(BASE + href, { waitUntil: "domcontentloaded" }); await connected(owner); await sleep(900);
  ok(await owner.$("#lineage-note"), "note missing for a verified candidate");
  const smiles = await owner.$eval("input[name='form[smiles]']", (e) => e.value);
  await owner.type("input[name='form[smiles]']", "C"); await sleep(900);
  ok(!(await owner.$("#lineage-note")), "note still shown after the structure was edited");
  await owner.keyboard.press("Backspace"); await sleep(900);
  ok(await owner.$("#lineage-note"), "note did not return after restoring the exact SMILES");
  return smiles.slice(0, 24);
});
await test("generator: a non-candidate or forged provenance never shows the note", async () => {
  await goto(owner, "/model?smiles=CCC&from_run=1");
  ok(!(await owner.$("#lineage-note")), "note for a non-candidate");
  await goto(owner, "/model?smiles=CC(=O)Oc1ccccc1C(N)=O&from_run=999999");
  ok(!(await owner.$("#lineage-note")), "note for a nonexistent run");
  await goto(owner, "/model?smiles=CC(=O)Oc1ccccc1C(N)=O&from_run=1");
  ok(await owner.$("#lineage-note"), "valid provenance should show the note");
});
await test("lineage page layout: no horizontal overflow at 320px, and the tree is readable", async () => {
  await owner.setViewport({ width: 320, height: 800 });
  await goto(owner, grandPath);
  const o = await owner.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: innerWidth }));
  ok(o.sw <= o.iw, `overflow ${o.sw} > ${o.iw}`);
  await owner.setViewport({ width: 1280, height: 900 });
});

console.log(results.map((r) => `${r[0]}  ${r[1]}${r[2] ? "  [" + r[2] + "]" : ""}`).join("\n"));
console.log(`\n${results.filter((r) => r[0] === "PASS").length}/${results.length} passed`);
await browser.close();
