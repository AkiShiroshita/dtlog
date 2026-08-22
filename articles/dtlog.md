# Logging a data.table pipeline

`data.table` says very little about what it did. `DT[i, j, by]` returns
a table, and whether the filter dropped two rows or two thousand,
whether the join matched anything, whether `:=` overwrote a column you
meant to keep, is something you have to check yourself, one
[`nrow()`](https://rdrr.io/r/base/nrow.html) at a time.

`dtlog` prints it instead. It redefines `[.data.table` and the
`data.table` functions around it so that every operation reports what it
did, and leaves the operations themselves untouched – same return value,
same visibility, same modification by reference. It is the idea behind
[tidylog](https://github.com/elbersb/tidylog), applied to `data.table`.

This vignette follows one pipeline from a CSV file to a summary table,
reading the log as it goes, and then writes the whole session to a
transcript file. The README covers the reference material: the full list
of what is logged, the comparison with tidylog, and the timings.

## Loading

`dtlog` masks functions that `data.table` exports, so it has to come
after `data.table` on the search path. Load it last, or there will be no
output.

``` r

library(data.table)
library(dtlog)
```

By default `dtlog` only reports calls made from the global environment,
so `data.table` code inside other packages stays silent. Code in a
vignette is not run from the global environment either, so this vignette
sets `options(dtlog.log_from_packages = TRUE)` once, up front. In an
ordinary session you do not need it.

## The data

Two tables: repeated measurements, and one row per patient.

``` r

set.seed(42)

visits <- data.table(
  id    = rep(1:20, each = 3),
  visit = rep(1:3, times = 20),
  date  = as.Date("2026-01-01") + sample(0:180, 60, replace = TRUE),
  sbp   = round(rnorm(60, mean = 132, sd = 16)),
  crp   = round(rexp(60, rate = 1 / 8), 1)
)
visits[sample(60, 6), sbp := NA_real_]
#> mutate: changed 6 values (10%) of 'sbp' (6 new NAs)

patients <- data.table(
  id  = 1:20,
  sex = sample(c("F", "M"), 20, replace = TRUE),
  age = sample(45:85, 20, replace = TRUE),
  arm = rep(c("control", "treatment"), each = 10)
)
patients <- patients[id != 7]   # one patient never made it into the registry
#> filter: removed one row (5%), 19 rows remaining
```

[`data.table()`](https://rdrr.io/pkg/data.table/man/data.table.html)
itself is not wrapped, so building the two tables is silent; the `:=`
that writes the missing values and the filter that drops a patient are
not. Writing the patient table out and reading it back shows the file
end of things.

``` r

path <- tempfile(fileext = ".csv")
fwrite(patients, path)
#> fwrite: wrote 19 rows and 4 columns to 'file1a606c74319b.csv'
patients <- fread(path)
#> fread: read 19 rows and 4 columns from 'file1a606c74319b.csv'
```

[`fread()`](https://akishiroshita.github.io/dtlog/reference/fread.md)
reports what it read and from where,
[`fwrite()`](https://akishiroshita.github.io/dtlog/reference/fwrite.md)
what it wrote. Both messages name the file, which is the part that is
easy to get wrong in a script that builds paths.

## Cleaning

Everything below is ordinary `data.table` code. The `#>` lines are
`dtlog`.

``` r

visits <- na.omit(visits, cols = "sbp")
#> drop_na: removed 6 rows (10%), 54 rows remaining

visits[, high := sbp >= 140]
#> mutate: new variable 'high' (logical) with 2 unique values and 0% NA

visits[crp > 25, crp := NA_real_]
#> mutate: changed 6 values (11%) of 'crp' (6 new NAs)
```

Three messages worth reading closely:

- `drop_na` gives the rows removed and the rows left, so a `cols =`
  argument that matches nothing is visible immediately.
- the first `:=` is a new column: name, type, how many distinct values,
  how much of it is `NA`.
- the second `:=` writes into a column that already exists, so the
  message is about change – how many values moved, and how many `NA`s
  that created. A recode that silently hits far more rows than expected
  shows up here.

Dropping a column and renaming one are logged the same way:

``` r

visits[, high := NULL]
#> mutate: dropped one variable (high)

setnames(visits, "sbp", "sbp_mmhg")
#> rename: renamed one variable (sbp -> sbp_mmhg)
```

[`setnames()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
prints both names, `sbp -> sbp_mmhg`, so the log stays readable when
several renames happen in a row.

## Joining

``` r

merged <- merge(visits, patients, by = "id", all.x = TRUE)
#> left_join: added 3 columns (sex, age, arm)
#>            > rows only in visits      3
#>            > rows only in patients ( 0)
#>            > matched rows            51
#>            >                       ====
#>            > rows total              54
```

The join message has two halves: the columns that arrived, and the
matching counts. The counts are the useful half here – the
`rows only in visits` line is the patient who never made it into the
registry, three visits with no `arm` and no `age`. A left join keeps
them, the row count does not change, and without the log nothing about
the result says anything happened.

Now that the log has pointed at them, they can go:

``` r

merged <- merged[!is.na(arm)]
#> filter: removed 3 rows (6%), 51 rows remaining
```

The same join written as a `data.table` subset logs the columns and the
change in rows:

``` r

setkey(patients, id)
#> setkey: keyed by (id), 19 rows sorted
joined <- visits[patients, on = "id"]
#> join (on id): added 3 columns (sex, age, arm)
#>               rows: was 54, now 51 (-3)
```

[`setkey()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
reports the key it set and how many rows it sorted; the subset reports
the join.

## Reshaping and aggregating

``` r

wide <- dcast(merged, id + arm ~ visit, value.var = "sbp_mmhg")
#> dcast: reorganized (visit, date, sbp_mmhg, crp, sex, …) into (1, 2, 3) [was 51x8, now 19x5]
```

[`dcast()`](https://akishiroshita.github.io/dtlog/reference/reshape.md)
reports the shape before and after, which is where a reshape usually
goes wrong: an unexpected row count means the left hand side of the
formula does not identify a row.

Aggregation is logged in two lines, the grouping and the result:

``` r

by_arm <- merged[, .(n        = .N,
                     patients = uniqueN(id),
                     mean_sbp = mean(sbp_mmhg),
                     mean_crp = mean(crp, na.rm = TRUE)),
                 by = arm]
#> group_by: one grouping variable (arm)
#> summarize: now 2 rows and 5 columns (was 51 rows and 8 columns)
by_arm
#>          arm     n patients mean_sbp mean_crp
#>       <char> <int>    <int>    <num>    <num>
#> 1:   control    25        9 130.5600 6.791667
#> 2: treatment    26       10 127.9231 8.209091
```

`dtlog` distinguishes the rows `i` selects from the rows `j` produces.
When `j` aggregates, the row count is not blamed on the filter:

``` r

merged[age >= 65, .(mean_sbp = mean(sbp_mmhg)), by = arm]
#> group_by: one grouping variable (arm)
#> summarize: now 2 rows and 2 columns (was 51 rows and 8 columns, after filtering with i)
#>          arm mean_sbp
#>       <char>    <num>
#> 1:   control 129.9091
#> 2: treatment 126.5625
```

The same holds in a pipe. `x |> f(y)` reaches `dtlog` as an ordinary
call to `f(x, y)`, so a piped chain logs exactly like a nested one:

``` r

merged[arm == "treatment"] |>
  _[, .(mean_crp = mean(crp, na.rm = TRUE)), by = sex]
#> filter: removed 25 rows (49%), 26 rows remaining
#> group_by: one grouping variable (sex)
#> summarize: now 2 rows and 2 columns (was 26 rows and 8 columns)
#>       sex mean_crp
#>    <char>    <num>
#> 1:      M 8.361538
#> 2:      F 7.988889
```

## Writing the session to a file

[`dt_log()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
opens a transcript. From that point on every operation is appended to a
text file together with the call that produced it, and
[`dt_log_end()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
closes it. This is the part that is hard to reproduce by hand: a record
of what a script actually did to the data, next to the code that did it.

``` r

log_path <- tempfile(fileext = ".txt")
dt_log(log_path)

final <- merged[!is.na(crp)]
#> filter: removed 5 rows (10%), 46 rows remaining
final[, crp_log := log(crp)]
#> mutate: new variable 'crp_log' (double) with 40 unique values and 0% NA
summary_tbl <- final[, .(n = .N, mean_crp_log = mean(crp_log)), by = .(arm, sex)]
#> group_by: 2 grouping variables (arm, sex)
#> summarize: now 4 rows and 4 columns (was 46 rows and 9 columns)

dt_log_end()
#> dt_log: wrote 3 operations to '/tmp/RtmppHTTwj/file1a602d4e7430.txt'
```

The file holds the calls as R deparses them, with their messages
underneath:

``` r
cat(readLines(log_path), sep = "\n")
# dtlog transcript, started 2026-08-22 10:32:14
# R version 4.6.1 (2026-06-24), data.table 1.18.4, dtlog 0.1.0
> merged[!is.na(crp)]
filter: removed 5 rows (10%), 46 rows remaining

> final[, `:=`(crp_log, log(crp))]
mutate: new variable 'crp_log' (double) with 40 unique values and 0% NA

> final[, .(n = .N, mean_crp_log = mean(crp_log)), by = .(arm, sex)]
group_by: 2 grouping variables (arm, sex)
summarize: now 4 rows and 4 columns (was 46 rows and 9 columns)

# dtlog transcript, ended 2026-08-22 10:32:14 (3 operations)
```

`dt_log(append = TRUE)` adds to an existing file, `code = FALSE` writes
the messages without the calls, and `echo = FALSE` writes only to the
file and leaves the console quiet.
[`dt_log_file()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
returns the path of the open transcript, or `NULL`:

``` r

dt_log_file()
#> NULL
```

The file is flushed after every operation, so it is readable while a
long script is still running, and a session that ends without
[`dt_log_end()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
still leaves a complete file – only the closing line is missing.

## Turning the volume down

A long pipeline in a loop does not need a message per iteration.
[`dtlog_pause()`](https://akishiroshita.github.io/dtlog/reference/dtlog_pause.md)
and
[`dtlog_resume()`](https://akishiroshita.github.io/dtlog/reference/dtlog_pause.md)
bracket a block of code:

``` r

dtlog_pause()
for (i in 1:3) merged[, tmp := i]
dtlog_resume()

merged[, tmp := NULL]
#> mutate: dropped one variable (tmp)
```

`options(dtlog.detail = "compact")` keeps the messages but drops the
value-level detail – types, unique values, share of `NA`, number of
values changed. It is also the setting that never copies data, so a `:=`
on a large table costs nothing:

``` r

options(dtlog.detail = "compact")
merged[, crp_high := crp > 10]
#> mutate: new variable 'crp_high' (logical)
options(dtlog.detail = "full")
```

`options(dtlog.display = ...)` decides where the output goes. The
default is [`message()`](https://rdrr.io/r/base/message.html); a list of
functions sends each message to all of them, and an empty list turns
logging off without unloading the package:

``` r

options(dtlog.display = list(function(x) cat("LOG |", x, "\n")))
elderly <- merged[age >= 70]
#> LOG | filter: removed 29 rows (57%), 22 rows remaining

options(dtlog.display = NULL)  # back to message()
```

Finally,
[`dtlog_summary()`](https://akishiroshita.github.io/dtlog/reference/dtlog_summary.md)
describes a table and returns it unchanged, so it can sit in the middle
of a chain:

``` r

dtlog_summary(merged)[1:2, .(id, arm)]
#> dtlog: data.table with 51 rows and 9 columns, keyed by (id)
#> filter: removed 49 rows (96%), 2 rows remaining
#> select: dropped 7 variables (visit, date, sbp_mmhg, crp, sex, …)
#> Key: <id>
#>       id     arm
#>    <int>  <char>
#> 1:     1 control
#> 2:     1 control
```

## What does not change

`dtlog` re-evaluates the call you wrote, unchanged, in the frame you
wrote it in. Return values and visibility are the same, `:=` and the
`set*()` functions still modify by reference, non-standard evaluation
still works, and
[`setDT()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
still converts a variable in the caller. The package’s parity tests run
more than a hundred `data.table` idioms twice – once through `dtlog`,
once through `data.table` – and compare the value, its visibility and
the state of the inputs.
