# dtlog 0.1.0

* First release.

* Logs `data.table` operations: the subsetting method `[.data.table` reports
  filters, sorts, column selection, modification by reference, grouping,
  aggregation and joins.

* Logs the exported `data.table` functions `merge()`, `unique()`,
  `duplicated()`, `na.omit()`, `head()`, `tail()`, `rbindlist()`, `melt()`,
  `dcast()`, `as.data.table()`, `fread()`, `fwrite()`, the `set*()` family and
  the set operations `funion()`, `fintersect()` and `fsetdiff()`.

* `dttable()` describes the variables of a single data table -- one row per
  column, with the number of unique values and the values themselves -- and
  passes every other call on to `base::table()` unchanged. It is a function of
  its own; `dtlog` does not mask `base::table()`.

* `dt_log()` and `dt_log_end()` write the messages to a transcript file,
  `dt_log_file()` reports where it is going, and `dtlog_summary()` reports the
  size and key of a table.

* `dtlog_pause()` and `dtlog_resume()` turn logging off and on. The options
  `dtlog.display`, `dtlog.detail`, `dtlog.log_from_packages` and
  `dtlog.table_max_unique` control where the output goes and how much of it
  there is.
