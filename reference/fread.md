# Read a file into a data table, with a log

Read a file into a data table, with a log

## Usage

``` r
fread(...)
```

## Arguments

- ...:

  All arguments of \[data.table::fread()\].

## Value

The data table that \[data.table::fread()\] returns.

## Examples

``` r
fread(text = "a,b\n1,2\n3,4")
#> fread: read 2 rows and 2 columns
#>        a     b
#>    <int> <int>
#> 1:     1     2
#> 2:     3     4
```
