# Write the code and its log to a text file

\`dt_log()\` starts a transcript: from that point on, every operation
that dtlog reports is appended to a text file, together with the call
that produced it. \`dt_log_end()\` closes the transcript. Start and end
are up to you; nothing is written before the first call or after the
second.

## Usage

``` r
dt_log(file = "dtlog.txt", append = FALSE, code = TRUE, echo = TRUE)

dt_log_end()

dt_log_file()
```

## Arguments

- file:

  Path of the text file. \`NULL\` ends the current transcript, so
  \`dt_log(NULL)\` is the same as \`dt_log_end()\`.

- append:

  Append to an existing file instead of overwriting it.

- code:

  Write the call above its log. Set to \`FALSE\` for the messages alone.

- echo:

  Keep printing to the console as well. \`FALSE\` writes only to the
  file.

## Value

The path of the transcript, invisibly.

## Details

Each operation is appended with a plain \[cat()\] that opens and closes
the file again, so the transcript stays readable while a long script is
running and survives a session that ends without \`dt_log_end()\` (only
the closing line is then missing).

## Examples

``` r
path <- tempfile(fileext = ".txt")
dt_log(path, echo = FALSE)
dt <- data.table::as.data.table(mtcars)
dt[mpg > 20]
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
dt[, kpl := mpg * 0.425]
#>       mpg   cyl  disp    hp  drat    wt  qsec    vs    am  gear  carb     kpl
#>     <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num>   <num>
#>  1:  21.0     6 160.0   110  3.90 2.620 16.46     0     1     4     4  8.9250
#>  2:  21.0     6 160.0   110  3.90 2.875 17.02     0     1     4     4  8.9250
#>  3:  22.8     4 108.0    93  3.85 2.320 18.61     1     1     4     1  9.6900
#>  4:  21.4     6 258.0   110  3.08 3.215 19.44     1     0     3     1  9.0950
#>  5:  18.7     8 360.0   175  3.15 3.440 17.02     0     0     3     2  7.9475
#>  6:  18.1     6 225.0   105  2.76 3.460 20.22     1     0     3     1  7.6925
#>  7:  14.3     8 360.0   245  3.21 3.570 15.84     0     0     3     4  6.0775
#>  8:  24.4     4 146.7    62  3.69 3.190 20.00     1     0     4     2 10.3700
#>  9:  22.8     4 140.8    95  3.92 3.150 22.90     1     0     4     2  9.6900
#> 10:  19.2     6 167.6   123  3.92 3.440 18.30     1     0     4     4  8.1600
#> 11:  17.8     6 167.6   123  3.92 3.440 18.90     1     0     4     4  7.5650
#> 12:  16.4     8 275.8   180  3.07 4.070 17.40     0     0     3     3  6.9700
#> 13:  17.3     8 275.8   180  3.07 3.730 17.60     0     0     3     3  7.3525
#> 14:  15.2     8 275.8   180  3.07 3.780 18.00     0     0     3     3  6.4600
#> 15:  10.4     8 472.0   205  2.93 5.250 17.98     0     0     3     4  4.4200
#> 16:  10.4     8 460.0   215  3.00 5.424 17.82     0     0     3     4  4.4200
#> 17:  14.7     8 440.0   230  3.23 5.345 17.42     0     0     3     4  6.2475
#> 18:  32.4     4  78.7    66  4.08 2.200 19.47     1     1     4     1 13.7700
#> 19:  30.4     4  75.7    52  4.93 1.615 18.52     1     1     4     2 12.9200
#> 20:  33.9     4  71.1    65  4.22 1.835 19.90     1     1     4     1 14.4075
#> 21:  21.5     4 120.1    97  3.70 2.465 20.01     1     0     3     1  9.1375
#> 22:  15.5     8 318.0   150  2.76 3.520 16.87     0     0     3     2  6.5875
#> 23:  15.2     8 304.0   150  3.15 3.435 17.30     0     0     3     2  6.4600
#> 24:  13.3     8 350.0   245  3.73 3.840 15.41     0     0     3     4  5.6525
#> 25:  19.2     8 400.0   175  3.08 3.845 17.05     0     0     3     2  8.1600
#> 26:  27.3     4  79.0    66  4.08 1.935 18.90     1     1     4     1 11.6025
#> 27:  26.0     4 120.3    91  4.43 2.140 16.70     0     1     5     2 11.0500
#> 28:  30.4     4  95.1   113  3.77 1.513 16.90     1     1     5     2 12.9200
#> 29:  15.8     8 351.0   264  4.22 3.170 14.50     0     1     5     4  6.7150
#> 30:  19.7     6 145.0   175  3.62 2.770 15.50     0     1     5     6  8.3725
#> 31:  15.0     8 301.0   335  3.54 3.570 14.60     0     1     5     8  6.3750
#> 32:  21.4     4 121.0   109  4.11 2.780 18.60     1     1     4     2  9.0950
#>       mpg   cyl  disp    hp  drat    wt  qsec    vs    am  gear  carb     kpl
#>     <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num>   <num>
dt_log_end()
#> dt_log: wrote 2 operations to '/tmp/RtmpPx8cA1/file18d6d81f0d4.txt'
cat(readLines(path), sep = "\n")
#> # dtlog transcript, started 2026-08-22 10:32:11
#> # R version 4.6.1 (2026-06-24), data.table 1.18.4, dtlog 0.1.0
#> > dt[mpg > 20]
#> filter: removed 18 rows (56%), 14 rows remaining
#> 
#> > dt[, `:=`(kpl, mpg * 0.425)]
#> mutate: new variable 'kpl' (double) with 25 unique values and 0% NA
#> 
#> # dtlog transcript, ended 2026-08-22 10:32:11 (2 operations)
```
