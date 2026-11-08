## R CMD check results

── R CMD check results ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── r5r 2.5.0 ────
Duration: 7m 56.3s

0 errors ✔ | 0 warnings ✔ | 0 notes ✔

* Possibly invalid URLs: https://escholarship.org/uc/item/05r820mz, https://hdl.handle.net/2123/23733 and https://mobilitydatabase.org/ return 202 or 403 to automated checks but open normally in a browser.


## Test environments

* GitHub Actions: windows-latest (R release), macOS-latest (R release), ubuntu-22.04 (R devel, release and oldrel), plus an ubuntu-22.04 (R release) job with `NOT_CRAN=false`
* Local: Windows Server 2022, R 4.5.1

## Submission

The license is now `GPL (>= 3) | MIT + file LICENSE` (it was `MIT + file LICENSE`). This change is to reflect the license of upstream software dependency (R5). All copyright holders agreed.


## revdepcheck results

We checked 2 reverse dependencies (r5rgui, spopt), comparing R CMD check results across CRAN and dev versions of this package.

 * We saw 0 new problems
 * We failed to check 0 packages