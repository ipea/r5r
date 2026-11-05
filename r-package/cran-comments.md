## Submission

The license is now `GPL (>= 3) | MIT + file LICENSE` (it was `MIT + file LICENSE`). This change is to reflect the license of upstream software dependency (R5). All copyright holders agreed.

## Test environments

* GitHub Actions: windows-latest (R release), macOS-latest (R release), ubuntu-22.04 (R devel, release and oldrel), plus an ubuntu-22.04 (R release) job with `NOT_CRAN=false`
* Local: Windows Server 2022, R 4.5.1

## R CMD check results

0 errors | 0 warnings | 1 note

* Possibly invalid URLs: https://escholarship.org/uc/item/05r820mz, https://hdl.handle.net/2123/23733 and https://mobilitydatabase.org/ return 202 or 403 to automated checks but open normally in a browser.

## Java and network use

r5r needs Java JDK 21 (SystemRequirements). On first use, `build_network()` downloads the R5 routing engine (a ~64 MB JAR file) from its GitHub release and caches it in `tools::R_user_dir("r5r", "cache")`; `r5r_cache()` lists and deletes it. Because of the Java requirement and the download, examples run only with `@examplesIf NOT_CRAN`, vignettes are evaluated only when `NOT_CRAN` is `"true"`, and tests are skipped on CRAN (`skip_on_cran()`). They all run in our CI.

## Reverse dependencies

We checked the 2 reverse dependencies (r5rgui, spopt) with `R CMD check` against this version: 0 new problems.
