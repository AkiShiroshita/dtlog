# Log a summary of a data table

Prints the number of rows and columns of a data table, along with its
key, and returns the object unchanged, so that it can be used within a
chain of operations.

## Usage

``` r
dtlog_summary(.data)
```

## Arguments

- .data:

  A \`data.table\` (or any data frame).

## Value

\`.data\`, unchanged and returned visibly.

## See also

\[dt_log()\] to write a transcript of a whole session to a file.

## Examples

``` r
dt <- data.table::data.table(a = 1:3, b = 4:6)
dtlog_summary(dt)
#> dtlog: data.table with 3 rows and 2 columns
#>        a     b
#>    <int> <int>
#> 1:     1     4
#> 2:     2     5
#> 3:     3     6
```
