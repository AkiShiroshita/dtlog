# Changelog

## dtlog 0.2.0

- Nine more `data.table` functions are logged.
  [`foverlaps()`](https://akishiroshita.github.io/dtlog/reference/foverlaps.md)
  reports the rows that went into the interval join and the rows and
  columns that came out.
  [`rollup()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md),
  [`cube()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md)
  and
  [`groupingsets()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md)
  report the size of the aggregate.
  [`split()`](https://rdrr.io/r/base/split.html) reports how many tables
  the rows went into and how many rows each of them holds.
  [`fsetequal()`](https://akishiroshita.github.io/dtlog/reference/rows.md)
  reports whether the two tables hold the same rows.
  [`setnafill()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  reports how many `NA`s it filled and how many are left, and
  [`setdroplevels()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  which levels it dropped from which columns.
  [`copy()`](https://akishiroshita.github.io/dtlog/reference/copy.md)
  reports that a deep copy was made, and how big it is.

- [`rollup()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md),
  [`cube()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md)
  and
  [`groupingsets()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md)
  run one `x[, j, by]` per grouping set, and `data.table` evaluates each
  of them in the frame the aggregation was called from – which is the
  frame dtlog reads to decide whether a call is the user’s. Those inner
  calls are now silenced while the aggregation runs, so one
  [`rollup()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md)
  produces one line rather than one `group_by` and one `summarize` per
  set. Logging that was already paused stays paused.

- `Imports: data.table` moves from `>= 1.14.0` to `>= 1.16.0`.
  [`setdroplevels()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  was introduced in 1.16.0, and a package should not export a wrapper
  for a function its own dependency declaration says may not be there.
  Every other function dtlog wraps is older than 1.16.0, so that is the
  oldest version the package can honestly ask for.

- The README says which `data.table` functions are deliberately not
  logged, and why: the ones that work on a vector inside `j` and would
  print once per group
  ([`shift()`](https://rdrr.io/pkg/data.table/man/shift.html),
  [`frank()`](https://rdrr.io/pkg/data.table/man/frank.html),
  [`nafill()`](https://rdrr.io/pkg/data.table/man/nafill.html),
  [`fcase()`](https://rdrr.io/pkg/data.table/man/fcase.html) and the
  rest), the ones with no before and after to compare
  ([`data.table()`](https://rdrr.io/pkg/data.table/man/data.table.html),
  [`key()`](https://rdrr.io/pkg/data.table/man/setkey.html),
  [`setDTthreads()`](https://rdrr.io/pkg/data.table/man/openmp-utils.html)),
  and [`cbindlist()`](https://rdrr.io/pkg/data.table/man/cbindlist.html)
  and
  [`mergelist()`](https://rdrr.io/pkg/data.table/man/mergelist.html),
  which need a newer `data.table` than the package declares.

## dtlog 0.1.1

- A logged function reached through another function that passes its own
  `...` on – `rbindlist(lapply(files, fread))`, and anything else of
  that shape – no longer fails with “the … list contains fewer than 1
  element”. Such a call arrives as `FUN(X[[i]], ...)`, where the `...`
  belongs to the frame that made the call and not to the `function(...)`
  a dtlog wrapper is declared as. dtlog now reads those dots in the
  frame that holds them. The arguments stay the promises of that frame,
  so an expression such as `sep = mysep` is still resolved where it was
  written, and nothing is evaluated a second time.

## dtlog 0.1.0

CRAN release: 2026-09-15

- First release.

- Logs `data.table` operations: the subsetting method `[.data.table`
  reports filters, sorts, column selection, modification by reference,
  grouping, aggregation and joins.

- Logs the exported `data.table` functions
  [`merge()`](https://rdrr.io/r/base/merge.html),
  [`unique()`](https://rdrr.io/r/base/unique.html),
  [`duplicated()`](https://rdrr.io/r/base/duplicated.html),
  [`na.omit()`](https://rdrr.io/r/stats/na.fail.html),
  [`head()`](https://rdrr.io/r/utils/head.html),
  [`tail()`](https://rdrr.io/r/utils/head.html),
  [`rbindlist()`](https://akishiroshita.github.io/dtlog/reference/rows.md),
  [`melt()`](https://akishiroshita.github.io/dtlog/reference/reshape.md),
  [`dcast()`](https://akishiroshita.github.io/dtlog/reference/reshape.md),
  [`as.data.table()`](https://akishiroshita.github.io/dtlog/reference/as.data.table.md),
  [`fread()`](https://akishiroshita.github.io/dtlog/reference/fread.md),
  [`fwrite()`](https://akishiroshita.github.io/dtlog/reference/fwrite.md),
  the `set*()` family and the set operations
  [`funion()`](https://akishiroshita.github.io/dtlog/reference/rows.md),
  [`fintersect()`](https://akishiroshita.github.io/dtlog/reference/rows.md)
  and
  [`fsetdiff()`](https://akishiroshita.github.io/dtlog/reference/rows.md).

- The operations are left untouched. Results, visibility, modification
  by reference, keys and indices are those of `data.table`, and every
  argument is evaluated exactly as often as `data.table` evaluates it:
  `dtlog` never computes an argument a second time in order to describe
  what a call did.

- [`dttable()`](https://akishiroshita.github.io/dtlog/reference/dttable.md)
  describes the variables of a single data table – one row per column,
  with the number of unique values and the values themselves – and
  passes every other call on to
  [`base::table()`](https://rdrr.io/r/base/table.html) unchanged. It is
  a function of its own; `dtlog` does not mask
  [`base::table()`](https://rdrr.io/r/base/table.html).

- [`dt_log()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
  and
  [`dt_log_end()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
  write the messages to a transcript file,
  [`dt_log_file()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
  reports where it is going, and
  [`dtlog_summary()`](https://akishiroshita.github.io/dtlog/reference/dtlog_summary.md)
  reports the size and key of a table.
  [`dt_log()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
  has no default path: the transcript is written where you name it and
  nowhere else.

- [`dtlog_pause()`](https://akishiroshita.github.io/dtlog/reference/dtlog_pause.md)
  and
  [`dtlog_resume()`](https://akishiroshita.github.io/dtlog/reference/dtlog_pause.md)
  turn logging off and on. The options `dtlog.display`, `dtlog.detail`,
  `dtlog.log_from_packages` and `dtlog.table_max_unique` control where
  the output goes and how much of it there is.
