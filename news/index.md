# Changelog

## dtlog 0.1.0

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

- [`dtlog_pause()`](https://akishiroshita.github.io/dtlog/reference/dtlog_pause.md)
  and
  [`dtlog_resume()`](https://akishiroshita.github.io/dtlog/reference/dtlog_pause.md)
  turn logging off and on. The options `dtlog.display`, `dtlog.detail`,
  `dtlog.log_from_packages` and `dtlog.table_max_unique` control where
  the output goes and how much of it there is.
