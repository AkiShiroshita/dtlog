# dtlog

`data.table` is fast and memory-efficient. It is particularly powerful
for large datasets.

However,`DT[i, j, by]` is terse. Reading a script rarely tells you how
many rows a filter dropped, which columns a `:=` added, or whether a
join matched anything.

`dtlog` prints that information. It is the same idea as
[tidylog](https://github.com/elbersb/tidylog), applied to `data.table`.
Nothing about the operations changes: dtlog only adds a message.

``` r

library(data.table)
library(dtlog)   # load after data.table

dt <- as.data.table(mtcars, keep.rownames = "car")

dt[mpg > 20]
#> filter: removed 18 rows (56%), 14 rows remaining

dt[order(-mpg)]
#> arrange: reordered 32 rows

dt[, .(car, mpg, cyl)]
#> select: dropped 9 variables (disp, hp, drat, wt, qsec, …)

dt[, kpl := mpg * 0.425]
#> mutate: new variable 'kpl' (double) with 25 unique values and 0% NA

dt[cyl == 4, mpg := NA]
#> mutate: changed 11 values (34%) of 'mpg' (11 new NAs)

dt[, kpl := NULL]
#> mutate: dropped one variable (kpl)

dt[, .(mean_mpg = mean(mpg, na.rm = TRUE)), by = cyl]
#> group_by: one grouping variable (cyl)
#> summarize: now 3 rows and 2 columns (was 32 rows and 12 columns)

labels <- data.table(cyl = c(4, 6), label = c("four", "six"))
dt[labels, on = "cyl"]
#> join (on cyl): added one column (label)
#>                rows: was 32, now 18 (-14)

merge(dt, labels, by = "cyl", all.x = TRUE)
#> left_join: added one column (label)
#>            > rows only in dt      14
#>            > rows only in labels ( 0)
#>            > matched rows         18
#>            >                     ====
#>            > rows total           32

setnames(dt, "mpg", "miles")
#> rename: renamed one variable (mpg -> miles)

setkey(dt, cyl)
#> setkey: keyed by (cyl), 32 rows sorted
```

## Installation

From CRAN:

``` r

install.packages("dtlog")
```

The development version from GitHub:

``` r

# install.packages("remotes")
remotes::install_github("AkiShiroshita/dtlog")
```

## Load order

dtlog redefines functions that `data.table` exports, so it has to come
last on the search path. Load it after `data.table`, or there will be no
output.

``` r

library(data.table)
library(dtlog)      # last
```

If you would rather resolve the conflicts explicitly, use the
[conflicted](https://github.com/r-lib/conflicted) package:

``` r

library(conflicted)
library(data.table)
library(dtlog)

conflict_prefer("melt", "dtlog")
conflict_prefer("setnames", "dtlog")
```

## What gets logged

| Call | Message |
|----|----|
| `DT[i, ...]` | `filter`, `arrange`, `which` |
| `DT[, j]` | `select`, `mutate`, `transmute`, `summarize` |
| `DT[, j, by = ]` | `group_by` and `summarize` |
| `DT[, x := ...]` | `mutate`: new columns, type conversions, how many values changed, `NA`s gained or lost |
| `DT[i, on = ]` | `join`: columns added and the change in rows |
| [`merge()`](https://rdrr.io/r/base/merge.html) | `inner_join` / `left_join` / `right_join` / `full_join`, with the matching counts |
| [`melt()`](https://akishiroshita.github.io/dtlog/reference/reshape.md), [`dcast()`](https://akishiroshita.github.io/dtlog/reference/reshape.md) | `reorganized (...) into (...) [was 32x12, now 352x3]`; columns that `measure.vars` left out are reported as dropped |
| [`unique()`](https://rdrr.io/r/base/unique.html), [`duplicated()`](https://rdrr.io/r/base/duplicated.html), [`na.omit()`](https://rdrr.io/r/stats/na.fail.html) | `distinct`, `duplicated`, `drop_na` |
| [`head()`](https://rdrr.io/r/utils/head.html), [`tail()`](https://rdrr.io/r/utils/head.html) | how many rows were dropped |
| [`rbindlist()`](https://akishiroshita.github.io/dtlog/reference/rows.md), [`funion()`](https://akishiroshita.github.io/dtlog/reference/rows.md), [`fintersect()`](https://akishiroshita.github.io/dtlog/reference/rows.md), [`fsetdiff()`](https://akishiroshita.github.io/dtlog/reference/rows.md) | how the row count changed |
| [`setnames()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md), [`setcolorder()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md) | `rename`, `relocate` |
| [`setkey()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md), [`setkeyv()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md), [`setorder()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md), [`setorderv()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md), [`setindex()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md), [`setindexv()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md) | keys, sort order, indices |
| [`set()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md), [`setDT()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md), [`setDF()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md), [`setattr()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md) | what was changed by reference |
| [`fread()`](https://akishiroshita.github.io/dtlog/reference/fread.md), [`fwrite()`](https://akishiroshita.github.io/dtlog/reference/fwrite.md) | rows, columns and the file name |
| [`as.data.table()`](https://akishiroshita.github.io/dtlog/reference/as.data.table.md) | the class it converted from and the resulting size |
| [`foverlaps()`](https://akishiroshita.github.io/dtlog/reference/foverlaps.md) | the rows that went in and came out, and the columns the interval join added |
| [`rollup()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md), [`cube()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md), [`groupingsets()`](https://akishiroshita.github.io/dtlog/reference/grouping_sets.md) | the size of the aggregate, once for the whole call rather than once per grouping set |
| [`split()`](https://rdrr.io/r/base/split.html) | how many tables the rows went into, and how many rows each of them holds |
| [`fsetequal()`](https://akishiroshita.github.io/dtlog/reference/rows.md) | whether the two tables hold the same rows |
| [`setnafill()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md) | how many `NA`s were filled, and how many are left |
| [`setdroplevels()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md) | which levels were dropped, and from which columns |
| [`copy()`](https://akishiroshita.github.io/dtlog/reference/copy.md) | that a deep copy was made, and how big it is |
| `dttable(DT)` | one row per column: its name, how many unique values it has, and the values themselves |

## Describing the variables of a table

[`dttable()`](https://akishiroshita.github.io/dtlog/reference/dttable.md)
describes a `data.table` rather than cross tabulating it. Each column
becomes one row – its name, how many unique values it holds, and the
values themselves – and the description is returned as a `data.table` so
it can be kept, written out or printed again. It is a function of its
own: `dtlog` does not mask
[`base::table()`](https://rdrr.io/r/base/table.html), and
[`table()`](https://rdrr.io/r/base/table.html) keeps working exactly as
it did.

``` r

dttable(dt)
#> dttable: 32 rows and 12 columns
#>         Variable N_unique                            Unique_value
#>              car       32 20+ unique values — possibly continuous
#>              mpg       25 20+ unique values — possibly continuous
#>              cyl        3                                 4; 6; 8
#>             disp       27 20+ unique values — possibly continuous
#>               hp       22 20+ unique values — possibly continuous
#>             drat       22 20+ unique values — possibly continuous
#>               wt       29 20+ unique values — possibly continuous
#>             qsec       30 20+ unique values — possibly continuous
#>               vs        2                                    0; 1
#>               am        2                                    0; 1
#>             gear        3                                 3; 4; 5
#>             carb        6                        1; 2; 3; 4; 6; 8
```

The values are listed in the order the column sorts in: numbers
ascending, characters alphabetically, dates and times chronologically,
factors by their levels. A column with 20 or more unique values is
reported as possibly continuous rather than listed, and a list of values
longer than 80 characters is truncated. Missing values are listed and
counted like any other value: `NA` (including `NA` as a level of a
factor) appears as `Missing`, `NaN` as `NaN`, and both are counted in
`N_unique`; an empty string is a value of its own, not a missing one.

``` r

dttable(dat)
#> dttable: 4 rows and 4 columns
#>         Variable N_unique                    Unique_value
#>              num        3                   1; 2; Missing
#>              chr        3                   a; b; Missing
#>              fac        3                no; yes; Missing
#>             date        3 2020-01-01; 2020-01-02; Missing
```

The description goes through the same output as every other message, so
[`dt_log()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
records it as well.

Only a single `data.table` triggers the description. Every other call is
passed straight on to
[`base::table()`](https://rdrr.io/r/base/table.html), so
[`dttable()`](https://akishiroshita.github.io/dtlog/reference/dttable.md)
can stand in for [`table()`](https://rdrr.io/r/base/table.html)
anywhere:

``` r

dttable(dt$cyl, dt$gear)       # the contingency table, as always
dttable(df$sex, df$death)      # a data.frame column is not a data.table either
dttable(as.data.frame(dt))     # and this is still base's cross tabulation
```

## Pipes

A `data.table` chain written with the native pipe logs the same way a
nested one does. `|>` is a syntax transformation, so `x |> f(y)` reaches
dtlog as an ordinary call to `f(x, y)`.

``` r

prostate2[rx == "0.2 mg estrogen"] |>
  _[, .(mean_age = mean(age, na.rm = TRUE),
        mean_wt  = mean(wt,  na.rm = TRUE)),
    by = rx]
#> filter: removed 10 rows (67%), 5 rows remaining
#> group_by: one grouping variable (rx)
#> summarize: now one row and 3 columns (was 5 rows and 3 columns)
```

The `_` placeholder on the left of `[` needs R \>= 4.3.0; `|>` itself
needs R \>= 4.1.0. Everything dtlog wraps works in a pipe, including the
`set*()` functions, which still change their input by reference:

``` r

DT |> _[mpg > 20] |> setorder(cyl)
#> filter: removed 18 rows (56%), 14 rows remaining
#> arrange: sorted 14 rows by (cyl)
```

The table on the left of the pipe is computed once, exactly as it is
without dtlog. magrittr’s `%>%` works too.

## Options

``` r

# where the output goes (message() by default)
options(dtlog.display = list(message, log4r_info))

# turn logging off
options(dtlog.display = list())

# turn it off for a while
dtlog_pause()
dtlog_resume()

# leave out the value level details ("full" by default)
options(dtlog.detail = "compact")

# also log data.table calls made inside other packages (FALSE by default)
options(dtlog.log_from_packages = TRUE)
```

`dtlog_summary(DT)` summarises a table and returns it unchanged, so you
can drop it into a chain:

``` r

dtlog_summary(dt)
#> dtlog: data.table with 32 rows and 12 columns
```

## Writing the session to a file

[`dt_log()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
opens a transcript and
[`dt_log_end()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
closes it. Between the two, every operation is appended to a text file
together with the call that produced it. Nothing is written before the
first call or after the second.

``` r

dt_log("session.txt")

dt <- as.data.table(mtcars, keep.rownames = "car")
dt[, kpl := mpg * 0.425]
by_cyl <- dt[, .(m = mean(mpg), n = .N), by = cyl]
joined <- merge(dt, labels, by = "cyl", all.x = TRUE)

dt_log_end()
#> dt_log: wrote 4 operations to 'session.txt'
```

    # dtlog transcript, started 2026-08-18 01:55:55
    # R version 4.3.3 (2024-02-29), data.table 1.18.4, dtlog 0.1.0
    > as.data.table(mtcars, keep.rownames = "car")
    as.data.table: converted data.frame to data.table (32 rows, 12 columns), added (car)

    > dt[, `:=`(kpl, mpg * 0.425)]
    mutate: new variable 'kpl' (double) with 25 unique values and 0% NA

    > dt[, .(m = mean(mpg), n = .N), by = cyl]
    group_by: one grouping variable (cyl)
    summarize: now 3 rows and 3 columns (was 32 rows and 13 columns)

    > merge(dt, labels, by = "cyl", all.x = TRUE)
    left_join: added one column (label)
               > rows only in dt       14
               > rows only in labels ( 0)
               > matched rows          18
               >                     ====
               > rows total            32

    # dtlog transcript, ended 2026-08-18 01:56:02 (4 operations)

| argument |  |
|----|----|
| `file` | where to write; there is no default.`dt_log(NULL)` is the same as [`dt_log_end()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md) |
| `append` | add to an existing file instead of overwriting it |
| `code` | `FALSE` writes the messages without the calls |
| `echo` | `FALSE` writes only to the file and leaves the console quiet |

[`dt_log_file()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
returns the path of the open transcript, or `NULL`. The file is flushed
after every operation, so it is readable while a long script runs, and a
session that ends without
[`dt_log_end()`](https://akishiroshita.github.io/dtlog/reference/dt_log.md)
still leaves a complete file – only the closing line is missing.

The call is written as R deparses it, which means
`dt[, kpl := mpg * 0.425]` comes back as
`` dt[, `:=`(kpl, mpg * 0.425)] ``. Both forms run.

## When i and j do different things

The number of rows in the result of `DT[i, j]` is not always the number
of rows `i` selected. Without `by=`, an aggregating `j` collapses the
result into a single row, so a result that is longer than that was
shaped by `i` and the two are reported one after the other. Where a
filter and an aggregation do meet, the row count is not blamed on `i`.

``` r

dt[mpg > 20, .(car, mpg)]        # j selects columns, so the rows come from i
#> filter: removed 18 rows (56%), 14 rows remaining
#> select: dropped 10 variables (cyl, disp, hp, drat, wt, …)

dt[mpg > 20, .(car, kpl = mpg * 0.425)]   # j computes one, the rows still come from i
#> filter: removed 18 rows (56%), 14 rows remaining
#> mutate: new variable 'kpl' (double) with 10 unique values and 0% NA
#>         dropped 11 variables (mpg, cyl, disp, hp, drat, …)

dt[mpg > 20, .(m = mean(mpg))]   # j aggregates
#> summarize: now one row and one column (was 32 rows and 12 columns, after filtering with i)

dt[mpg > 20, .N, by = cyl]
#> group_by: one grouping variable (cyl)
#> summarize: now 2 rows and 2 columns (was 32 rows and 12 columns, after filtering with i)
```

## Special variables

`.N`, `.SD`, `.SDcols` and `.GRP` are tools for writing `j`, so what
dtlog reports is the result of the call around them:

``` r

dt[, n := .N, by = cyl]
#> mutate (by cyl): new variable 'n' (integer) with 3 unique values and 0% NA

dt[, grp := .GRP, by = cyl]
#> mutate (by cyl): new variable 'grp' (integer) with 3 unique values and 0% NA

dt[, lag_mpg := shift(mpg)]
#> mutate: new variable 'lag_mpg' (double) with 25 unique values and 3% NA
```

## What is not logged

dtlog wraps the calls that take a table and hand back a different one,
or change it by reference. Three kinds of `data.table` function are
deliberately left alone.

**Functions that work on a vector.**
[`shift()`](https://rdrr.io/pkg/data.table/man/shift.html),
[`nafill()`](https://rdrr.io/pkg/data.table/man/nafill.html),
[`frank()`](https://rdrr.io/pkg/data.table/man/frank.html),
[`frankv()`](https://rdrr.io/pkg/data.table/man/frank.html),
[`rleid()`](https://rdrr.io/pkg/data.table/man/rleid.html),
[`rowid()`](https://rdrr.io/pkg/data.table/man/rowid.html),
[`fifelse()`](https://rdrr.io/pkg/data.table/man/fifelse.html),
[`fcase()`](https://rdrr.io/pkg/data.table/man/fcase.html),
[`between()`](https://rdrr.io/pkg/data.table/man/between.html),
[`uniqueN()`](https://rdrr.io/pkg/data.table/man/duplicated.html),
[`chmatch()`](https://rdrr.io/pkg/data.table/man/chmatch.html),
[`tstrsplit()`](https://rdrr.io/pkg/data.table/man/tstrsplit.html) and
[`fdroplevels()`](https://rdrr.io/pkg/data.table/man/fdroplevels.html)
are tools for writing `j`. They run once per group, so wrapping them
would print one message per group, and the `:=` or the aggregation
around them already says what came out:

``` r

dt[, lag_mpg := shift(mpg)]
#> mutate: new variable 'lag_mpg' (double) with 25 unique values and 3% NA

dt[, r := frank(mpg), by = cyl]
#> mutate (by cyl): new variable 'r' (double) with 18 unique values and 0% NA
```

[`setnafill()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
and
[`setdroplevels()`](https://akishiroshita.github.io/dtlog/reference/set_functions.md)
are wrapped although
[`nafill()`](https://rdrr.io/pkg/data.table/man/nafill.html) and
[`fdroplevels()`](https://rdrr.io/pkg/data.table/man/fdroplevels.html)
are not: they change a whole table by reference, which is the kind of
thing that is easy to miss.

**Functions with no before and after.**
[`data.table()`](https://rdrr.io/pkg/data.table/man/data.table.html),
[`CJ()`](https://rdrr.io/pkg/data.table/man/J.html) and
[`SJ()`](https://rdrr.io/pkg/data.table/man/J.html) build a table rather
than change one.
[`key()`](https://rdrr.io/pkg/data.table/man/setkey.html),
[`indices()`](https://rdrr.io/pkg/data.table/man/setkey.html),
[`haskey()`](https://rdrr.io/pkg/data.table/man/setkey.html),
[`tables()`](https://rdrr.io/pkg/data.table/man/tables.html),
[`address()`](https://rdrr.io/pkg/data.table/man/address.html) and
[`truelength()`](https://rdrr.io/pkg/data.table/man/truelength.html)
report on one without touching it.
[`setDTthreads()`](https://rdrr.io/pkg/data.table/man/openmp-utils.html)
and
[`setNumericRounding()`](https://rdrr.io/pkg/data.table/man/setNumericRounding.html)
are settings. There is nothing to compare.

**[`cbindlist()`](https://rdrr.io/pkg/data.table/man/cbindlist.html) and
[`mergelist()`](https://rdrr.io/pkg/data.table/man/mergelist.html)**,
which arrived in `data.table` 1.18.0. dtlog declares
`data.table (>= 1.16.0)`, the oldest version that has every function it
wraps, and wrapping these two would mean moving that floor forward by
more than a year for the sake of two functions. They are worth logging,
and will be wrapped when the floor rises on its own.

A call that is not logged is otherwise untouched: it is `data.table`’s
own function, and the operation around it reports as usual.

## Citation

``` r

citation("dtlog")
```

## License

MIT
