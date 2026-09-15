# yongzesong/app — online calculators (shared Shinylive runtime)

Static export of Yongze Song's six Shinylive (webR) online calculators, published
as a GitHub **project** site. Because the user site `yongzesong.github.io` carries
the custom domain, this repository is served at

    https://yongzesong.com/app/            landing page (index.html)
    https://yongzesong.com/app/gcf/        GCF  — generalized covariate field
    https://yongzesong.com/app/opgd/       OPGD — optimal parameters-based geographical detector
    https://yongzesong.com/app/gc/         GC   — geocomplexity
    https://yongzesong.com/app/lisp/       LISP — local indicator of stratified power
    https://yongzesong.com/app/dsi/        DSI  — degree of spatial interpretability
    https://yongzesong.com/app/gos/        GOS  — geographically optimal similarity

i.e. exactly the URLs the calculators had when they lived in `app/` of the main
site repo. Everything runs in the visitor's browser (R compiled to WebAssembly);
there is no server component.

## Layout: one runtime, six apps

```
app/
├── index.html            landing page (site look; stylesheet = ../assets/css/style.css,
│                         which resolves to the main site at the domain level)
├── shinylive-sw.js       the ONE service worker, registered with scope /app/
├── shinylive/            the ONE Shinylive 0.10.12 runtime (≈ 65 MB)
│   └── webr/packages/    union of the wasm R packages of all six apps (≈ 78 MB)
│                         + metadata.rds (package index, merged across the exports)
├── gcf/                  ┐ per app: index.html (title + favicon patched), app.json
├── gos/                  │ (the app's source files, serialised), favicon.svg,
├── opgd/                 │ edit/index.html (redirect to the editor view)
├── lisp/                 │
├── gc/                   │
├── dsi/                  ┘
├── tools/export-all.R    the build script (see below)
├── .nojekyll             GitHub Pages: publish as-is (no Jekyll processing)
└── README.md
```

The previous deployment kept six self-contained exports (481 MB), each with its
own byte-identical 65 MB copy of the runtime. This layout is ≈ 146 MB: 65 MB
runtime + 78 MB packages + a few MB of app files.

How the sharing works (all documented `shinylive::export()` behaviour, nothing
hand-patched):

* `shinylive::export(appdir, destdir, subdir = "<abbr>")` writes the app into
  `destdir/<abbr>/` and the runtime into `destdir/shinylive/` +
  `destdir/shinylive-sw.js`. The export template receives `REL_PATH = "../"`,
  so each `<abbr>/index.html` loads `./../shinylive/load-shinylive-sw.js`,
  `./../shinylive/shinylive.js` and the CSS, and calls
  `runExportedApp({ relPath: "../" })`.
* `shinylive/load-shinylive-sw.js` registers the service worker at
  `dirname(dirname(<its own directory>)) + "/shinylive-sw.js"`, i.e. at
  `/app/shinylive-sw.js` with scope `/app/`. One worker therefore serves all six
  app folders (its fetch handler matches any `…/app_<id>/…` path under its scope).
* Wasm packages go to `destdir/shinylive/webr/packages/<pkg>/<pkg>_<ver>.tgz`;
  `metadata.rds` is merged across successive exports into the same `destdir`
  (`package_cache = TRUE`), so the runtime sees the union of the six package
  sets. At run time the runtime reads `shinylive/webr/packages/metadata.rds`
  (relative to its own location) and `webr::mount()`s **every** package listed
  there before the app starts — see the trade-off below.

## Trade-off: every app downloads the union of packages

Because the package index is per runtime, not per app, a visitor's first load
of *any* calculator fetches all 54 package tarballs (82 MB), not only the ones
that app uses. Measured in headless Chrome with a cold cache (bytes on the
wire, localhost):

| app | old per-app export | this shared export |
|-----|-------------------:|-------------------:|
| dsi | 44 MB (runtime 43.5 + rpart 0.6) | 125 MB (runtime 43.5 + 54 tgz 81.9) |
| gc  | 44 MB (runtime only)             | 125 MB |
| gcf | 99 MB (runtime 45 + 34 tgz 54)   | 127 MB |

(The runtime figure is what webR actually fetches — R.wasm, library.data.gz
and the lazily loaded base-library images — not the 65 MB on disk.) The
tarballs have the same URL for all six apps, so after one calculator has been
opened the other five load their packages from the browser cache; GitHub Pages
serves them with `Cache-Control: max-age=600` and ETags, so later visits cost
54 conditional requests answered with 304. Boot time on localhost was within
one second of the old exports (mounting the extra archives is cheap), and all
54 archives are held in the tab's memory. If the light calculators (lisp, gc,
dsi: only rpart) should stay at 44 MB, the alternative is a second runtime
folder for them (a custom `template_dir` pointing their pages at
`../shinylive-lite/`): repo ≈ 210 MB instead of 146 MB, light apps 44 MB,
heavy apps unchanged at 127 MB. This export keeps the single runtime as
specified.

## Re-export

```bash
Rscript tools/export-all.R                  # clean export (default)
Rscript tools/export-all.R --keep-packages  # keep shinylive/webr/packages/ so
                                            # unchanged wasm binaries are not
                                            # downloaded again
```

Requirements: R with `shiny` and `shinylive` (>= 0.5.0; the current export used
shinylive 0.5.0 with assets 0.10.12 and R 4.6.0) and internet access to
`repo.r-wasm.org` (the exporter fetches the wasm package binaries from there).
The script is idempotent: it deletes the previous `<abbr>/` folders and the
runtime, exports the six apps, patches each `index.html` (page title + SVG
favicon link, exactly as each app's original `tools/export.R` did), copies the
favicon, then verifies the shared layout and prints the package list and sizes.

App sources (read by the script, never modified by it):

| app  | source folder | title | favicon |
|------|---------------|-------|---------|
| gcf  | `claudespace/10-papers/accepted/2602-cc003-GCF/software/app/gcf-app/` | GCF Calculator | `gcf-app/favicon.svg` |
| gos  | `claudespace/70-software/_archive/2608-gos/app/`  | GOS calculator  | `2608-gos/tools/favicon.svg` |
| opgd | `claudespace/70-software/_archive/2608-opgd/app/` | OPGD calculator | `2608-opgd/tools/favicon.svg` |
| lisp | `claudespace/70-software/_archive/2608-lisp/app/` | LISP calculator | `2608-lisp/tools/favicon.svg` |
| gc   | `claudespace/70-software/_archive/2608-gc/app/`   | GC calculator   | `2608-gc/tools/favicon.svg` |
| dsi  | `claudespace/70-software/_archive/2608-dsi/app/`  | DSI calculator  | `2608-dsi/tools/favicon.svg` |

(`claudespace` = `~/Library/CloudStorage/Dropbox/claudespace`; the absolute
paths are at the top of `tools/export-all.R`.) Each project also keeps its own
single-app `tools/export.R` + `site/`; those are unaffected.

To update one calculator: edit its source, run the script (with
`--keep-packages` if no dependency changed), commit, push.

## Local preview

Shinylive needs a service worker, so the folder must be served over http on
`localhost`/`127.0.0.1` (or https), not opened as a file:

```bash
python3 -m http.server 8700 --directory .
# open http://localhost:8700/gcf/   (the landing page's ../assets/css links only
# resolve on the real domain; the calculators themselves are self-contained)
```

To mimic production paths (`/app/<abbr>/`), serve a temp folder that contains a
symlink `app -> <this folder>` and open `http://127.0.0.1:8700/app/gcf/`.

Note: the Claude Code browser pane cannot register a service worker on
localhost; test with a normal browser or headless Chrome.

## DEPLOY (manual steps)

The main site repo currently has its own `app/` folder with the six old exports.
While it exists it **shadows** this project site (the user site wins for
`/app/…`), so the order below matters: publish this repo first, verify, and only
then remove `app/` from the main site.

1. On GitHub create an empty **public** repository `yongzesong/app` (no README,
   no .gitignore, no licence — this folder already has them).

2. From this folder, first commit and push (the folder is already `git init`-ed,
   nothing is committed yet):

   ```bash
   cd "~/Library/CloudStorage/Dropbox/claudeWorkspace/GitHub/app"
   git add -A
   git status            # expect: index.html, README.md, tools/, shinylive/, shinylive-sw.js, six app folders, .nojekyll, .gitignore
   git commit -m "Six Shinylive calculators sharing one runtime"
   git branch -M main
   git remote add origin https://github.com/yongzesong/app.git
   git push -u origin main
   ```

   The push is ≈ 146 MB (largest single files: `sf_1.1-1.tgz` 10 MB,
   `R.wasm` 18 MB, `library.data.gz` 15 MB — all under GitHub's 100 MB limit,
   so no Git LFS is needed).

3. On GitHub: repository **Settings → Pages → Build and deployment → Source:
   Deploy from a branch**, branch `main`, folder `/ (root)`, Save. Because
   `.nojekyll` is present the files are published as-is.

4. Wait for the Pages build (Actions tab → "pages build and deployment", usually
   one to two minutes). The project site is then live at
   `https://yongzesong.com/app/` — but still shadowed by the main site's `app/`
   folder for every path that exists there.

5. Verify before touching the main site: the Actions run is green and
   Settings → Pages shows "Your site is live at https://yongzesong.com/app/".
   Opening `https://yongzesong.com/app/` should already show the new landing
   page (the old `app/` folder had no `index.html`, so nothing shadows it); if
   the domain still answers with the main site's 404 page for it, that is the
   user-site shadowing and it clears in step 6. The app URLs themselves keep
   showing the old exports until step 6.

6. Only then, in the main site repo `yongzesong.github.io`:

   ```bash
   git rm -r app
   git commit -m "Move online calculators to the yongzesong/app project site"
   git push
   ```

   After its Pages build finishes, `https://yongzesong.com/app/gcf/` (and
   `/opgd/`, `/gc/`, `/lisp/`, `/dsi/`, `/gos/`) are served from this repo.
   Open each one: the tab title/favicon must be the calculator's, "Load example
   data" then the compute button must produce the figures, and DevTools →
   Application → Service Workers must show one worker `…/app/shinylive-sw.js`
   with scope `https://yongzesong.com/app/`. Visitors who still have the old
   per-app workers registered (`/app/gcf/shinylive-sw.js`, scope `/app/gcf/`)
   get a 404 on that worker's update check, Chrome drops it, and the new one
   takes over on the next load; a hard reload fixes any stale case.

7. Housekeeping (optional): the links on the main site (`index.html#software`,
   `methods.html`, the reproduce tutorials) all point to `app/<abbr>/` and need
   no change.

## Verification of the current export

Every app was run end to end in headless Chrome (CDP) from a static server
under the production path prefix (`http://127.0.0.1:8700/app/<abbr>/`), each
in a fresh browser context: page load, webR boot, "Load example data",
the compute button, all result figures/tables rendered, no JavaScript
exceptions, every request answered 200/304, service worker
`/app/shinylive-sw.js` with scope `/app/` controlling the page. Cold-cache
timings on an Apple-silicon Mac: webR boot 5–11 s; compute — gcf 42 s
(900 cells, B = 20 selection), gos 44 s (894 samples × 13,132-cell grid),
lisp 9 s, opgd 2 s, gc 2 s, dsi 1 s. The R console messages that webR routes
to `console.error` (package start-up messages; for GCF also the expected
"thread constructor failed" from the one-off ranger probe, after which the app
uses its randomForest kernel) are the only console errors.

## Versions in the current export

* Shinylive R package 0.5.0, Shinylive assets 0.10.12, webR bundled with those
  assets (R 4.6), exported on 2026-09-15.
* 54 wasm packages in `shinylive/webr/packages/` — the union of the six apps'
  dependency chains, all byte-identical to the binaries the previous six
  exports shipped (no version changed on repo.r-wasm.org between the two
  exports). Heaviest: sf 1.1-1, terra 1.9-27, spdep 1.4-2, s2 1.1.7 (GCF),
  ggplot2 4.0.3 (GOS), GD 10.9 (OPGD).
