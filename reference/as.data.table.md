# Convert an object to a data table, with a log

Convert an object to a data table, with a log

## Usage

``` r
as.data.table(x, ...)
```

## Arguments

- x:

  The object to convert.

- ...:

  All other arguments of \[data.table::as.data.table()\].

## Value

The \`data.table\` that \[data.table::as.data.table()\] returns.

## Examples

``` r
data.table::as.data.table(head(mtcars, 3), keep.rownames = "car")
#>              car   mpg   cyl  disp    hp  drat    wt  qsec    vs    am  gear
#>           <char> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num>
#> 1:     Mazda RX4  21.0     6   160   110  3.90 2.620 16.46     0     1     4
#> 2: Mazda RX4 Wag  21.0     6   160   110  3.90 2.875 17.02     0     1     4
#> 3:    Datsun 710  22.8     4   108    93  3.85 2.320 18.61     1     1     4
#>     carb
#>    <num>
#> 1:     4
#> 2:     4
#> 3:     1
```
