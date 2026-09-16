# Join two data tables on overlapping intervals, with a log

Reports how many rows went in and came out, and which columns the join
added. `foverlaps()` matches a row of `x` against every row of `y` whose
interval overlaps it, so the result can be longer as well as shorter
than `x`, and the row count is the part worth seeing.

## Usage

``` r
foverlaps(x, y, ...)
```

## Arguments

- x, y:

  The data tables to join. Both carry the interval as two columns, and
  `y` has to be keyed on them.

- ...:

  All other arguments of
  [`data.table::foverlaps()`](https://rdrr.io/pkg/data.table/man/foverlaps.html).

## Value

Whatever
[`data.table::foverlaps()`](https://rdrr.io/pkg/data.table/man/foverlaps.html)
returns: the matched rows, or, with `which = TRUE`, the row numbers that
matched.

## Examples

``` r
x <- data.table::data.table(s = c(1, 5), e = c(3, 7))
y <- data.table::data.table(s = c(2, 6), e = c(4, 8))
data.table::setkey(y, s, e)
data.table::foverlaps(x, y)
#>        s     e   i.s   i.e
#>    <num> <num> <num> <num>
#> 1:     2     4     1     3
#> 2:     6     8     5     7
```
