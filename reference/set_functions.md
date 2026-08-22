# Modify a data table by reference, with a log

These functions are the \`data.table\` \`set\*()\` functions. They still
change their input by reference and return exactly what \`data.table\`
returns; they only report what they changed.

## Usage

``` r
setnames(x, ...)

setcolorder(x, ...)

setkey(x, ...)

setkeyv(x, ...)

setorder(x, ...)

setorderv(x, ...)

setindex(x, ...)

setindexv(x, ...)

set(x, ...)

setDT(x, ...)

setDF(x, ...)

setattr(x, ...)
```

## Arguments

- x:

  The data table (or, for \[setDT()\], the object to convert).

- ...:

  All other arguments, passed on unchanged.

## Value

Whatever the corresponding \`data.table\` function returns.

## Examples

``` r
dt <- data.table::data.table(a = 3:1, b = 1:3)
data.table::setnames(dt, "a", "alpha")
data.table::setkey(dt, alpha)
```
