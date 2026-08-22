# Write a data table to a file, with a log

Write a data table to a file, with a log

## Usage

``` r
fwrite(x, ...)
```

## Arguments

- x:

  The table to write.

- ...:

  All other arguments of \[data.table::fwrite()\].

## Value

\`NULL\`, invisibly, as \[data.table::fwrite()\] returns it.

## Examples

``` r
dt <- data.table::data.table(a = 1:2, b = 3:4)
fwrite(dt, tempfile())
#> fwrite: wrote 2 rows and 2 columns to 'file18d62f4a8ee9'
```
