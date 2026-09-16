# Copy a data table, with a log

`data.table` modifies by reference, and
[`data.table::copy()`](https://rdrr.io/pkg/data.table/man/copy.html) is
the way out of that: it is the point where a second, independent table
comes into existence. dtlog says so, and says how big the copy was.

## Usage

``` r
copy(x)
```

## Arguments

- x:

  The object to copy.

## Value

The deep copy that
[`data.table::copy()`](https://rdrr.io/pkg/data.table/man/copy.html)
returns.

## Examples

``` r
dt <- data.table::data.table(a = 1:3)
safe <- data.table::copy(dt)
```
