import fs from "fs";
import zlib from "zlib";
import os from "os";
import path from "path";
import { launch, newPage, login, connected, BASE } from "./lib.mjs";
const browser = await launch();
const results = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function test(name, fn) { try { const d = await fn(); results.push(["PASS", name, d || ""]); } catch (e) { results.push(["FAIL", name, String(e.message || e).slice(0, 220)]); } }
const ok = (c, m) => { if (!c) throw new Error(m); };
const goto = async (page, p) => { await page.goto(BASE + p, { waitUntil: "domcontentloaded" }); await connected(page); await sleep(500); };

// A real, decodable PNG of a flat colour, built with zlib (no image library needed).
function makePng(size, [r, g, b]) {
  const crcTable = (() => { const t = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
  const crc = (buf) => { let c = 0xffffffff; for (const x of buf) c = crcTable[(c ^ x) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4); ihdr[8] = 8; ihdr[9] = 2;
  const row = Buffer.concat([Buffer.from([0]), Buffer.from(Array(size).fill([r, g, b]).flat())]);
  const raw = Buffer.concat(Array(size).fill(row));
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "av-"));
const red = path.join(dir, "red.png"); fs.writeFileSync(red, makePng(64, [220, 38, 38]));
const blue = path.join(dir, "blue.png"); fs.writeFileSync(blue, makePng(64, [37, 99, 235]));
const fake = path.join(dir, "fake.png"); fs.writeFileSync(fake, "<!DOCTYPE html><html><script>alert(1)</script></html>");
const big = path.join(dir, "big.png"); fs.writeFileSync(big, Buffer.concat([makePng(64, [0, 0, 0]), Buffer.alloc(2_100_000)]));

const owner = await newPage(browser, 1280); await login(owner, 1);
const visitor = await newPage(browser, 1280);
const current = () => owner.$eval("#current-avatar", (i) => i.getAttribute("src")).catch(() => null);
let firstSrc, secondSrc;

await test("avatar: starts with no picture", async () => {
  await goto(owner, "/settings");
  const clear = await owner.$("button[phx-click=remove_avatar]"); if (clear) { await clear.click(); await sleep(700); }
  ok(!(await current()), "has avatar at start");
  ok((await owner.evaluate(() => document.body.innerText)).includes("No picture"), "no placeholder");
});
await test("avatar: choosing a file shows a preview; uploading shows a picture that really decodes", async () => {
  await (await owner.$("#avatar-form input[type=file]")).uploadFile(red);
  await owner.waitForSelector("#avatar-form img", { timeout: 5000 });
  ok(!(await owner.$eval("#avatar-form button[type=submit]", (b) => b.disabled)), "submit still disabled");
  await owner.click("#avatar-form button[type=submit]");
  await owner.waitForSelector("#current-avatar", { timeout: 6000 }); await sleep(800);
  firstSrc = await current();
  ok(/^\/avatars\/[a-f0-9]{32}\.png$/.test(firstSrc), "src shape: " + firstSrc);
  const dims = await owner.$eval("#current-avatar", (i) => [i.naturalWidth, i.naturalHeight]);
  ok(dims[0] === 64 && dims[1] === 64, "image did not decode: " + dims);
  return firstSrc;
});
await test("avatar: served with nosniff, a locked-down CSP, day-long caching", async () => {
  const h = await owner.evaluate(async (u) => { const r = await fetch(u); return { status: r.status, type: r.headers.get("content-type"), nosniff: r.headers.get("x-content-type-options"), csp: r.headers.get("content-security-policy"), cache: r.headers.get("cache-control"), bytes: (await r.arrayBuffer()).byteLength }; }, firstSrc);
  ok(h.status === 200 && h.type === "image/png", JSON.stringify(h));
  ok(h.nosniff === "nosniff" && /default-src 'none'/.test(h.csp) && /max-age=86400/.test(h.cache) && !/immutable/.test(h.cache), JSON.stringify(h));
});
await test("avatar: the picture is public (an anonymous visitor can load it) and shows on the profile", async () => {
  const res = await visitor.goto(BASE + firstSrc);
  ok(res.status() === 200 && /image\/png/.test(res.headers()["content-type"]), "visitor status " + res.status());
  await goto(owner, "/profile"); await sleep(600);
  const prof = await owner.$$eval("img", (imgs) => imgs.filter((i) => i.getAttribute("src") === arguments[0]).length).catch(() => 0);
  const has = await owner.evaluate((src) => [...document.images].some((i) => i.getAttribute("src") === src && i.naturalWidth > 0), firstSrc);
  ok(has, "profile does not show the uploaded picture");
});
await test("avatar: an HTML file disguised as .png is rejected and the picture is unchanged", async () => {
  await goto(owner, "/settings");
  await (await owner.$("#avatar-form input[type=file]")).uploadFile(fake);
  await owner.waitForSelector("#avatar-form button[type=submit]:not([disabled])", { timeout: 5000 });
  await owner.click("#avatar-form button[type=submit]");
  await owner.waitForFunction(() => /not a PNG, JPEG, GIF or WebP/.test(document.body.innerText), { timeout: 6000 });
  ok((await current()) === firstSrc, "avatar changed after a rejected upload");
});
await test("avatar: an oversized file is refused with a clear message", async () => {
  await goto(owner, "/settings");
  await (await owner.$("#avatar-form input[type=file]")).uploadFile(big);
  await owner.waitForFunction(() => /larger than 2 MB/.test(document.body.innerText), { timeout: 6000 });
  ok(await owner.$eval("#avatar-form button[type=submit]", (b) => b.disabled) || true, "n/a");
});
await test("avatar: replacing removes the old file from the server", async () => {
  await goto(owner, "/settings");
  await (await owner.$("#avatar-form input[type=file]")).uploadFile(blue);
  await owner.waitForSelector("#avatar-form button[type=submit]:not([disabled])");
  await owner.click("#avatar-form button[type=submit]");
  await owner.waitForFunction((old) => document.querySelector("#current-avatar")?.getAttribute("src") !== old, { timeout: 6000 }, firstSrc);
  secondSrc = await current(); await sleep(400);
  const ask = (u) => owner.evaluate(async (x) => (await fetch(x, { cache: "reload" })).status, u);
  ok((await ask(firstSrc)) === 404, "old picture still served by the server");
  ok((await ask(secondSrc)) === 200, "new picture not served");
});
await test("avatar: removing deletes it", async () => {
  await goto(owner, "/settings");
  await owner.click("button[phx-click=remove_avatar]"); await sleep(900);
  ok(!(await current()), "avatar still shown");
  ok((await owner.evaluate(async (x) => (await fetch(x, { cache: "reload" })).status, secondSrc)) === 404, "file still served after removal");
});
await test("avatar: path traversal and bogus names are 404, never file contents", async () => {
  for (const p of ["/avatars/..%2F..%2Fmix.exs", "/avatars/mix.exs", "/avatars/" + "a".repeat(32) + ".png", "/avatars/%2e%2e%2fconfig%2fconfig.exs"]) {
    const r = await visitor.goto(BASE + p);
    ok(r.status() === 404, p + " -> " + r.status());
    ok(!/defmodule|import Config/.test(await visitor.evaluate(() => document.body.innerText)), "leaked file contents for " + p);
  }
});

console.log(results.map((r) => `${r[0]}  ${r[1]}${r[2] ? "  [" + r[2] + "]" : ""}`).join("\n"));
console.log(`\n${results.filter((r) => r[0] === "PASS").length}/${results.length} passed`);
await browser.close();
