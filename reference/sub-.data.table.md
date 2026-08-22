# Subset, aggregate and update a data.table, with a log

\`dtlog\` redefines the \`\[\` method for data tables. The call is
passed on to \`data.table\` unchanged – same arguments, same evaluation
environment, same return value, same modification by reference – and a
message describing what happened is printed afterwards.

## Usage

``` r
# S3 method for class 'data.table'
x[...]
```

## Arguments

- x:

  A \`data.table\`.

- ...:

  All other arguments of \`\[.data.table\`, i.e. \`i\`, \`j\`, \`by\`,
  \`keyby\`, \`with\`, \`nomatch\`, \`mult\`, \`roll\`, \`rollends\`,
  \`which\`, \`.SDcols\`, \`verbose\`, \`allow.cartesian\`, \`drop\`,
  \`on\`, \`env\` and \`showProgress\`. They are never touched by
  \`dtlog\`.

## Value

Whatever \`data.table\`'s \`\[\` returns, with the same visibility.

## Details

Depending on the call, the message uses the vocabulary of \`tidylog\`:
\`filter\` (rows removed by \`i\`), \`arrange\` (rows reordered),
\`join\` (\`i\` is a table or \`on=\` was given), \`select\` (\`j\` only
picks existing columns), \`mutate\` (\`:=\`), \`group_by\`/\`summarize\`
(\`by=\`/\`keyby=\`).

## Examples

``` r
dt <- data.table::as.data.table(mtcars)
dt[mpg > 20]
#> filter: removed 18 rows (56%), 14 rows remaining
#>       mpg   cyl  disp    hp  drat    wt  qsec    vs    am  gear  carb
#>     <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num>
#>  1:  21.0     6 160.0   110  3.90 2.620 16.46     0     1     4     4
#>  2:  21.0     6 160.0   110  3.90 2.875 17.02     0     1     4     4
#>  3:  22.8     4 108.0    93  3.85 2.320 18.61     1     1     4     1
#>  4:  21.4     6 258.0   110  3.08 3.215 19.44     1     0     3     1
#>  5:  24.4     4 146.7    62  3.69 3.190 20.00     1     0     4     2
#>  6:  22.8     4 140.8    95  3.92 3.150 22.90     1     0     4     2
#>  7:  32.4     4  78.7    66  4.08 2.200 19.47     1     1     4     1
#>  8:  30.4     4  75.7    52  4.93 1.615 18.52     1     1     4     2
#>  9:  33.9     4  71.1    65  4.22 1.835 19.90     1     1     4     1
#> 10:  21.5     4 120.1    97  3.70 2.465 20.01     1     0     3     1
#> 11:  27.3     4  79.0    66  4.08 1.935 18.90     1     1     4     1
#> 12:  26.0     4 120.3    91  4.43 2.140 16.70     0     1     5     2
#> 13:  30.4     4  95.1   113  3.77 1.513 16.90     1     1     5     2
#> 14:  21.4     4 121.0   109  4.11 2.780 18.60     1     1     4     2
dt[, mpg_per_cyl := mpg / cyl]
#> mutate: new variable 'mpg_per_cyl' (double) with 27 unique values and 0% NA
#>       mpg   cyl  disp    hp  drat    wt  qsec    vs    am  gear  carb
#>     <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num>
#>  1:  21.0     6 160.0   110  3.90 2.620 16.46     0     1     4     4
#>  2:  21.0     6 160.0   110  3.90 2.875 17.02     0     1     4     4
#>  3:  22.8     4 108.0    93  3.85 2.320 18.61     1     1     4     1
#>  4:  21.4     6 258.0   110  3.08 3.215 19.44     1     0     3     1
#>  5:  18.7     8 360.0   175  3.15 3.440 17.02     0     0     3     2
#>  6:  18.1     6 225.0   105  2.76 3.460 20.22     1     0     3     1
#>  7:  14.3     8 360.0   245  3.21 3.570 15.84     0     0     3     4
#>  8:  24.4     4 146.7    62  3.69 3.190 20.00     1     0     4     2
#>  9:  22.8     4 140.8    95  3.92 3.150 22.90     1     0     4     2
#> 10:  19.2     6 167.6   123  3.92 3.440 18.30     1     0     4     4
#> 11:  17.8     6 167.6   123  3.92 3.440 18.90     1     0     4     4
#> 12:  16.4     8 275.8   180  3.07 4.070 17.40     0     0     3     3
#> 13:  17.3     8 275.8   180  3.07 3.730 17.60     0     0     3     3
#> 14:  15.2     8 275.8   180  3.07 3.780 18.00     0     0     3     3
#> 15:  10.4     8 472.0   205  2.93 5.250 17.98     0     0     3     4
#> 16:  10.4     8 460.0   215  3.00 5.424 17.82     0     0     3     4
#> 17:  14.7     8 440.0   230  3.23 5.345 17.42     0     0     3     4
#> 18:  32.4     4  78.7    66  4.08 2.200 19.47     1     1     4     1
#> 19:  30.4     4  75.7    52  4.93 1.615 18.52     1     1     4     2
#> 20:  33.9     4  71.1    65  4.22 1.835 19.90     1     1     4     1
#> 21:  21.5     4 120.1    97  3.70 2.465 20.01     1     0     3     1
#> 22:  15.5     8 318.0   150  2.76 3.520 16.87     0     0     3     2
#> 23:  15.2     8 304.0   150  3.15 3.435 17.30     0     0     3     2
#> 24:  13.3     8 350.0   245  3.73 3.840 15.41     0     0     3     4
#> 25:  19.2     8 400.0   175  3.08 3.845 17.05     0     0     3     2
#> 26:  27.3     4  79.0    66  4.08 1.935 18.90     1     1     4     1
#> 27:  26.0     4 120.3    91  4.43 2.140 16.70     0     1     5     2
#> 28:  30.4     4  95.1   113  3.77 1.513 16.90     1     1     5     2
#> 29:  15.8     8 351.0   264  4.22 3.170 14.50     0     1     5     4
#> 30:  19.7     6 145.0   175  3.62 2.770 15.50     0     1     5     6
#> 31:  15.0     8 301.0   335  3.54 3.570 14.60     0     1     5     8
#> 32:  21.4     4 121.0   109  4.11 2.780 18.60     1     1     4     2
#>       mpg   cyl  disp    hp  drat    wt  qsec    vs    am  gear  carb
#>     <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num>
#>     mpg_per_cyl
#>           <num>
#>  1:    3.500000
#>  2:    3.500000
#>  3:    5.700000
#>  4:    3.566667
#>  5:    2.337500
#>  6:    3.016667
#>  7:    1.787500
#>  8:    6.100000
#>  9:    5.700000
#> 10:    3.200000
#> 11:    2.966667
#> 12:    2.050000
#> 13:    2.162500
#> 14:    1.900000
#> 15:    1.300000
#> 16:    1.300000
#> 17:    1.837500
#> 18:    8.100000
#> 19:    7.600000
#> 20:    8.475000
#> 21:    5.375000
#> 22:    1.937500
#> 23:    1.900000
#> 24:    1.662500
#> 25:    2.400000
#> 26:    6.825000
#> 27:    6.500000
#> 28:    7.600000
#> 29:    1.975000
#> 30:    3.283333
#> 31:    1.875000
#> 32:    5.350000
#>     mpg_per_cyl
#>           <num>
```
