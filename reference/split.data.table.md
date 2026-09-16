# Split a data table, with a log

Reports how many tables the rows were split into, and how many rows each
of them holds.

## Usage

``` r
# S3 method for class 'data.table'
split(x, f, drop = FALSE, ...)
```

## Arguments

- x:

  The data table to split.

- f:

  The grouping factor, as in
  [`base::split()`](https://rdrr.io/r/base/split.html). `data.table`'s
  own `by=` is the usual way to give it instead.

- drop:

  Whether to drop unused levels, as in
  [`base::split()`](https://rdrr.io/r/base/split.html).

- ...:

  All other arguments of `data.table`'s
  [`split()`](https://rdrr.io/r/base/split.html) method, i.e. `by`,
  `sorted`, `keep.by` and `flatten`.

## Value

The list of data tables that `data.table` returns.

## Examples

``` r
dt <- data.table::data.table(g = c("a", "a", "b"), v = 1:3)
split(dt, by = "g")
#> split: 3 rows into 2 tables (a: 2 rows, b: one row)
#> $a
#>         g     v
#>    <char> <int>
#> 1:      a     1
#> 2:      a     2
#> 
#> $b
#>         g     v
#>    <char> <int>
#> 1:      b     3
#> 
```
