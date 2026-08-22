# Row operations with a log

These functions behave exactly like their \`data.table\` counterparts
and report how many rows they removed, kept or combined.

## Usage

``` r
# S3 method for class 'data.table'
unique(x, ...)

# S3 method for class 'data.table'
duplicated(x, ...)

# S3 method for class 'data.table'
na.omit(object, ...)

rbindlist(l, ...)

funion(x, y, ...)

fintersect(x, y, ...)

fsetdiff(x, y, ...)
```

## Arguments

- x, y, object, l:

  The inputs, as in the corresponding \`data.table\` function.

- ...:

  All other arguments, passed on unchanged.

## Value

Whatever the \`data.table\` function returns.

## Examples

``` r
dt <- data.table::data.table(a = c(1, 1, 2), b = c(NA, 2, 3))
unique(dt, by = "a")
#> distinct: removed one row (33%), 2 rows remaining
#>        a     b
#>    <num> <num>
#> 1:     1    NA
#> 2:     2     3
stats::na.omit(dt)
#> drop_na: removed one row (33%), 2 rows remaining
#>        a     b
#>    <num> <num>
#> 1:     1     2
#> 2:     2     3
```
