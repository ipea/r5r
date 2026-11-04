# Project Memory — r5r

Corrections and learned facts that persist across sessions. When a mistake is corrected, or a non-obvious approach is confirmed, append a `[LEARN:category]` entry below (most recent at bottom). Keep this file under 200 lines; it is committed and read by collaborators.

Personal working preferences (not project facts) live in Claude Code's per-user auto-memory, outside this repo.

---

## Repository layout

[LEARN:r5r] Monorepo: the package is in `r-package/`, there is no root `DESCRIPTION`. Every devtools / `R CMD` / `/r-package-check` call must pass the path explicitly (`devtools::test("r-package")`, `/r-package-check r-package`).

[LEARN:r5r] Default branch is `master`, not `main`; PRs are merged with merge commits. The global `/commit` skill's Steps 0/0b (quality_score.py, check-surface-sync.sh) do not apply here.

## Java / R5

[LEARN:r5r] The little JAR `r-package/inst/jar/r5r.jar` is rebuilt by the CI job `build-jar` on every push to a non-protected branch and committed as `Rebuild JAR for commit <sha>`. Never commit a hand-built JAR; after pushing a `java-r5rcore/` change, `git pull` before pushing again.

[LEARN:r5r] Java must be exactly 21 — `start_r5r_java()` in `R/utils.R` aborts on any other major version. `SystemRequirements` says `>= 21.0` but the code is strict.

[LEARN:r5r] The R5 version is pinned in two places that must move together: `R/onLoad.R` (`r5_jar_version`, `r5_jar_size`) and `inst/extdata/metadata_r5r.csv`. The cache dir name `r5r/r5_jar_v<version>` derives from it and stale caches are purged in `.onLoad`.

[LEARN:r5r] `java-r5rcore/build.gradle` shells out to R (`devtools::load_all(); download_r5()`) to find the R5 JAR, so a local Gradle build needs R, devtools and the package deps installed.

## Tests and artifacts

[LEARN:r5r] Tests run only with `NOT_CRAN=true`; `tests/testthat/setup.R` builds the poa and spo networks once for the whole suite. `test-z_r5r_cache.R` is named to run last because it deletes the JAR cache.

[LEARN:r5r] `build_network()` writes `network.dat`, `*.mapdb*`, `gtfs_errors.csv` and `r5r-log.log` into `data_path`. In `inst/extdata/poa|spo` these are build artifacts, not source; `gtfs_errors.csv` was added to `.gitignore` on 2026-09-21.

[LEARN:ci] `remotes::system_requirements("ubuntu", "24.04")` errors (supports only up to 22.04), and inside the `build-jar` `while read ... < <(Rscript ...)` loop that failure is silent: no GDAL/GEOS/PROJ get installed, then Gradle's `download_r5()` call fails with `"sf" is required`. Keep "20.04" (or move to pak/r-lib sysreqs) and never bump this string without checking it runs.

[LEARN:r5r] `r-package/.Rprofile` is tracked but may carry a contributor's machine-local `JAVA_HOME` block (written by rJavaEnv). Never stage it; `git update-index --skip-worktree r-package/.Rprofile` keeps it out of `git status`.

## Claude Code config

[LEARN:claude] A user-level skill (`~/.claude/skills/<name>`) takes precedence over a project skill with the same name, so r5r-specific skill copies never run for anyone who has the user-level twin. Put r5r specifics in `AGENTS.md`, the path-scoped rules, and `.claude/agents/` (project agents DO override user-level agents).

[LEARN:claude] Rule frontmatter must use `paths:`; Cursor-style `globs:` / `alwaysApply:` are ignored, so such a rule loads in every session.

[LEARN:r5r] `start_r5r_java()` called `rJava::.jinit(parameters = c(log_path, ...))`, which REPLACES `.jinit()`'s default `getOption("java.parameters")`, so a user's `-Xmx` was silently ignored from v2.2.0 to v2.4.0 (JVM got its default heap; `.onAttach`/`r5r_sitrep()` still echoed the option). Fixed in dev by prepending `getOption("java.parameters")`. To verify JVM flags, read `RuntimeMXBean$getInputArguments()` / `Runtime$maxMemory()` in a fresh R session; never trust the option value. To benchmark CRAN <= 2.4.0 with a set heap, call `.jinit()` yourself with the flags plus `-DLOG_PATH/-DR5_VER/-DR5R_VER` before `build_network()`.

[LEARN:perf] Building geometries is not where `detailed_itineraries()` spends its time with transit. Java allocation with geometry kept vs `drop_geometry = TRUE` (dev, poa, 50 × 50 pairs, 2026-10-09) was 563,948 vs 563,642 MB (shortest path) and 4,906,857 vs 4,899,706 MB (`suboptimal_minutes = 10`), a difference under 0.2%. The cost is the McRaptor search, about 225 MB allocated per OD pair. On the R side, `java_to_dt()` and `sf` parsing add about 0.5 s (shortest path) and 13 s (suboptimal 10, 197K rows, about 2,700 s per call). Car-only calls are where dropping geometry matters: about 25% of the Java allocation, on calls that take under a second. For transit speed, work on the router (see the FastRaptor idea, #464), not on geometry or path reconstruction.

[LEARN:r5r] `detailed_itineraries()` (#534): `time_window` does not route every whole minute. R5 7.5 `McRaptorSuboptimalPathProfileRouter.generateDepartureTimesToSample` starts at a random second in the first step and advances by random 30–90 s steps (step = window/draws, draws = `time_window`), with a MersenneTwister seeded from the origin's latitude, so the same offsets recur in every call from that origin. Each departure is routed separately and only arrivals within `suboptimal_minutes` of the earliest survive (transfers only break ties); r5r then keeps the fastest per route sequence. Itineraries appearing/disappearing between adjacent minutes is expected, not a bug.

[LEARN:roxygen] The local roxygen2 (8.0.0) is older than the package's RoxygenNote (8.1.0); `devtools::document("r-package")` then rewrites `NAMESPACE` (splits the data.table importFrom) and other untouched `.Rd` files. Keep only the `.Rd` of the function you edited and `git checkout --` the rest.

[LEARN:perf] No JVM heap leak in dev `detailed_itineraries()` (2026-10-09, poa, 10 OD pairs, transit, -Xmx4G, 8 calls): live heap after `Runtime.gc()` stayed at 95 MB on every call, committed heap ~340 MB, GC < 0.2 s per call. The cost is first-call warm-up in each JVM: 5–9 s for call 1, then 1.5 → 0.2 s. A persistent `callr` process behaves like the main session; a fresh `callr::r()` per call pays the warm-up (plus ~15–20 s to load r5r, start Java and read `network.dat`) every time. Benchmarks must report warm and cold calls separately. Read JVM stats with `rJava::.jcall()` and explicit signatures: a callr child using `J("…")$method()` reflection on ManagementFactory beans crashed R with no hs_err log.

[LEARN:perf] Larger heap benchmark (2026-10-09, dev, poa, -Xmx20G, 3 reps per setup): `travel_time_matrix()` 1227×1227 hexgrid, transit, `time_window = 30`, max 60 min; `detailed_itineraries()` on 500 random hexgrid pairs, max 60 min. Live heap after a full GC stays at 100–130 MB (creeps ~5 MB per repeat in the same JVM, likely R5 caches; not a leak at this scale). Used heap reaches 0.4–4.5 GB between collections (allocation churn); GC time is ≤ 0.6 s per ttm call and ≤ 1.5 s per di call. Cold first call (new JVM): ttm 18–28 s, di 24–30 s; warm: ttm 6.5–11 s, di 17–22 s. A fresh `callr::r()` per run adds ~19–21 s setup and always pays the cold call.

[LEARN:perf] Java→R transfer (2026-10-10, dev, poa hexgrid 1227², transit, -Xmx8G): in `java_to_dt()` the String columns dominate (rJava converts one Java string per row); `from_id`/`to_id` were ~85% of it. Sending them as positions (`RDataFrame.getStringColumnIndex()` + `java_to_dt(ids =)`) cut the step from 0.76 to 0.13 s for 1.47 M rows, identical output. Car-only 1227² (1.48 M rows, 5 interleaved pairs in one warm JVM): call 7.20 → 6.16 s median (−14%), new faster in all 5 pairs. Boxed `ArrayList<Object>` storage costs ~nothing on regular TTM (percentile ints are JVM-cached `Integer`s, ids are refs to the input strings: 24 MB retained for 1.47 M rows); primitive columns would only save ~12 B per Double cell (est. 28% of 99 MB on expanded TTM with breakdown, ~0 on DI where results are 1–2 MB). DI time is routing, not transfer (0.06 s of 12 s).

[LEARN:r5r] `java-r5rcore/build.gradle` does not run on Windows: its `R -e 'setwd("../r-package"); …'` loses the inner double quotes ("object '..' not found"). For a local smoke build compile with `javac --release 21 -cp <R5 jar> -d out @sources` (src uses no JRI classes), add `src/main/resources/logback.xml` at the jar root, and swap it into `inst/jar` only temporarily. `PathOptionsTable.java` declares `total_duration` as an Integer column but stores doubles — harmless with untyped storage, must be fixed before any typed `RDataFrame` columns.

[LEARN:r5r] Running `devtools::document()` with a local roxygen2 older than the package's `RoxygenNote` (8.0.0 vs 8.1.0, 2026-10-10) rewrites `NAMESPACE` (`importFrom(data.table, ...)` split one per line) with no semantic change → `git checkout -- r-package/NAMESPACE` after documenting, or update roxygen2. Rendering a vignette with `NOT_CRAN=true` runs its hidden `r5r_cache(delete_file = 'all')` chunk and wipes the local R5 JAR cache.

[LEARN:r5r] #593 (2026-10-19): with frequency-based GTFS (spo has `frequencies.txt`, poa does not), FastRaptor results vary run to run because R5 7.5.1 `FrequencyRandomOffsets.mt = new MersenneTwister()` is unseeded; R's `set.seed()` cannot reach it. Seeding it per origin from java-r5rcore (reflection on `FastRaptorWorker.offsets` → `mt.setSeed(...)` right after `new FastRaptorWorker` in `R5TravelTimeComputer`) makes results identical across runs and `n_threads`, with no R5 change; the McRaptor/fare branch is not covered. Evidence, hook diff and draft reply: `quality_reports/plans/2026-10-19_593-seed-reprex_support/`.

[LEARN:r5r] `expanded_travel_time_matrix()` `draw_number` was assigned in R5's `iterationsForPathTemplates` hash order (RouteSequence keys), so it changed between runs even with identical trips; fixed for #593 by sorting each departure minute's paths in `TravelTimeMatrixComputer.extractPathResults` (`PATH_ORDER`). Also: `detailed_itineraries()` rejects networks with `frequencies.txt`, so it has no Monte Carlo randomness to seed.

[LEARN:r5r] Full `devtools::test("r-package")` on this machine (2026-10-19, master db235b32): 3 failures + 1 error are pre-existing and order-dependent/environmental — `build_network` 'overwrite' and `stop_r5` message expectations (pass when run alone), `setup_fare_structure` needs `gtfstools` (not installed). Compare against master before blaming a change.

[LEARN:r5r] R5 7.6 `transit.path.Path` has only `patternSequence` (`patterns`; `stopSequence.boardStops/alightStops/rideTimesSeconds/transferTimesSeconds`, first transfer = 0) and `boardTimes` (clock); no waits, trip or pattern positions. Waits = `boardTimes[k]` − (departure + access + rides + transfers so far); positions must be matched against `TripSchedule.departures/arrivals` (patterns can visit a stop twice). Paths are shared across iterations: never call `setAccess`/`computeWaitTimes` on them. `FastRaptorWorker` fails a `checkState` (with `time_window >= 2`) when an access time is ≥ `max_trip_duration`, so filter access stops first (#464).

[LEARN:r5r] On networks with elevation (poa uses TOBLER), egress `StreetRouter` searches run backwards from the destination, so `getReachedStops()` / `getStateAtVertex()` times cost each edge in the reverse direction (seen: 292 s uphill), while `StreetPath(state, net, true)` re-times the leg forwards with `State.reverse()` (95 s downhill), and that is what `detailed_itineraries()` reports. Ranking trips by the backward egress times picks trips that are not the fastest by their own reported duration. The FastRaptor path of `detailed_itineraries()` (shortest path, no fares, #464) ranks with `state.reverse(net).getDurationSeconds()`; the McRaptor path (alternatives or fares) still ranks with the backward times (open issue, 2026-10-20).
