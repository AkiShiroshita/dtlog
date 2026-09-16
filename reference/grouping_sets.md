# Aggregate over several grouping sets, with a log

[`data.table::rollup()`](https://rdrr.io/pkg/data.table/man/groupingsets.html),
[`data.table::cube()`](https://rdrr.io/pkg/data.table/man/groupingsets.html)
and
[`data.table::groupingsets()`](https://rdrr.io/pkg/data.table/man/groupingsets.html)
run one aggregation per grouping set and stack the results. Each reports
the size of the table it produced next to the size of the table it
started from, in the wording an aggregating `j` uses.

## Usage

``` r
rollup(x, ...)

cube(x, ...)

groupingsets(x, ...)
```

## Arguments

- x:

  The data table to aggregate.

- ...:

  All other arguments, as in the corresponding `data.table` function.

## Value

Whatever the `data.table` function returns.

## Examples

``` r
dt <- data.table::data.table(g = c("a", "a", "b"), h = c("x", "y", "x"),
                             v = 1:3)
data.table::rollup(dt, j = sum(v), by = c("g", "h"))
#> group_by: 2 grouping variables (g, h)
#> summarize: now 0 rows and 3 columns (was 3 rows and 3 columns, after filtering with i)
#> group_by: 2 grouping variables (g, h)
#> summarize: now 3 rows and 3 columns (was 3 rows and 3 columns)
#> group_by: one grouping variable (g)
#> summarize: now 2 rows and 2 columns (was 3 rows and 3 columns)
#> group_by: 0 grouping variables ()
#> summarize: now one row and one column (was 3 rows and 3 columns)
#>         g      h    V1
#>    <char> <char> <int>
#> 1:      a      x     1
#> 2:      a      y     2
#> 3:      b      x     3
#> 4:      a   <NA>     3
#> 5:      b   <NA>     3
#> 6:   <NA>   <NA>     6
data.table::cube(dt, j = sum(v), by = c("g", "h"))
#> group_by: 2 grouping variables (g, h)
#> summarize: now 0 rows and 3 columns (was 3 rows and 3 columns, after filtering with i)
#> group_by: 2 grouping variables (g, h)
#> summarize: now 3 rows and 3 columns (was 3 rows and 3 columns)
#> group_by: one grouping variable (g)
#> summarize: now 2 rows and 2 columns (was 3 rows and 3 columns)
#> group_by: one grouping variable (h)
#> summarize: now 2 rows and 2 columns (was 3 rows and 3 columns)
#> group_by: 0 grouping variables ()
#> summarize: now one row and one column (was 3 rows and 3 columns)
#>         g      h    V1
#>    <char> <char> <int>
#> 1:      a      x     1
#> 2:      a      y     2
#> 3:      b      x     3
#> 4:      a   <NA>     3
#> 5:      b   <NA>     3
#> 6:   <NA>      x     4
#> 7:   <NA>      y     2
#> 8:   <NA>   <NA>     6
```
