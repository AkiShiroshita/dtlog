## Submission

This is a new submission of 'dtlog' (version 0.1.0).

## Test environments

* local: Ubuntu 24.04, R 4.3.3
* local: Windows 11 x64 (build 26200), R 4.6.0 (2026-04-24 ucrt),
  'data.table' 1.18.4
* GitHub Actions:
  * ubuntu-latest, R-devel / R-release / R-oldrel-1
  * macOS-latest, R-release
  * windows-latest, R-release

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Akihiro Shiroshita <akihirokun8@gmail.com>'
  New submission

The words 'dtlog' and 'tidylog' in the DESCRIPTION are package names and are
quoted as required.

The same result (0 errors | 0 warnings | 1 note) was obtained with
`R CMD check --as-cran` on Windows 11 with R 4.6.0; the full test suite
(589 tests in 'testthat') passed there with no failures, warnings or skips.

## Notes for the reviewer

'dtlog' intentionally provides wrappers around functions exported by
'data.table' (for example `[.data.table`, `merge.data.table`, `setnames`) that
print a short message describing what each operation did and then dispatch to
the 'data.table' implementation. Attaching the package therefore masks those
'data.table' functions, which is by design and is documented in the package
help and README. The underlying behaviour, including modification by reference,
is unchanged; `tests/testthat/test-parity.R` and
`tests/testthat/test-no-side-effects.R` verify that results are identical to
plain 'data.table'. This mirrors the approach taken by the 'tidylog' package,
which is already on CRAN.

The package writes no files and changes no global options on load. Logging can
be turned off with `dtlog_pause()`.

## Downstream dependencies

There are currently no downstream dependencies for this package.
