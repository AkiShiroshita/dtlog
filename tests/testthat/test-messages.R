test_that("i produces filter and arrange messages", {
  expect_dtlog_message(quote(DT[mpg > 20]),
                       "filter: removed 18 rows \\(56%\\), 14 rows remaining")
  expect_dtlog_message(quote(DT[mpg > 0]), "filter: no rows removed")
  expect_dtlog_message(quote(DT[mpg > 1000]), "filter: removed all rows")
  expect_dtlog_message(quote(DT[order(-mpg)]), "arrange: reordered 32 rows")
  expect_dtlog_message(quote(OTHER[c(1, 1, 2)]), "filter: added one row, 3 rows total")
  expect_dtlog_message(quote(DT[mpg > 20, which = TRUE]),
                       "which: 14 out of 32 rows match \\(44%\\)")
})

test_that("j produces select, mutate and summarize messages", {
  expect_dtlog_message(quote(DT[, .(car, mpg)]),
                       "select: dropped 10 variables \\(cyl, disp, hp, drat, wt, \u2026\\)")
  msgs_t <- dtlog_messages(quote(DT[, .(mpg2 = mpg * 2)]))
  expect_match(msgs_t[1L],
               "^transmute: new variable 'mpg2' \\(double\\) with 25 unique values and 0% NA$")
  expect_match(msgs_t[2L], "dropped 12 variables")
  expect_dtlog_message(quote(DT[, sum(mpg)]),
                       "summarize: returned one value \\(double\\)")
  expect_dtlog_message(quote(DT[, mpg]),
                       "summarize: returned double of length 32")
  msgs <- dtlog_messages(quote(DT[, .(m = mean(mpg)), by = cyl]))
  expect_match(msgs[1L], "group_by: one grouping variable \\(cyl\\)")
  expect_match(msgs[2L], "summarize: now 3 rows and 2 columns \\(was 32 rows and 12 columns\\)")
})

test_that(":= produces mutate messages", {
  env <- fresh_env()
  expect_dtlog_message(quote(DT[, kpl := mpg * 0.425]),
                       "mutate: new variable 'kpl' \\(double\\)", env)
  expect_dtlog_message(quote(DT[cyl == 4, mpg := NA]),
                       "mutate: changed 11 values \\(34%\\) of 'mpg' \\(11 new NAs\\)", env)
  expect_dtlog_message(quote(DT[, kpl := as.integer(kpl)]),
                       "mutate: converted 'kpl' from double to integer \\(0 new NA\\)", env)
  expect_dtlog_message(quote(DT[, kpl := NULL]),
                       "mutate: dropped one variable \\(kpl\\)", env)
  expect_dtlog_message(quote(DT[, hp := hp]), "mutate: no changes to 'hp'", env)
  expect_dtlog_message(quote(DT[, mean_hp := mean(hp), by = cyl]),
                       "mutate \\(by cyl\\): new variable 'mean_hp'", env)
  msgs <- dtlog_messages(quote(DT[, `:=`(one = 1, two = 2)]), env)
  expect_length(msgs, 2L)
  expect_match(msgs[2L], "^ {8}new variable 'two'")
})

test_that("an aggregating j is not reported as a filter", {
  # the row count of the result says nothing about how many rows i selected
  expect_identical(
    dtlog_messages(quote(DT[mpg > 20, .(m = mean(mpg))])),
    "summarize: now one row and one column (was 32 rows and 12 columns, after filtering with i)"
  )
  msgs <- dtlog_messages(quote(DT[mpg > 20, .N, by = cyl]))
  expect_match(msgs[1L], "^group_by: one grouping variable \\(cyl\\)$")
  expect_match(msgs[2L], "after filtering with i")

  # a j that only selects columns leaves the rows to i, so both are reported
  msgs2 <- dtlog_messages(quote(DT[mpg > 20, .(car, mpg)]))
  expect_match(msgs2[1L], "^filter: removed 18 rows")
  expect_match(msgs2[2L], "^select: dropped 10 variables")
  msgs3 <- dtlog_messages(quote(DT[mpg > 20, cols, with = FALSE]))
  expect_match(msgs3[1L], "^filter: removed 18 rows")
  expect_match(msgs3[2L], "^select: dropped 10 variables")

  # aggregation without i keeps the plain wording
  expect_identical(
    dtlog_messages(quote(DT[, lapply(.SD, mean), .SDcols = c("mpg", "hp")])),
    "summarize: now one row and 2 columns (was 32 rows and 12 columns)"
  )
})

test_that("the special variables are reported through the surrounding call", {
  env <- fresh_env()
  expect_dtlog_message(quote(DT[, n := .N, by = cyl]),
                       "mutate \\(by cyl\\): new variable 'n' \\(integer\\)", env)
  expect_dtlog_message(quote(DT[, grp := .GRP, by = cyl]),
                       "mutate \\(by cyl\\): new variable 'grp' \\(integer\\)", env)
  expect_dtlog_message(quote(DT[, lag_mpg := data.table::shift(mpg)]),
                       "mutate: new variable 'lag_mpg' \\(double\\) with .* and 3% NA", env)
  msgs <- dtlog_messages(quote(DT[, lapply(.SD, mean), by = cyl,
                                  .SDcols = c("mpg", "hp")]), env)
  expect_match(msgs[2L], "^summarize: now 3 rows and 3 columns")
})

test_that("joins report the columns and rows they add", {
  msgs <- dtlog_messages(quote(DT[OTHER, on = "cyl"]))
  expect_match(msgs[1L], "^join \\(on cyl\\): added one column \\(label\\)$")
  expect_match(msgs[2L], "rows: was 32, now 18 \\(-14\\)")
})

test_that("merge reports the join type and the matching", {
  msgs <- dtlog_messages(quote(merge(DT, OTHER, by = "cyl", all.x = TRUE)))
  expect_match(msgs[1L], "^left_join: added one column \\(label\\)")
  expect_match(msgs[2L], "rows only in DT\\s+14")
  expect_match(msgs[3L], "rows only in OTHER\\s+\\( 0\\)")
  expect_match(msgs[4L], "matched rows\\s+18")
  expect_match(msgs[6L], "rows total\\s+32")
  expect_match(dtlog_messages(quote(merge(DT, OTHER, by = "cyl")))[1L], "^inner_join")
  expect_match(dtlog_messages(quote(merge(DT, OTHER, by = "cyl", all = TRUE)))[1L],
               "^full_join")
})

test_that("the other wrapped functions report what they did", {
  expect_dtlog_message(quote(unique(DT, by = "cyl")),
                       "distinct: removed 29 rows \\(91%\\), 3 rows remaining")
  expect_dtlog_message(quote(duplicated(DT, by = "cyl")),
                       "duplicated: 29 of 32 rows marked as duplicates")
  expect_dtlog_message(quote(stats::na.omit(WITH_NA)),
                       "drop_na: removed 2 rows \\(67%\\), one row remaining")
  expect_dtlog_message(quote(rbindlist(list(OTHER, OTHER))),
                       "rbindlist: combined 2 tables into 4 rows and 2 columns")
  expect_dtlog_message(quote(funion(OTHER, HALF)),
                       "funion: 2 rows and one row in, 2 rows out")
  expect_dtlog_message(quote(melt(WIDE, id.vars = "id")),
                       "melt: reorganized \\(p, q\\) into \\(variable, value\\) \\[was 2x3, now 4x3\\]")
  expect_dtlog_message(
    quote(melt(WIDE, id.vars = "id", measure.vars = "p", value.name = "val")),
    "melt: reorganized \\(p\\) into \\(variable, val\\) \\[was 2x3, now 2x3\\], dropped one variable \\(q\\)"
  )
  expect_dtlog_message(quote(dcast(LONG, id ~ variable)),
                       "dcast: reorganized \\(variable, value\\) into \\(p, q\\)")
  expect_dtlog_message(quote(head(DT, 5)),
                       "head: removed 27 rows \\(84%\\), 5 rows remaining")
  expect_dtlog_message(quote(tail(DT, 5)),
                       "tail: removed 27 rows \\(84%\\), 5 rows remaining")
  expect_dtlog_message(quote(head(DT, 100)), "head: no rows removed")
  expect_dtlog_message(quote(stats::na.omit(WITH_NA, invert = TRUE)),
                       "na.omit \\(invert\\): kept the 2 rows with NA")
  expect_dtlog_message(quote(fread(text = "a,b\n1,2")),
                       "fread: read one row and 2 columns")
  expect_dtlog_message(quote(fwrite(OTHER, TMPFILE)),
                       "fwrite: wrote 2 rows and 2 columns to '.*\\.csv'")
  expect_dtlog_message(quote(fwrite(OTHER, TMPFILE, append = TRUE)),
                       "fwrite: appended 2 rows and 2 columns")
  expect_dtlog_message(quote(as.data.table(as.data.frame(OTHER))),
                       "as.data.table: converted data.frame to data.table \\(2 rows, 2 columns\\)")
  expect_dtlog_message(quote(as.data.table(head(mtcars, 3), keep.rownames = "car")),
                       "as.data.table: converted data.frame to data.table \\(3 rows, 12 columns\\), added \\(car\\)")
})

test_that("the set functions report what they changed", {
  env <- fresh_env()
  expect_dtlog_message(quote(setnames(DT, "mpg", "miles")),
                       "rename: renamed one variable \\(mpg -> miles\\)", env)
  expect_dtlog_message(quote(setcolorder(DT, c("miles", "car"))),
                       "relocate: columns reordered \\(miles, car, cyl, disp, hp, \u2026\\)", env)
  expect_dtlog_message(quote(setkey(DT, cyl)), "setkey: keyed by \\(cyl\\), 32 rows sorted", env)
  expect_dtlog_message(quote(setkey(DT, NULL)), "setkey: removed the key \\(was cyl\\)", env)
  expect_dtlog_message(quote(setorder(DT, -miles)), "arrange: sorted 32 rows by \\(-miles\\)", env)
  expect_dtlog_message(quote(setorderv(DT, "cyl")), "arrange: sorted 32 rows by \\(cyl\\)", env)
  expect_dtlog_message(quote(setindex(DT, gear)), "setindex: added index \\(gear\\)", env)
  expect_dtlog_message(quote(set(DT, i = 1L, j = "miles", value = 0)),
                       "set: changed one value \\(3%\\) of 'miles'", env)
  expect_dtlog_message(quote(set(DT, j = "gear", value = NULL)),
                       "set: dropped one variable \\(gear\\)", env)
  expect_dtlog_message(quote(DT[, c("vs", "am") := NULL]),
                       "mutate: dropped 2 variables \\(vs, am\\)", env)
  expect_dtlog_message(quote(setDF(DT)), "setDF: converted data.table to data.frame", env)
  expect_dtlog_message(quote(setDT(DT)), "setDT: converted data.frame to data.table", env)
})

test_that("options control the output", {
  env <- fresh_env()
  old <- options(dtlog.display = list())
  expect_silent(eval(quote(DT[mpg > 20]), env))
  options(old)

  collected <- character()
  old <- options(dtlog.display = list(function(x) collected <<- c(collected, x)))
  eval(quote(DT[mpg > 20]), env)
  options(old)
  expect_length(collected, 1L)
  expect_match(collected, "^filter: removed")

  dtlog_pause()
  expect_silent(eval(quote(DT[mpg > 20]), env))
  dtlog_resume()
  expect_message(eval(quote(DT[mpg > 20]), env), "filter")
})

test_that("the compact detail level avoids value level information", {
  env <- fresh_env()
  old <- options(dtlog.detail = "compact")
  on.exit(options(old), add = TRUE)
  expect_identical(dtlog_messages(quote(DT[, kpl := mpg * 0.425]), env),
                   "mutate: new variable 'kpl' (double)")
  msgs <- dtlog_messages(quote(DT[, kpl := 2]), env)
  expect_identical(msgs, "mutate: updated one variable (kpl)")
  msgs2 <- dtlog_messages(quote(merge(DT, OTHER, by = "cyl")), env)
  expect_match(msgs2[2L], "rows: was 32, now 18")
})

test_that("calls from other packages are silent by default", {
  # data.table calls inside a package namespace must not produce output
  f <- function() {
    dt <- data.table::data.table(a = 1:3)
    dt[a > 1]
  }
  environment(f) <- asNamespace("dtlog")
  expect_silent(f())

  old <- options(dtlog.log_from_packages = TRUE)
  on.exit(options(old), add = TRUE)
  expect_message(f(), "filter")
})
