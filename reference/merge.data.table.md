# Merge two data tables, with a log

Reports the columns the merge added and how the rows of the two inputs
were matched, in the style of \`tidylog\`'s join messages. The counts of
unmatched rows are only computed when \`options(dtlog.detail = "full")\`
(the default); they cost two additional matching passes over the inputs.

## Usage

``` r
# S3 method for class 'data.table'
merge(x, y, ...)
```

## Arguments

- x, y:

  The data tables to merge.

- ...:

  All other arguments of \[data.table::merge.data.table()\].

## Value

The merged data table, exactly as \[data.table::merge.data.table()\]
returns it.

## Examples

``` r
a <- data.table::data.table(id = 1:3, v = 1:3)
b <- data.table::data.table(id = 2:4, w = 4:6)
merge(a, b, by = "id")
#> inner_join: added one column (w)
#>             > rows only in a (1)
#>             > rows only in b (1)
#>             > matched rows     2
#>             >                ===
#>             > rows total       2
#> Key: <id>
#>       id     v     w
#>    <int> <int> <int>
#> 1:     2     2     4
#> 2:     3     3     5
```
