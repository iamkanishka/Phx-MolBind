import chromium from "@sparticuz/chromium";
import puppeteer from "puppeteer-core";
import fs from "fs";

export const BASE = process.env.MOLBIND_URL || "http://localhost:4000";
// Optional: serve smiles-drawer from a local file instead of unpkg (offline runs).
const SMILES_JS = process.env.SMILES_DRAWER_JS || null;

export async function launch() {
  return puppeteer.launch({
    executablePath: await chromium.executablePath(),
    args: [...chromium.args.filter((a) => !["--single-process", "--no-zygote"].includes(a)), "--no-sandbox"],
    headless: "shell",
  });
}

// New page that serves smiles-drawer locally (unpkg is not reachable from the
// sandbox) and aborts every other external request, recording problems.
export async function newPage(browser, width = 1280, height = 900) {
  // Every page gets its own incognito context so cookies/sessions never leak between "users".
  const ctx = await browser.createBrowserContext();
  const page = await ctx.newPage();
  page.ctx = ctx;
  await page.setViewport({ width, height });
  const log = { console: [], pageErrors: [], failed: [], external: [] };
  await page.setRequestInterception(true);
  page.on("request", (req) => {
    const url = req.url();
    if (url.startsWith(BASE) || url.startsWith("data:") || url.startsWith("blob:")) return req.continue();
    if (url.includes("smiles-drawer") && SMILES_JS) {
      return req.respond({ status: 200, contentType: "application/javascript", body: fs.readFileSync(SMILES_JS) });
    }
    log.external.push(url);
    // Offline runs abort external hosts (fonts, CDNs); otherwise let them through.
    return process.env.MOLBIND_OFFLINE ? req.abort() : req.continue();
  });
  page.on("console", (m) => { if (["error", "warning"].includes(m.type()) && !m.text().includes("net::ERR_FAILED")) log.console.push(`${m.type()}: ${m.text()}`.slice(0, 200)); });
  page.on("pageerror", (e) => log.pageErrors.push(String(e).slice(0, 200)));
  page.on("requestfailed", (r) => { if (r.url().startsWith(BASE)) log.failed.push(`${r.url()} ${r.failure()?.errorText}`); });
  page.log = log;
  return page;
}

// Sign in by reusing a real session cookie copied from a logged-in browser
// (cookie name `_phx_molbind_key`; see README). Wallet signing cannot be
// automated, and this repo deliberately ships no login backdoor route.
// MOLBIND_COOKIE_2 is a second user's cookie, used by the chat test.
export async function login(page, id = 1) {
  const value = id === 2 ? process.env.MOLBIND_COOKIE_2 : process.env.MOLBIND_COOKIE;
  if (!value) throw new Error(`Set ${id === 2 ? "MOLBIND_COOKIE_2" : "MOLBIND_COOKIE"} (see test/browser/README.md)`);
  await page.setCookie({ name: "_phx_molbind_key", value, url: BASE, httpOnly: true });
}

export async function connected(page, timeout = 8000) {
  await page.waitForSelector("[data-phx-main].phx-connected", { timeout });
}
