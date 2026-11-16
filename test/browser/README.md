# Browser checks (optional, not part of `mix test`)

Real-browser checks that complement the ExUnit suite. They were used to
verify the UI refactor against a headless Chromium. They need Node 18+ and:

    npm i --no-save puppeteer-core @sparticuz/chromium axe-core
    # or point puppeteer-core at any installed Chrome/Chromium (edit lib.mjs)

## What they do

| Script          | Checks |
|-----------------|--------|
| `pages.mjs`     | Loads 13 pages at 320/375/768/1280 px: LiveView connects, no console errors, no failed requests, no horizontal overflow, time-to-connected. |
| `interact.mjs`  | Command palette, mobile drawer, canvas rendering, Copy SMILES, PNG download, theme persistence, chat scroll behaviour with two users, sketcher export, wallet sign-in states (stubbed `window.ethereum`). |
| `interact2.mjs` | Share links end to end (create, public read-only view as an anonymous visitor, privacy headers, revoke, 404), chat replies/reactions/molecule cards with two users live, and the structure viewer (zoom, pan, fit, labels, background, 3D note, fullscreen, state surviving server re-renders). |
| `interact3.mjs` | Lineage end to end: parent/child/grandchild links and root-first ancestor chain, saved molecules in the tree, the generator's lineage note (shown for a verified candidate, dropped when the SMILES is edited, never shown for forged provenance), and no overflow at 320 px. Needs the lineage records from `seed.exs`. |
| `interact4.mjs` | Avatar upload with real files: preview, decode check, serving headers, public access, disguised-HTML and oversize rejection, replace/remove deleting the old file, path-traversal 404s. |
| `axe.mjs`       | axe-core (WCAG 2.0/2.1/2.2 A/AA + best practice) on every page, plus the public share page as an anonymous visitor, in light and dark themes, including colour contrast. |

## Running

1. Build assets and start the app: `mix assets.deploy && mix phx.server`
2. Seed data the scripts expect (user ada = id 1, a second user = id 2, runs,
   a collection, chat messages): `mix run test/browser/seed.exs`
3. Wallet signing cannot be automated, so the scripts reuse real sessions.
   Sign in as each seeded user in a browser and copy the `_phx_molbind_key`
   cookie value (DevTools > Application > Cookies):

       export MOLBIND_URL=http://localhost:4000
       export MOLBIND_COOKIE='...user 1...'
       export MOLBIND_COOKIE_2='...user 2...'
       node test/browser/pages.mjs
       node test/browser/interact.mjs
       node test/browser/interact2.mjs
       node test/browser/interact3.mjs
       node test/browser/interact4.mjs
       node test/browser/axe.mjs

Set `MOLBIND_OFFLINE=1` to abort all non-local requests (fonts, CDNs), and
`SMILES_DRAWER_JS=/path/to/smiles-drawer.min.js` to serve the SMILES library
locally. Paths such as `/history/1` assume the seed data.

## Known remaining findings

* `/sketcher`: axe reports `target-size` (15px dropdown toggle) and
  `aria-allowed-role` inside the third-party ChemDoodle widget. These come
  from ChemDoodle's own markup and are not fixable without forking it.
* `target-size` / `aria-allowed-role` findings are all inside ChemDoodle.
* These scripts are not a WCAG conformance claim. Keyboard-only use of the
  sketcher, screen-reader output and reduced-motion behaviour still need
  manual testing with assistive technology.
