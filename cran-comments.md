## Resubmission

This is a resubmission of the first submission of 'dtlog' (version 0.1.0).

The reviewer wrote:

> Please ensure that your functions do not write by default or in your
> examples/vignettes/tests in the user's home filespace (including the package
> directory and getwd()). This is not allowed by CRAN policies. Please omit any
> default path in writing functions. In your examples/vignettes/tests you can
> write to tempdir().

`dt_log()`, the one function in the package that creates a file, had
`file = "dtlog.txt"` as its default and so would have written to `getwd()` when
called without a path. That default is gone: `file` is now a required argument,
and `dt_log()` called without one stops with

```
Error: dt_log(): `file` must be a single path; there is no default
```

The documentation of the argument says so, and
`tests/testthat/test-transcript.R` checks both the error and that no
`dtlog.txt` is left behind.

No other function in the package writes a file of its own. `fwrite()` is a
logging wrapper around `data.table::fwrite()`, which has no default path
either, and the transcript is only ever written to the path the user passes to
`dt_log()`.

Every example, the vignette and the whole test suite already wrote to
`tempfile()` only, and they still do. I re-checked the sources for a written
path outside `tempdir()` and found none.

## Submission

This is the first submission of 'dtlog' (version 0.1.0).

## Test environments

Every environment below was re-checked on 2026-09-05, on the source of this
resubmission.

* win-builder, R release, Windows Server 2022 x64, x86_64-w64-mingw32 --
  submitted 2026-09-05.

* win-builder, R Under development (unstable), Windows Server 2022 x64,
  x86_64-w64-mingw32 -- submitted 2026-09-05.

* GitHub Actions, `R CMD check --as-cran` (2026-09-05) -- Status: OK on each
  of:

  * Ubuntu 24.04.4 LTS, x86_64-pc-linux-gnu, R-devel (2026-09-04 r90492)
  * Ubuntu 24.04.4 LTS, x86_64-pc-linux-gnu, R 4.6.1 (2026-06-24)
  * Ubuntu 24.04.4 LTS, x86_64-pc-linux-gnu, R 4.5.3 (2026-03-11), oldrel-1
  * macOS Tahoe 26.6.2, aarch64-apple-darwin23, R 4.6.1 (2026-06-24)
  * Windows Server 2022 x64 (build 26100), x86_64-w64-mingw32,
    R 4.6.1 (2026-06-24 ucrt)

* R-hub v2, `R CMD check` (2026-09-05) -- Status: OK on each of:

  * macOS Sequoia 15.7.9, x86_64-apple-darwin20,
    R-devel (2026-09-04 r90492)
  * Ubuntu 22.04.5 LTS, x86_64-pc-linux-gnu, R-devel (2026-09-04 r90492),
    built without long doubles ('nold')
  * Fedora Linux 42, x86_64-pc-linux-gnu, R-devel (2026-06-21 r90185), with
    the suggested packages made unavailable ('nosuggests')

* Local, `R CMD check --as-cran` (2026-09-05) -- Status: 1 NOTE.
  Windows 11 x64 (build 26200), x86_64-w64-mingw32,
  R 4.6.0 (2026-04-24 ucrt).

## R CMD check results

Every GitHub Actions and R-hub platform above reports Status: OK -- 0 errors,
0 warnings, 0 notes. Both win-builder runs (R-release and R-devel) and the
local run report 0 errors | 0 warnings | 1 note.

<!-- TODO before sending: the win-builder runs of 2026-09-05 are still in the
     queue. Replace the two "submitted 2026-09-05" lines above with their R
     versions and Status once the result mails arrive, and confirm the note is
     the new-submission one. -->

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
and the test suite (testthat edition 3, 906 expectations across 10 files, none
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
plain 'data.table'. The latter also verifies that every argument a wrapper has
to read in order to describe the call -- `which=`, `with=`, the computed left
hand side of a `(cols) :=`, `merge()`'s `by=` and `all*=`, `na.omit()`'s
`invert=`, `set()`'s `j=`, `setorderv()`'s `cols=` and `setattr()`'s `name=` --
is evaluated exactly once, as often as 'data.table' evaluates it, so an
argument written as an expression with a side effect behaves the same with and
without 'dtlog'. This mirrors the approach taken by the 'tidylog' package,
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
