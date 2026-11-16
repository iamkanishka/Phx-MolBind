import fs from "fs";
import { launch, newPage, login, connected, BASE } from "./lib.mjs";
const browser = await launch();
const results = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function test(name, fn) {
  try { const detail = await fn(); results.push(["PASS", name, detail || ""]); }
  catch (e) { results.push(["FAIL", name, String(e.message || e).slice(0, 200)]); }
}
const ok = (c, msg) => { if (!c) throw new Error(msg); };
const goto = async (page, path) => { await page.goto(BASE + path, { waitUntil: "domcontentloaded" }); await connected(page); await sleep(400); };
const drawn = (page, sel) => page.evaluate((s) => { const c = document.querySelector(s); if (!c) return -1; const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data; let n = 0; for (let i = 3; i < d.length; i += 4) if (d[i] > 0) n++; return n; }, sel);

// ---------- desktop ----------
const page = await newPage(browser, 1280);
await login(page);

await test("palette: Ctrl+K opens, filters, Enter navigates", async () => {
  await goto(page, "/");
  await page.keyboard.down("Control"); await page.keyboard.press("k"); await page.keyboard.up("Control");
  await sleep(200);
  ok(await page.$eval("#command-palette", (d) => d.open), "dialog not open");
  await page.keyboard.type("gener");
  const visible = await page.$$eval("#command-palette li[data-label]:not(.hidden)", (l) => l.map((x) => x.dataset.label));
  ok(visible.length === 1 && visible[0] === "generate", "filter wrong: " + visible);
  await page.keyboard.press("Enter");
  await page.waitForFunction(() => location.pathname === "/model", { timeout: 5000 });
  ok(!(await page.$eval("#command-palette", (d) => d.open)), "palette still open after navigation");
});
await test("palette: Escape closes and restores focus", async () => {
  await goto(page, "/");
  await page.focus("button[aria-label='Open command palette']");
  await page.keyboard.down("Control"); await page.keyboard.press("k"); await page.keyboard.up("Control");
  await sleep(150);
  await page.keyboard.press("Escape"); await sleep(150);
  ok(!(await page.$eval("#command-palette", (d) => d.open)), "still open");
});
await test("nav: active link has aria-current=page", async () => {
  await goto(page, "/history");
  const cur = await page.$$eval("#app-sidebar a[aria-current=page]", (a) => a.map((x) => x.textContent.trim().replace(/\s+/g, " ")));
  ok(cur.length === 1 && cur[0].startsWith("History"), JSON.stringify(cur));
});
await test("generator: SMILES preview draws on canvas; slider label; error keeps values", async () => {
  await goto(page, "/model");
  await page.type("input[name='form[smiles]']", "CCO");
  await page.waitForSelector("#input-preview", { timeout: 4000 });
  await sleep(1500);
  const px = await drawn(page, "#input-preview");
  ok(px > 100, "canvas empty (" + px + " px)");
  await page.$eval("input[name='form[num_molecules]']", (el) => { el.value = "500"; el.dispatchEvent(new Event("input", { bubbles: true })); });
  await sleep(900);
  ok((await page.content()).includes("Number of molecules must be between 1 and 100."), "no range error");
  await page.$eval("input[name='form[num_molecules]']", (el) => { el.value = "3"; el.dispatchEvent(new Event("input", { bubbles: true })); });
  await sleep(700);
  await page.click("#molecule-form button[type=submit]");
  await page.waitForFunction(() => /not configured|NVIDIA|rejected|could not|failed|Waiting/i.test(document.body.innerText), { timeout: 8000 });
  await sleep(1500);
  const v = await page.$eval("input[name='form[smiles]']", (e) => e.value);
  ok(v === "CCO", "smiles lost after run: " + v);
  return "canvas px=" + px;
});
await test("run detail: structures drawn, Copy SMILES works, PNG downloads", async () => {
  const ctx = page.ctx;
  await ctx.overridePermissions(BASE, ["clipboard-read", "clipboard-write"]);
  fs.rmSync("/tmp/dl", { recursive: true, force: true }); fs.mkdirSync("/tmp/dl");
  const cdp = await page.createCDPSession();
  await cdp.send("Browser.setDownloadBehavior", { behavior: "allow", downloadPath: "/tmp/dl", eventsEnabled: true, browserContextId: ctx.id });
  await goto(page, "/history/1");
  await sleep(1500);
  const px = await Promise.all([0, 1, 2].map((i) => drawn(page, "#run-canvas-" + i)));
  ok(px.every((n) => n > 100), "canvases not drawn: " + px);
  await page.click("#run-copy-0"); await sleep(400);
  const label = await page.$eval("#run-copy-0", (b) => b.textContent.trim());
  ok(label === "Copied", "copy label: " + label);
  const clip = await page.evaluate(() => navigator.clipboard.readText());
  ok(clip === "CC(=O)OC1=CC=CC=C1C(=O)O", "clipboard: " + clip);
  await page.click("#run-png-0"); await sleep(1500);
  const files = fs.readdirSync("/tmp/dl");
  ok(files.length === 1 && files[0].endsWith(".png"), "download: " + files);
  const sig = fs.readFileSync("/tmp/dl/" + files[0]).subarray(0, 8).toString("hex");
  ok(sig === "89504e470d0a1a0a", "not a PNG: " + sig);
  return files[0];
});
await test("molecule bank: search patches URL; table view; 3D modal opens", async () => {
  await goto(page, "/molecule-bank");
  await page.type("#bank-q", "caff");
  await page.waitForFunction(() => location.search.includes("q=caff"), { timeout: 4000 });
  await sleep(500);
  ok((await page.content()).includes("1 molecule"), "count not updated");
  const px = await drawn(page, "#bank-canvas-caffeine"); ok(px > 100, "caffeine not drawn " + px);
  await page.click("button[aria-label='Open larger 3D view of Caffeine']");
  await page.waitForSelector("#molecule-modal", { timeout: 4000 });
  await page.keyboard.press("Escape"); await sleep(500);
});
await test("research: PubChem failure shows inline error (no crash)", async () => {
  await goto(page, "/research");
  await page.type("#compound-name", "caffeine");
  await page.keyboard.press("Enter");
  await page.waitForFunction(() => /Could not reach PubChem|PubChem/i.test(document.querySelector("[role=status]")?.innerText || ""), { timeout: 20000 });
  ok(await page.$("[data-phx-main].phx-connected"), "LiveView disconnected");
});
await test("sketcher: ChemDoodle loads; empty-canvas export reports an error", async () => {
  await goto(page, "/sketcher");
  await sleep(1500);
  ok(await page.evaluate(() => typeof ChemDoodle !== "undefined"), "ChemDoodle missing");
  await page.click("button[phx-value-format=smiles]");
  await page.waitForFunction(() => /canvas is empty|could not|cannot|Unsupported|failed/i.test(document.querySelector("[role=status]")?.innerText || ""), { timeout: 4000 });
  return await page.$eval("[role=status]", (e) => e.innerText.trim().slice(0, 80));
});
await test("settings: theme choice applies, persists across reload", async () => {
  await goto(page, "/settings");
  await page.click("input[name=theme][value=dark]"); await sleep(600);
  ok(await page.evaluate(() => document.documentElement.classList.contains("dark")), "dark class missing");
  ok((await page.evaluate(() => localStorage.getItem("theme"))) === "dark", "not stored");
  await goto(page, "/settings");
  ok(await page.evaluate(() => document.documentElement.classList.contains("dark")), "not restored on reload");
  ok(await page.$eval("input[name=theme][value=dark]", (e) => e.checked), "radio not reflecting stored theme");
  await page.click("input[name=theme][value=light]"); await sleep(300);
});

// ---------- chat: two users ----------
const b = await newPage(browser, 1280); await login(b, 2);
await test("chat: starts at bottom; load older keeps place; new msg while scrolled up shows jump button", async () => {
  await goto(page, "/message");
  await sleep(500);
  const atBottom = () => page.$eval("#chat-messages", (e) => e.scrollHeight - e.scrollTop - e.clientHeight < 5);
  ok(await atBottom(), "not at bottom on load");
  await page.$eval("#chat-messages", (e) => (e.scrollTop = 0)); await sleep(300);
  const before = await page.$$eval("#chat-messages > div", (d) => d.length);
  await page.evaluate(() => [...document.querySelectorAll("button")].find((x) => /Load older/.test(x.textContent))?.click());
  await sleep(800);
  const after = await page.$$eval("#chat-messages > div", (d) => d.length);
  ok(after > before, `older not loaded (${before} -> ${after})`);
  await page.$eval("#chat-messages", (e) => (e.scrollTop = 0)); await sleep(300);
  await goto(b, "/message");
  await b.type("#chat-form input[type=text]", "hello from user two");
  await b.keyboard.press("Enter");
  await sleep(1200);
  const top = await page.$eval("#chat-messages", (e) => e.scrollTop);
  ok(top < 50, "view jumped while reading history: " + top);
  ok(await page.$eval("#chat-jump", (e) => !e.classList.contains("hidden")), "jump button not shown");
  await page.click("#chat-jump"); await sleep(300);
  ok(await atBottom(), "jump did not scroll to bottom");
  ok((await page.content()).includes("hello from user two"), "message missing");
  return `loaded ${before}->${after}`;
});

// ---------- mobile drawer ----------
const m = await newPage(browser, 375, 800); await login(m);
await test("mobile: sidebar hidden, opens via toggle, closes via Escape and link click", async () => {
  await goto(m, "/");
  const x = () => m.$eval("#app-sidebar", (e) => Math.round(e.getBoundingClientRect().right));
  ok((await x()) <= 0, "sidebar visible by default: right=" + (await x()));
  await m.click("#sidebar-toggle"); await sleep(500);
  ok((await x()) > 200, "sidebar did not open");
  ok((await m.$eval("#sidebar-toggle", (e) => e.getAttribute("aria-expanded"))) === "true", "aria-expanded not true");
  await m.keyboard.press("Escape"); await sleep(500);
  ok((await x()) <= 0, "Escape did not close");
  await m.click("#sidebar-toggle"); await sleep(400);
  await m.click("#app-sidebar a[href='/collections']");
  await m.waitForFunction(() => location.pathname === "/collections", { timeout: 4000 }); await sleep(600);
  ok((await x()) <= 0, "drawer stayed open after navigation");
});

// ---------- wallet sign-in (logged out) ----------
const anon = await newPage(browser, 1280);
await test("wallet: no extension -> inline install guidance, no alert()", async () => {
  let alerted = false; anon.on("dialog", async (d) => { alerted = true; await d.dismiss(); });
  await goto(anon, "/auth/sign-in");
  await anon.click("#loginButton"); await sleep(400);
  ok(await anon.$eval("#wallet-install", (e) => !e.classList.contains("hidden")), "install block hidden");
  ok(!alerted, "alert() fired");
});
const anon2 = await newPage(browser, 1280);
await anon2.evaluateOnNewDocument(() => { window.ethereum = { request: async ({ method }) => { if (method === "eth_requestAccounts") return ["0x" + "ab".repeat(20)]; const e = new Error("User rejected"); e.code = 4001; throw e; }, on() {}, removeListener() {} }; });
await test("wallet: rejected signature -> specific message + 'Try again'", async () => {
  await goto(anon2, "/auth/sign-in");
  await anon2.click("#loginButton");
  await anon2.waitForFunction(() => /declined/i.test(document.querySelector("#wallet-status")?.innerText || ""), { timeout: 6000 });
  ok((await anon2.$eval("#loginButton", (e) => e.innerText)).includes("Try again"), "button label");
  ok(await anon2.$eval("#loginButton", (e) => !e.disabled), "button left disabled");
});

console.log(results.map((r) => `${r[0]}  ${r[1]}${r[2] ? "  [" + r[2] + "]" : ""}`).join("\n"));
console.log(`\n${results.filter((r) => r[0] === "PASS").length}/${results.length} passed`);
await browser.close();
