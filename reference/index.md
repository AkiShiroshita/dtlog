# Package index

## Logged subsetting

The method every `DT[i, j, by]` call goes through.

- [`` `[`( ``*`<data.table>`*`)`](https://akishiroshita.github.io/dtlog/reference/sub-.data.table.md)
  : Subset, aggregate and update a data.table, with a log

## Logged ‘data.table’ functions

Wrappers around the functions ‘data.table’ exports. Each one prints a
message and then dispatches to the ‘data.table’ implementation.

- [`as.data.table()`](https://akishiroshita.github.io/dtlog/reference/as.data.table.md)
  : Convert an object to a data table, with a log
- [`merge(`*`<data.table>`*`)`](https://akishiroshita.github.io/dtlog/reference/merge.data.table.md)
  : Merge two data tables, with a log
- [`melt()`](https://akishiroshita.github.io/dtlog/reference/reshape.md)
  [`dcast()`](https://akishiroshita.github.io/dtlog/reference/reshape.md)
  : Reshape a data table, with a log
- [`unique(`*`<data.table>`*`)`](https://akishiroshita.github.io/dtlog/reference/rows.md)
  [`duplicated(`*`<data.table>`*`)`](https://akishiroshita.github.io/dtlog/reference/rows.md)
  [`na.omit(`*`<data.table>`*`)`](https://akishiroshita.github.io/dtlog/reference/rows.md)
  [`rbindlist()`](https://akishiroshita.github.io/dtlog/reference/rows.md)
  [`funion()`](https://akishiroshita.github.io/dtlog/reference/rows.md)
  [`fintersect()`](https://akishiroshita.github.io/dtlog/reference/rows.md)
  [`fsetdiff()`](https://akishiroshita.github.io/dtlog/reference/rows.md)
  : Row operations with a log
- [`setnames()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setcolorder()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setkey()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setkeyv()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setorder()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setorderv()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setindex()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setindexv()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`set()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setDT()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setDF()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  [`setattr()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
  : Modify a data table by reference, with a log
- [`head(`*`<data.table>`*`)`](https://akishiroshita.github.io/dtlog/reference/head_tail.md)
  [`tail(`*`<data.table>`*`)`](https://akishiroshita.github.io/dtlog/reference/head_tail.md)
  : First or last rows of a data table, with a log
- [`fread()`](https://akishiroshita.github.io/dtlog/reference/fread.md)
  : Read a file into a data table, with a log
- [`fwrite()`](https://akishiroshita.github.io/dtlog/reference/fwrite.md)
  : Write a data table to a file, with a log

## Describing a table

- [`dttable()`](https://akishiroshita.github.io/dtlog/reference/dttable.md)
  : Describe the variables of a data table
- [`dtlog_summary()`](https://akishiroshita.github.io/dtlog/reference/dtlog_summary.md)
  : Log a summary of a data table

## Transcripts and control

- [`dt_log()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
  [`dt_log_end()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
  [`dt_log_file()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
  : Write the code and its log to a text file
- [`dtlog_pause()`](https://akishiroshita.github.io/dtlog/reference/dtlog_pause.md)
  [`dtlog_resume()`](https://akishiroshita.github.io/dtlog/reference/dtlog_pause.md)
  : Pause and resume logging

## Package

- [`dtlog`](https://akishiroshita.github.io/dtlog/reference/dtlog-package.md)
  [`dtlog-package`](https://akishiroshita.github.io/dtlog/reference/dtlog-package.md)
  : dtlog: logging for data.table operations
