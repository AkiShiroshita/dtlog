## Update submission

This is an update of 'dtlog' from 0.1.0 (on CRAN since 2026-09-15) to 0.2.0.

I am sending it sooner than I otherwise would because it fixes a bug in 0.1.0
that users hit in ordinary code: a logged function called through another
function that forwards its own `...` -- `rbindlist(lapply(files, fread))` is
the common case -- failed with "the ... list contains fewer than 1 element".
It is fixed, and `tests/testthat/` has a regression test for it.

The release also:

* logs nine more functions exported by 'data.table' (`foverlaps()`,
  `rollup()`, `cube()`, `groupingsets()`, `split()`, `fsetequal()`,
  `setnafill()`, `setdroplevels()` and `copy()`);
* raises `Imports: data.table` from `>= 1.14.0` to `>= 1.16.0`, because
  `setdroplevels()` first appeared in 'data.table' 1.16.0;
* adds a CITATION file with the package's Zenodo DOI.

The full list is in NEWS.md.

## Test environments

* Local, `R CMD check --as-cran` (2026-09-25):
  Windows 11 x64 (build 26200), x86_64-w64-mingw32,
  R 4.6.0 (2026-04-24 ucrt).

* win-builder, R release 4.6.1 (2026-06-24 ucrt), Windows Server 2022 x64
  (build 20348), x86_64-w64-mingw32 (2026-09-25).

* win-builder, R Under development (unstable) (2026-09-21 r90579 ucrt),
  Windows Server 2022 x64 (build 20348), x86_64-w64-mingw32 (2026-09-25).

* GitHub Actions, `R CMD check --as-cran` on the submitted source
  (2026-09-16):

  * Ubuntu 24.04.5 LTS, R-devel
  * Ubuntu 24.04.5 LTS, R 4.6.1 (2026-06-24)
  * Ubuntu 24.04.5 LTS, R 4.5.3 (2026-03-11), oldrel-1
  * macOS Tahoe 26.6.2, R 4.6.1 (2026-06-24)
  * Windows Server 2022 x64 (build 26100), R 4.6.1 (2026-06-24 ucrt)

## R CMD check results

0 errors | 0 warnings | 0 notes

on every environment above.

## Notes for the reviewer

As in 0.1.0, 'dtlog' intentionally provides wrappers around functions exported
by 'data.table' that print a short message describing what each operation did
and then dispatch to the 'data.table' implementation. Attaching the package
therefore masks those 'data.table' functions, which is by design and is
documented in the package help and README. The new wrappers in 0.2.0 follow
the same pattern and are covered by the same parity tests
(`tests/testthat/test-parity.R`, `tests/testthat/test-functions-parity.R`),
which check that results are identical to plain 'data.table'.

The package writes no files except to the path a user passes to `dt_log()`
(which has no default), and changes no global options on load.

## Downstream dependencies

There are currently no downstream dependencies for this package.
