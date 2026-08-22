# First or last rows of a data table, with a log

First or last rows of a data table, with a log

## Usage

``` r
# S3 method for class 'data.table'
head(x, ...)

# S3 method for class 'data.table'
tail(x, ...)
```

## Arguments

- x:

  The data table.

- ...:

  All other arguments of \[utils::head()\] and \[utils::tail()\], i.e.
  \`n\`.

## Value

The same rows \`data.table\` would return.

## Examples

``` r
head(data.table::as.data.table(mtcars), 3)
#> head: removed 29 rows (91%), 3 rows remaining
#>      mpg   cyl  disp    hp  drat    wt  qsec    vs    am  gear  carb
#>    <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num>
#> 1:  21.0     6   160   110  3.90 2.620 16.46     0     1     4     4
#> 2:  21.0     6   160   110  3.90 2.875 17.02     0     1     4     4
#> 3:  22.8     4   108    93  3.85 2.320 18.61     1     1     4     1
```
