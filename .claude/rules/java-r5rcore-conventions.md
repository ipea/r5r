---
paths:
  - "java-r5rcore/**"
  - "r-package/inst/jar/**"
  - "r-package/inst/extdata/metadata_r5r.csv"
  - "r-package/R/onLoad.R"
  - "r-package/R/download_r5.R"
  - "r-package/R/utils.R"
  - "r-package/R/java_utils.R"
  - "r-package/R/r5r_cache.R"
  - "r-package/R/set.R"
  - "r-package/R/assign.R"
---

# Java / R5 Bridge Conventions (r5r)

**Standard:** the R side never carries logic that belongs in Java, the shipped JAR is always the CI build of the committed sources, and an R5 upgrade is a single atomic change across all pinned locations.

## 1. Two JARs, two lifecycles

| JAR | Origin | Lifecycle |
|---|---|---|
| **R5** (`r5-v*-all.jar`, ~64 MB) | Conveyal release, downloaded by `download_r5()` into `tools::R_user_dir("r5r/r5_jar_v<ver>", "cache")` | Pinned by version; never shipped in the package (`.Rbuildignore` excludes `inst/jar/r5-*.jar`, `.gitignore` excludes `r5-*.jar`) |
| **r5r core** (`r-package/inst/jar/r5r.jar`, small) | Gradle build of `java-r5rcore/src` | Built and committed **by CI only** (`build-jar` job); `.gitattributes` marks it `binary` + `merge=ours` |

## 2. Little JAR: never hand-build and commit

- Edit `java-r5rcore/src/org/ipea/r5r/**`, push the branch. CI (JDK 21 Temurin, `gradle build`) compares the sha256 of `build/libs/java-r5rcore-*.jar` with `inst/jar/r5r.jar` and, if different, commits `Rebuild JAR for commit <sha>` to your branch. The job is skipped on protected refs (`master`).
- **After every push touching `java-r5rcore/`, run `git pull` before further pushes**, otherwise the bot's commit causes a rejected push.
- A local `./gradlew build` is a compile smoke test only. Two different overrides exist: `options(r5r.r5jar = "<path>")` swaps the *big R5* JAR (to test an unreleased R5); there is no option for the *little* JAR. To exercise a local little-JAR build in R without committing it, temporarily copy `build/libs/java-r5rcore-*.jar` over `inst/jar/r5r.jar`, `devtools::load_all("r-package")`, and **discard the copy** (`git checkout -- r-package/inst/jar/r5r.jar`) before staging.
- Gradle needs R on PATH with devtools and the package's Imports installed: `build.gradle` runs `download_r5()` to resolve the R5 JAR and reads `JRI.jar` from the installed rJava.

## 3. R5 version bump checklist (atomic)

1. `r-package/inst/extdata/metadata_r5r.csv`: add the row `version;date;download URL` for the Conveyal release.
2. `r-package/R/onLoad.R`: update `r5r_env$r5_jar_version` and `r5r_env$r5_jar_size` (byte size of the JAR as actually downloaded from the URL in step 1 — measure it, don't copy it from the release page; used as the corruption check in `start_r5r_java()`).
3. Rebuild the little JAR against the new R5 (push → CI) and fix any API breakage in `java-r5rcore/src` (R5 internals change between releases).
4. Run the full test suite and `R CMD check --as-cran r-package`.
5. `NEWS.md` bullet naming the R5 version, and a note in `cran-comments.md` if the check output changed.

## 4. Java version policy

- Exactly **21**: `start_r5r_java()` aborts on any other major version with install links (rJavaEnv, Temurin, Corretto, OpenJDK, Oracle). Keep the Gradle toolchain, CI `setup-java`, `SystemRequirements`, README and `r5r_sitrep()` consistent when this ever changes.
- Do not add `-Xmx` inside the package. Memory is the user's call via `options(java.parameters = "-Xmx<N>G")` before `library(r5r)`; `.onAttach` reminds them.

## 5. JVM start and logging

- `rJava::.jinit()` is called once per session in `start_r5r_java()` with `-DLOG_PATH=<data_path>/r5r-log.log`, `-DR5_VER`, `-DR5R_VER` (read in `R5RCore.java`; logback config in `java-r5rcore/src/main/resources/logback.xml`). Verbosity and progress are toggled through `set_verbose()` / `set_progress()`, not by editing logback.
- `stop_r5()` releases the core; `r5r_cache()` lists/deletes cached R5 JARs.

## 6. R ↔ Java data boundary

- Java returns tabular results as `RDataFrame`; R converts with `java_to_dt()` (`R/java_utils.R`). Add columns on the Java side and convert types there; do not post-process in R what Java can emit correctly.
- Routing parameters flow one way: R `set_*()` helpers (`R/set.R`) → `RoutingProperties.java`. A new parameter needs (a) the Java field + setter, (b) the R `set_*()` helper with `checkmate` validation, (c) the `assign_*()` coercion if user-facing, (d) roxygen docs on every function that exposes it, (e) a test.
- **Semantics must survive the trip.** The documented unit, default, bound (inclusive/exclusive) and meaning of an R argument must match what R5 does with the field it lands in. Most past r5r bugs are this mismatch (cutoffs, fractional opportunities, `max_car_time` on car-only trips, transfer-walk durations) — when touching `set.R`/`assign.R`, trace the argument to the R5 request and test the boundary.
- Java is `org.ipea.r5r.*` with `Process/`, `Fares/`, `Network/`, `Planner/`, `Scenario/` packages; keep new classes in the matching package.

## 7. Checklist

```
[ ] No hand-built inst/jar/r5r.jar staged; git pull after CI rebuilt the JAR on the branch
[ ] R5 bump: metadata_r5r.csv + onLoad.R (version + size) + NEWS.md changed together
[ ] Java 21 references consistent (utils.R check, CI, DESCRIPTION, README)
[ ] New routing parameter wired through RoutingProperties.java + set_*() + docs + test
[ ] Full suite green locally (NOT_CRAN=true) before pushing Java changes
```

## Cross-references

- [`r-package-conventions.md`](r-package-conventions.md) — R-side CRAN standard.
- `AGENTS.md` §"Java / R5 Bridge Contract" — the summary table.
