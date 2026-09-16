# dtlog 0.2.0

* Nine more `data.table` functions are logged. `foverlaps()` reports the rows
  that went into the interval join and the rows and columns that came out.
  `rollup()`, `cube()` and `groupingsets()` report the size of the aggregate.
  `split()` reports how many tables the rows went into and how many rows each
  of them holds. `fsetequal()` reports whether the two tables hold the same
  rows. `setnafill()` reports how many `NA`s it filled and how many are left,
  and `setdroplevels()` which levels it dropped from which columns. `copy()`
  reports that a deep copy was made, and how big it is.

* `rollup()`, `cube()` and `groupingsets()` run one `x[, j, by]` per grouping
  set, and `data.table` evaluates each of them in the frame the aggregation was
  called from -- which is the frame dtlog reads to decide whether a call is the
  user's. Those inner calls are now silenced while the aggregation runs, so one
  `rollup()` produces one line rather than one `group_by` and one `summarize`
  per set. Logging that was already paused stays paused.

* `Imports: data.table` moves from `>= 1.14.0` to `>= 1.16.0`. `setdroplevels()`
  was introduced in 1.16.0, and a package should not export a wrapper for a
  function its own dependency declaration says may not be there. Every other
  function dtlog wraps is older than 1.16.0, so that is the oldest version the
  package can honestly ask for.

* The README says which `data.table` functions are deliberately not logged, and
  why: the ones that work on a vector inside `j` and would print once per group
  (`shift()`, `frank()`, `nafill()`, `fcase()` and the rest), the ones with no
  before and after to compare (`data.table()`, `key()`, `setDTthreads()`), and
  `cbindlist()` and `mergelist()`, which need a newer `data.table` than the
  package declares.

# dtlog 0.1.1

* A logged function reached through another function that passes its own `...`
  on -- `rbindlist(lapply(files, fread))`, and anything else of that shape --
  no longer fails with "the ... list contains fewer than 1 element". Such a
  call arrives as `FUN(X[[i]], ...)`, where the `...` belongs to the frame that
  made the call and not to the `function(...)` a dtlog wrapper is declared as.
  dtlog now reads those dots in the frame that holds them. The arguments stay
  the promises of that frame, so an expression such as `sep = mysep` is still
  resolved where it was written, and nothing is evaluated a second time.

# dtlog 0.1.0

* First release.

* Logs `data.table` operations: the subsetting method `[.data.table` reports
  filters, sorts, column selection, modification by reference, grouping,
  aggregation and joins.

* Logs the exported `data.table` functions `merge()`, `unique()`,
  `duplicated()`, `na.omit()`, `head()`, `tail()`, `rbindlist()`, `melt()`,
  `dcast()`, `as.data.table()`, `fread()`, `fwrite()`, the `set*()` family and
  the set operations `funion()`, `fintersect()` and `fsetdiff()`.

* The operations are left untouched. Results, visibility, modification by
  reference, keys and indices are those of `data.table`, and every argument is
  evaluated exactly as often as `data.table` evaluates it: `dtlog` never
  computes an argument a second time in order to describe what a call did.

* `dttable()` describes the variables of a single data table -- one row per
  column, with the number of unique values and the values themselves -- and
  passes every other call on to `base::table()` unchanged. It is a function of
  its own; `dtlog` does not mask `base::table()`.

* `dt_log()` and `dt_log_end()` write the messages to a transcript file,
  `dt_log_file()` reports where it is going, and `dtlog_summary()` reports the
  size and key of a table. `dt_log()` has no default path: the transcript is
  written where you name it and nowhere else.

* `dtlog_pause()` and `dtlog_resume()` turn logging off and on. The options
  `dtlog.display`, `dtlog.detail`, `dtlog.log_from_packages` and
  `dtlog.table_max_unique` control where the output goes and how much of it
  there is.
