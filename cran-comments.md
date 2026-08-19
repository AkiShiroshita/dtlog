## Submission

This is the first submission of 'dtlog' (version 0.1.0).

## Test environments

* local: Windows 11 x64 (build 26200), R 4.6.0 (2026-04-24 ucrt), platform
  x86_64-w64-mingw32, 'data.table' 1.18.4 -- `R CMD build` followed by
  `R CMD check --as-cran` on the resulting tarball -- Status: 1 NOTE
  (2026-08-18).

* win-builder, R release 4.6.1 (2026-06-24 ucrt), Windows Server 2022 x64
  (build 20348) -- Status: 1 NOTE (2026-08-18).

* win-builder, R Under development (unstable) (2026-08-17 r90424 ucrt),
  Windows Server 2022 x64 (build 20348) -- Status: 1 NOTE (2026-08-18).

* GitHub Actions, `R CMD check --as-cran` (2026-08-18) on each of:

  * Ubuntu 24.04, R-devel
  * Ubuntu 24.04, R release
  * Ubuntu 24.04, R oldrel-1
  * macOS (aarch64-apple-darwin23), R 4.6.1
  * Windows Server, R release

## R CMD check results

Every GitHub Actions platform above reports Status: OK -- 0 errors, 0 warnings,
0 notes. Both win-builder runs (R-release and R-devel) report 0 errors |
0 warnings | 1 note, and locally the result is 0 errors | 0 warnings | 1 note.

The note is the expected one for a package not yet on CRAN:

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Akihiro Shiroshita <akihirokun8@gmail.com>'

New submission
```

The words 'dtlog' and 'tidylog' in the DESCRIPTION are package names and are
quoted as required.

`R CMD check` reports OK for every other check, including the examples, the
vignette and the test suite (testthat edition 3, 90 tests and 778 expectations
across 9 files, none failing and none skipped).

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

The package also exports `table()`, which masks `base::table()`. It adds one
behaviour: a single 'data.table' is described (one row per column, with the
number of unique values and the values themselves). Every other call is passed
on to `base::table()` unchanged, and `tests/testthat/test-table.R` checks that
those calls return exactly what `base::table()` returns.

The package writes no files and changes no global options on load. Logging can
be turned off with `dtlog_pause()`.

## Downstream dependencies

There are currently no downstream dependencies for this package.
