# Reshape a data table, with a log

Reports which columns were reorganized into which, and how the
dimensions of the table changed, in the style of \`tidylog\`'s
\`pivot_longer()\` and \`pivot_wider()\` messages.

## Usage

``` r
melt(data, ...)

# S3 method for class 'data.table'
melt(data, ...)

dcast(data, ...)

# S3 method for class 'data.table'
dcast(data, ...)
```

## Arguments

- data:

  The table to reshape.

- ...:

  All other arguments of \[data.table::melt.data.table()\] and
  \[data.table::dcast.data.table()\].

## Value

The reshaped data table.

## Examples

``` r
dt <- data.table::data.table(id = 1:2, a = 3:4, b = 5:6)
long <- data.table::melt(dt, id.vars = "id")
data.table::dcast(long, id ~ variable)
#> Key: <id>
#>       id     a     b
#>    <int> <int> <int>
#> 1:     1     3     5
#> 2:     2     4     6
```
