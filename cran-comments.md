## Submission

This is the first submission of 'dtlog' (version 0.1.0).

## Test environments

* win-builder, R release 4.6.1 (2026-06-24 ucrt), Windows Server 2022 x64
  (build 20348), x86_64-w64-mingw32 -- Status: 1 NOTE (2026-08-22).

* win-builder, R Under development (unstable) (2026-08-21 r90440 ucrt),
  Windows Server 2022 x64 (build 20348), x86_64-w64-mingw32 -- Status: 1 NOTE
  (2026-08-22).

* GitHub Actions, `R CMD check --as-cran` (2026-08-22) -- Status: OK on each
  of:

  * Ubuntu 24.04.4 LTS, x86_64-pc-linux-gnu, R-devel (2026-06-21 r90185)
  * Ubuntu 24.04.4 LTS, x86_64-pc-linux-gnu, R 4.6.1 (2026-06-24)
  * Ubuntu 24.04.4 LTS, x86_64-pc-linux-gnu, R 4.5.3 (2026-03-11), oldrel-1
  * macOS Tahoe 26.5.2, aarch64-apple-darwin23, R 4.6.1 (2026-06-24)
  * Windows Server 2022 x64 (build 26100), x86_64-w64-mingw32,
    R 4.6.1 (2026-06-24 ucrt)

* R-hub v2, `R CMD check` (2026-08-22) -- Status: OK on each of:

  * macOS Sequoia 15.7.7, x86_64-apple-darwin20,
    R-devel (2026-06-24 r90190)
  * Ubuntu 22.04.5 LTS, x86_64-pc-linux-gnu, R-devel (2026-08-21 r90440),
    built without long doubles ('nold')
  * Fedora Linux 42, x86_64-pc-linux-gnu, R-devel (2026-06-21 r90185), with
    the suggested packages made unavailable ('nosuggests')

## R CMD check results

Every GitHub Actions and R-hub platform above reports Status: OK -- 0 errors,
0 warnings, 0 notes. Both win-builder runs (R-release and R-devel) report 0 errors |
0 warnings | 1 note.

The note is the expected one for a package not yet on CRAN:

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Akihiro Shiroshita <akihirokun8@gmail.com>'

New submission
```

The words 'dtlog' and 'tidylog' in the DESCRIPTION are package names and are
quoted as required. `dttable()` and `base::table()` in the Description field
are function names, so they are not quoted.

`R CMD check` reports OK for every other check on every platform above,
including the examples, the vignette, the PDF and HTML versions of the manual,
and the test suite (testthat edition 3, 818 expectations across 10 files, none
failing).

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

The package also provides `dttable()`, which describes a single 'data.table'
(one row per column, with the number of unique values and the values
themselves). `dttable()` is a function of its own and masks nothing: no
function in 'base' is affected by attaching 'dtlog'. Every call that is not a
single 'data.table' is passed on to `base::table()` unchanged, and
`tests/testthat/test-dttable.R` checks that those calls return exactly what
`base::table()` returns.

The package writes no files and changes no global options on load. Logging can
be turned off with `dtlog_pause()`.

## Downstream dependencies

There are currently no downstream dependencies for this package.
