import { launch, newPage, login, connected, BASE } from "./lib.mjs";
const browser = await launch();
const results = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function test(name, fn) {
  try { const d = await fn(); results.push(["PASS", name, d || ""]); }
  catch (e) { results.push(["FAIL", name, String(e.message || e).slice(0, 220)]); }
}
const ok = (c, m) => { if (!c) throw new Error(m); };
const goto = async (page, path) => { await page.goto(BASE + path, { waitUntil: "domcontentloaded" }); await connected(page); await sleep(500); };
const drawn = (page, sel) => page.evaluate((s) => { const c = document.querySelector(s); if (!c) return -1; const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data; let n = 0; for (let i = 3; i < d.length; i += 4) if (d[i] > 0) n++; return n; }, sel);
const dataUrl = (page, sel) => page.evaluate((s) => document.querySelector(s).toDataURL(), sel);

const owner = await newPage(browser, 1280); await login(owner, 1);
const visitor = await newPage(browser, 1280); // anonymous: its own empty cookie jar
const second = await newPage(browser, 1280); await login(second, 2);

// ======================= 1. SHARE LINKS =======================
let shareUrl;
await test("share: owner creates a link; URL is shown once", async () => {
  await goto(owner, "/history/1");
  ok((await owner.content()).includes("Private: no active links"), "not private initially");
  await owner.select("#share-panel-expiry", "7");
  await owner.click("#share-panel form button[type=submit]");
  await owner.waitForSelector("#share-panel-url", { timeout: 5000 });
  shareUrl = await owner.$eval("#share-panel-url", (e) => e.value);
  ok(/\/s\/[A-Za-z0-9_-]{40,}$/.test(shareUrl), "url shape: " + shareUrl);
  ok((await owner.content()).includes("Shared: 1 active link"), "indicator not updated");
  await goto(owner, "/history/1");
  ok(!(await owner.content()).includes(shareUrl.split("/s/")[1]), "token recoverable after reload!");
  return shareUrl.replace(/\/s\/.*/, "/s/…");
});
await test("share: anonymous visitor sees a read-only page with drawn structures and no shell", async () => {
  const res = await visitor.goto(shareUrl, { waitUntil: "domcontentloaded" });
  await connected(visitor); await sleep(1800);
  const h = res.headers();
  ok(res.status() === 200, "status " + res.status());
  ok(h["referrer-policy"] === "no-referrer", "referrer-policy: " + h["referrer-policy"]);
  ok(h["x-robots-tag"] === "noindex, nofollow", "x-robots-tag: " + h["x-robots-tag"]);
  ok(h["cache-control"] === "no-store", "cache-control: " + h["cache-control"]);
  ok(!(await visitor.$("#app-sidebar")), "app shell leaked to a public page");
  const body = await visitor.evaluate(() => document.body.innerText);
  ok(/shared from molbind/i.test(body) && /read-only/i.test(body), "banner missing: " + body.slice(0, 80));
  ok(!/0xabab|ada|Shortlist/i.test(body), "owner identity / private data visible");
  const px = await drawn(visitor, "#shared-cand-0");
  ok(px > 100, "candidate not drawn: " + px);
  return `${px} px drawn`;
});
await test("share: a link grants nothing beyond itself (private pages still require sign-in)", async () => {
  for (const path of ["/history/1", "/collections/1", "/message", "/settings"]) {
    await visitor.goto(BASE + path, { waitUntil: "domcontentloaded" });
    ok(new URL(visitor.url()).pathname === "/auth/sign-in", path + " reachable: " + visitor.url());
  }
  const res = await visitor.goto(BASE + "/account/export.json", { waitUntil: "domcontentloaded" });
  ok(!/"format"\s*:\s*"molbind-export"/.test(await visitor.evaluate(() => document.body.innerText)), "data export reachable");
});
await test("share: viewer controls work on the public page (copy)", async () => {
  await visitor.goto(shareUrl, { waitUntil: "domcontentloaded" }); await connected(visitor); await sleep(1200);
  await visitor.ctx.overridePermissions(BASE, ["clipboard-read", "clipboard-write"]);
  await visitor.click("#shared-cand-0-viewer [data-action=copy]"); await sleep(500);
  const clip = await visitor.evaluate(() => navigator.clipboard.readText());
  ok(/^C/.test(clip) && clip.length > 5, "clipboard: " + clip);
});
await test("share: revoking kills the link immediately (404, same for unknown tokens)", async () => {
  await goto(owner, "/history/1");
  await owner.click("#share-panel button[phx-click=revoke]"); await sleep(700);
  ok((await owner.content()).includes("Private: no active links"), "indicator not private");
  const res = await visitor.goto(shareUrl, { waitUntil: "domcontentloaded" });
  ok(res.status() === 404, "revoked link status " + res.status());
  const body = await visitor.evaluate(() => document.body.innerText);
  ok(/couldn't find that page/i.test(body), "no useful 404 page: " + body.slice(0, 80));
  const res2 = await visitor.goto(BASE + "/s/" + "x".repeat(43), { waitUntil: "domcontentloaded" });
  ok(res2.status() === 404, "unknown token status " + res2.status());
  ok(!/stack|\*\*|\.ex:/i.test(await visitor.evaluate(() => document.body.innerText)), "internals leaked");
});

// ======================= 2. CHAT =======================
await test("chat: reply is delivered live with a quote to the other user", async () => {
  await goto(owner, "/message"); await goto(second, "/message");
  const target = await second.evaluate(() => { const m = [...document.querySelectorAll("#chat-messages > div")].reverse().find((d) => /message number/.test(d.innerText)); return m.id; });
  await second.evaluate((id) => document.querySelector(`#${id} button[phx-click=reply]`).click(), target);
  await second.waitForSelector("#reply-bar", { timeout: 4000 });
  await second.type("#chat-form input[type=text]", "replying from user two");
  await second.keyboard.press("Enter");
  await owner.waitForFunction(() => /replying from user two/.test(document.body.innerText), { timeout: 6000 });
  const quote = await owner.evaluate(() => [...document.querySelectorAll("#chat-messages blockquote")].map((b) => b.innerText).pop());
  ok(/Replying to/.test(quote), "quote missing: " + quote);
  ok(!(await second.$("#reply-bar")), "reply bar not cleared");
  return quote.replace(/\s+/g, " ").slice(0, 60);
});
await test("chat: reaction syncs live, shows count and aria-pressed, toggles off", async () => {
  const sel = '#chat-messages > div:last-child button[phx-value-emoji="👍"]';
  await second.waitForSelector(sel); await second.click(sel);
  await owner.waitForFunction((s) => /1 reaction/.test(document.querySelector(s)?.getAttribute("aria-label") || ""), { timeout: 6000 }, sel);
  ok((await second.$eval(sel, (e) => e.getAttribute("aria-pressed"))) === "true", "pressed state on reactor");
  ok((await owner.$eval(sel, (e) => e.getAttribute("aria-pressed"))) === "false", "owner should not be pressed");
  await second.click(sel);
  await owner.waitForFunction((s) => /React with/.test(document.querySelector(s)?.getAttribute("aria-label") || ""), { timeout: 6000 }, sel);
});
await test("chat: sharing a candidate posts a molecule card that draws for everyone", async () => {
  await goto(owner, "/history/1");
  await owner.evaluate(() => [...document.querySelectorAll("button")].find((b) => /Share to chat/.test(b.textContent)).click());
  await owner.waitForFunction(() => /Shared to the chat lobby/.test(document.body.innerText), { timeout: 5000 });
  await goto(second, "/message");
  await sleep(1500);
  const card = await second.$eval("#chat-messages > div:last-child [id^=msg-card]", (e) => e.id);
  const px = await drawn(second, `#${card.replace("card", "canvas")}`);
  ok(px > 100, "card canvas not drawn: " + px);
  ok((await second.evaluate(() => document.querySelector("#chat-messages > div:last-child a[href^='/model?smiles=']") !== null)), "open-in-generator link missing");
  return `${px} px`;
});

// ======================= 3. VIEWER CONTROLS =======================
await test("viewer: structure is drawn; toolbar is a labelled toolbar", async () => {
  await goto(owner, "/history/1"); await sleep(1500);
  const info = await owner.evaluate(() => { const t = document.querySelector("#run-viewer-0 [role=toolbar]"); return { label: t.getAttribute("aria-label"), buttons: [...t.querySelectorAll("button")].map((b) => b.getAttribute("aria-label")) }; });
  ok(info.buttons.length >= 6 && info.buttons.every(Boolean), "unlabelled buttons: " + JSON.stringify(info.buttons));
  ok((await drawn(owner, "#run-canvas-0")) > 100, "not drawn");
});
const zoom = () => owner.$eval("#run-viewer-0 [data-stage]", (e) => Number(e.dataset.zoom));
await test("viewer: zoom in/out/fit buttons", async () => {
  ok((await zoom()) === 100, "start zoom " + (await zoom()));
  await owner.click("#run-viewer-0 [data-action=zoom-in]"); ok((await zoom()) === 125, "in: " + (await zoom()));
  await owner.click("#run-viewer-0 [data-action=zoom-in]"); ok((await zoom()) === 156, "in2: " + (await zoom()));
  await owner.click("#run-viewer-0 [data-action=zoom-out]"); ok((await zoom()) === 125, "out: " + (await zoom()));
  await owner.click("#run-viewer-0 [data-action=fit]"); ok((await zoom()) === 100, "fit: " + (await zoom()));
  for (let i = 0; i < 12; i++) await owner.click("#run-viewer-0 [data-action=zoom-in]");
  ok((await zoom()) === 400, "max clamp: " + (await zoom()));
  for (let i = 0; i < 20; i++) await owner.click("#run-viewer-0 [data-action=zoom-out]");
  ok((await zoom()) === 50, "min clamp: " + (await zoom()));
  await owner.click("#run-viewer-0 [data-action=fit]");
});
await test("viewer: keyboard (+, -, 0, arrows) and Ctrl+wheel", async () => {
  await owner.focus("#run-viewer-0 [data-viewport]");
  await owner.keyboard.press("+"); await owner.keyboard.press("+");
  ok((await zoom()) === 156, "keys +: " + (await zoom()));
  const t0 = await owner.$eval("#run-viewer-0 canvas", (c) => c.style.transform);
  await owner.keyboard.press("ArrowLeft");
  const t1 = await owner.$eval("#run-viewer-0 canvas", (c) => c.style.transform);
  ok(t0 !== t1, "arrow did not pan: " + t0 + " -> " + t1);
  await owner.keyboard.press("0"); ok((await zoom()) === 100, "key 0: " + (await zoom()));
  const box = await owner.$eval("#run-viewer-0 [data-viewport]", (e) => { const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; });
  await owner.mouse.move(box.x, box.y);
  await owner.keyboard.down("Control"); await owner.mouse.wheel({ deltaY: -100 }); await owner.keyboard.up("Control"); await sleep(200);
  ok((await zoom()) === 125, "ctrl+wheel: " + (await zoom()));
  await owner.keyboard.press("0");
});
await test("viewer: drag pans when zoomed, not at 100%", async () => {
  const c = await owner.$eval("#run-viewer-0 [data-viewport]", (e) => { const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; });
  const tr = () => owner.$eval("#run-viewer-0 canvas", (e) => e.style.transform);
  const before = await tr();
  await owner.mouse.move(c.x, c.y); await owner.mouse.down(); await owner.mouse.move(c.x + 40, c.y + 20, { steps: 4 }); await owner.mouse.up();
  ok((await tr()) === before, "panned at 100%");
  await owner.click("#run-viewer-0 [data-action=zoom-in]"); await owner.click("#run-viewer-0 [data-action=zoom-in]");
  const z = await tr();
  await owner.mouse.move(c.x, c.y); await owner.mouse.down(); await owner.mouse.move(c.x + 40, c.y + 20, { steps: 4 }); await owner.mouse.up();
  ok((await tr()) !== z && /translate\(40px, 20px\)/.test(await tr()), "drag did not pan: " + (await tr()));
  await owner.click("#run-viewer-0 [data-action=fit]");
});
await test("viewer: label-all-carbons redraws; dark background changes viewport; both announce state", async () => {
  const before = await dataUrl(owner, "#run-canvas-0");
  await owner.click("#run-viewer-0 [data-action=labels]"); await sleep(600);
  const after = await dataUrl(owner, "#run-canvas-0");
  ok(before !== after, "drawing did not change when labelling all carbons");
  ok((await owner.$eval("#run-viewer-0 [data-action=labels]", (e) => e.getAttribute("aria-pressed"))) === "true", "aria-pressed");
  await owner.click("#run-viewer-0 [data-action=labels]"); await sleep(500);
  ok((await dataUrl(owner, "#run-canvas-0")) === before, "toggling back did not restore the drawing");
  await owner.click("#run-viewer-0 [data-action=background]"); await sleep(500);
  const bg = await owner.$eval("#run-viewer-0 [data-stage]", (e) => getComputedStyle(e).backgroundColor);
  ok(bg === "rgb(31, 41, 55)", "dark bg: " + bg);
  ok((await owner.$eval("#run-viewer-0 [data-status]", (e) => e.textContent)).includes("Dark"), "no status announcement");
  await owner.click("#run-viewer-0 [data-action=background]"); await sleep(300);
});
await test("viewer: 3D control explains why there is no 3D view (no fake coordinates)", async () => {
  ok(await owner.$eval("#run-viewer-0-note", (e) => e.classList.contains("hidden")), "note visible by default");
  await owner.click("#run-viewer-0 [data-action=\"3d\"]");
  const t = await owner.$eval("#run-viewer-0-note", (e) => ({ hidden: e.classList.contains("hidden"), text: e.innerText }));
  ok(!t.hidden && /does not compute them/.test(t.text), "3D note: " + JSON.stringify(t));
  await owner.click("#run-viewer-0 [data-action=\"3d\"]");
});
await test("viewer: fullscreen toggles (or reports unavailability), state survives a server re-render", async () => {
  await owner.click("#run-viewer-0 [data-action=zoom-in]");
  await owner.evaluate(() => [...document.querySelectorAll("button")].find((b) => /Delete run/.test(b.textContent)).click()); // forces a parent patch
  await sleep(800);
  ok((await zoom()) === 125, "zoom reset by server re-render: " + (await zoom()));
  ok((await drawn(owner, "#run-canvas-0")) > 100, "canvas wiped by re-render");
  await owner.click("#run-viewer-0 [data-action=fit]");
  await owner.click("#run-viewer-0 [data-action=fullscreen]"); await sleep(600);
  const fs = await owner.evaluate(() => document.fullscreenElement && document.fullscreenElement.id);
  const status = await owner.$eval("#run-viewer-0 [data-status]", (e) => e.textContent);
  ok(fs === "run-viewer-0" || /not available|blocked/.test(status), "neither fullscreen nor an explanation: " + fs + " / " + status);
  if (fs) { await owner.click("#run-viewer-0 [data-action=fullscreen]"); await sleep(400); ok(!(await owner.evaluate(() => document.fullscreenElement)), "did not exit"); }
  return fs ? "real fullscreen" : "unavailable here: " + status;
});

console.log(results.map((r) => `${r[0]}  ${r[1]}${r[2] ? "  [" + r[2] + "]" : ""}`).join("\n"));
console.log(`\n${results.filter((r) => r[0] === "PASS").length}/${results.length} passed`);
await browser.close();
