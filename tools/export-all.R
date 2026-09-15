# tools/export-all.R — export the six Shinylive (webR) calculators into ONE
# folder that shares a single shinylive/ runtime.
#
# Run from anywhere:
#   Rscript tools/export-all.R                  # clean export (default)
#   Rscript tools/export-all.R --keep-packages  # keep shinylive/webr/packages/
#                                               # (skips re-downloading wasm
#                                               # binaries that are unchanged)
#
# Requires: install.packages(c("shiny", "shinylive"))  (shinylive >= 0.5.0,
# assets 0.10.12 were used for the current export).
#
# How the sharing works (documented shinylive::export() behaviour):
#   * export(appdir, destdir, subdir = "<abbr>") writes the app's index.html,
#     app.json and edit/ into destdir/<abbr>/ and the runtime into
#     destdir/shinylive/ plus destdir/shinylive-sw.js; the template computes
#     REL_PATH = "../" so every <abbr>/index.html loads ../shinylive/*.
#   * shinylive/load-shinylive-sw.js registers the service worker at
#     dirname(dirname(<script dir>)) + "/shinylive-sw.js" = destdir root, so
#     one worker (scope = destdir/) serves all app subfolders.
#   * wasm packages are downloaded into destdir/shinylive/webr/packages/ and
#     shinylive/webr/packages/metadata.rds is MERGED across successive exports
#     into the same destdir (package_cache = TRUE), so the runtime sees the
#     union of all six apps' packages.
#
# Post-processing replicates each app's original tools/export.R exactly:
# shinylive writes a generic <title>Shiny App</title>; it is replaced by the
# app's title plus an SVG favicon link, and favicon.svg is copied next to
# index.html.

root <- normalizePath(file.path(dirname(sub("^--file=", "",
  grep("^--file=", commandArgs(FALSE), value = TRUE))), ".."))
args <- commandArgs(TRUE)
keep_packages <- "--keep-packages" %in% args

space <- "/Users/268222h/Library/CloudStorage/Dropbox/claudespace"
arch  <- file.path(space, "70-software", "_archive")
gcf_app <- file.path(space, "10-papers", "accepted", "2602-cc003-GCF",
                     "software", "app", "gcf-app")

# Order = order on the landing page / main site.
apps <- list(
  gcf  = list(appdir  = gcf_app,
              title   = "GCF Calculator",
              favicon = file.path(gcf_app, "favicon.svg")),
  gos  = list(appdir  = file.path(arch, "2608-gos", "app"),
              title   = "GOS calculator",
              favicon = file.path(arch, "2608-gos", "tools", "favicon.svg")),
  opgd = list(appdir  = file.path(arch, "2608-opgd", "app"),
              title   = "OPGD calculator",
              favicon = file.path(arch, "2608-opgd", "tools", "favicon.svg")),
  lisp = list(appdir  = file.path(arch, "2608-lisp", "app"),
              title   = "LISP calculator",
              favicon = file.path(arch, "2608-lisp", "tools", "favicon.svg")),
  gc   = list(appdir  = file.path(arch, "2608-gc", "app"),
              title   = "GC calculator",
              favicon = file.path(arch, "2608-gc", "tools", "favicon.svg")),
  dsi  = list(appdir  = file.path(arch, "2608-dsi", "app"),
              title   = "DSI calculator",
              favicon = file.path(arch, "2608-dsi", "tools", "favicon.svg"))
)

for (abbr in names(apps)) {
  a <- apps[[abbr]]
  if (!dir.exists(a$appdir))  stop("App source not found: ", a$appdir)
  if (!file.exists(a$favicon)) stop("Favicon not found: ", a$favicon)
}

# ---- clean previous export ---------------------------------------------------
# shinylive::export() never overwrites an existing runtime file (it only warns
# when the copy differs), so start from a clean slate.
cat("== Cleaning previous export in", root, "\n")
for (abbr in names(apps)) unlink(file.path(root, abbr), recursive = TRUE)
unlink(file.path(root, "shinylive-sw.js"))
if (keep_packages && dir.exists(file.path(root, "shinylive", "webr", "packages"))) {
  cat("   keeping shinylive/webr/packages/ (package cache)\n")
  keep <- file.path(root, "shinylive", "webr", "packages")
  for (f in list.files(file.path(root, "shinylive"), full.names = TRUE,
                       all.files = TRUE, no.. = TRUE)) {
    if (basename(f) != "webr") unlink(f, recursive = TRUE)
  }
  for (f in list.files(file.path(root, "shinylive", "webr"), full.names = TRUE,
                       all.files = TRUE, no.. = TRUE)) {
    if (basename(f) != "packages") unlink(f, recursive = TRUE)
  }
} else {
  unlink(file.path(root, "shinylive"), recursive = TRUE)
}

# ---- export each app into root/<abbr>/ -------------------------------------
t_all <- Sys.time()
for (abbr in names(apps)) {
  a <- apps[[abbr]]
  cat("\n== Exporting", abbr, "from", a$appdir, "\n")
  t0 <- Sys.time()
  shinylive::export(a$appdir, root, subdir = abbr, quiet = FALSE)

  # Post-process index.html: page title + hex-logo favicon (exactly what each
  # app's original tools/export.R does; the favicon link goes on the line
  # after the title).
  idx <- file.path(root, abbr, "index.html")
  html <- readLines(idx, warn = FALSE)
  hit <- grep("<title>Shiny App</title>", html, fixed = TRUE)
  if (length(hit) != 1)
    stop("Expected exactly one '<title>Shiny App</title>' line in ", idx,
         " but found ", length(hit), " — the shinylive export template changed.")
  html <- sub("<title>Shiny App</title>",
              paste0("<title>", a$title, "</title>\n",
                     '    <link rel="icon" type="image/svg+xml" href="./favicon.svg" />'),
              html, fixed = TRUE)
  writeLines(html, idx)
  file.copy(a$favicon, file.path(root, abbr, "favicon.svg"), overwrite = TRUE)

  # Sanity: the page must load the SHARED runtime one level up.
  if (!any(grepl('"./../shinylive/load-shinylive-sw.js"', html, fixed = TRUE)))
    stop(idx, " does not reference ../shinylive/ — subdir export failed?")
  if (dir.exists(file.path(root, abbr, "shinylive")))
    stop("Unexpected per-app runtime copy at ", file.path(root, abbr, "shinylive"))
  cat(sprintf("   done in %.0f s: title '%s', favicon copied\n",
              as.numeric(difftime(Sys.time(), t0, units = "secs")), a$title))
}

# ---- verify the shared layout ----------------------------------------------
cat("\n== Verifying shared layout\n")
stopifnot(file.exists(file.path(root, "shinylive-sw.js")),
          file.exists(file.path(root, "shinylive", "load-shinylive-sw.js")),
          file.exists(file.path(root, "shinylive", "shinylive.js")),
          file.exists(file.path(root, "shinylive", "webr", "R.wasm")))
meta_file <- file.path(root, "shinylive", "webr", "packages", "metadata.rds")
stopifnot(file.exists(meta_file))
meta <- readRDS(meta_file)
pk <- vapply(meta, function(m) {
  if (length(m$assets)) sprintf("%s %s", m$name, m$assets[[1]]$version)
  else sprintf("%s (no wasm binary!)", m$name)
}, character(1))
cat(sprintf("   %d wasm packages in shinylive/webr/packages/ (metadata.rds):\n",
            length(pk)))
cat(paste0("     ", sort(unname(pk)), "\n"), sep = "")
missing <- vapply(meta, function(m) length(m$assets) == 0, logical(1))
if (any(missing))
  warning("Packages without a wasm binary: ",
          paste(names(meta)[missing], collapse = ", "))

dir_mb <- function(p) sum(file.info(list.files(p, recursive = TRUE,
                       full.names = TRUE, all.files = TRUE))$size) / 1024^2
cat("\n== Sizes (MB)\n")
for (d in c(names(apps), "shinylive"))
  cat(sprintf("   %-10s %7.1f\n", d, dir_mb(file.path(root, d))))
cat(sprintf("   %-10s %7.1f\n", "TOTAL", dir_mb(root)))
cat(sprintf("\nAll six apps exported in %.0f s.\n",
            as.numeric(difftime(Sys.time(), t_all, units = "secs"))))
cat("Preview (service worker needs localhost or https):\n",
    "  python3 -m http.server 8700 --directory ", root, "\n",
    "  then open http://localhost:8700/gcf/ (or /gos/, /opgd/, /lisp/, /gc/, /dsi/)\n",
    sep = "")
