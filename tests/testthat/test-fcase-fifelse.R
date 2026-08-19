# fcase() and fifelse() are plain data.table helpers: dtlog does not redefine
# them, so a call that uses one must behave exactly as it would without dtlog
# and be described by the message of the operation it appears in.

test_that("fifelse() and fcase() in j produce mutate messages", {
  env <- fresh_env()
  expect_dtlog_message(
    quote(DT[, band := data.table::fifelse(mpg > 20, "high", "low")]),
    "mutate: new variable 'band' \\(character\\) with 2 unique values and 0% NA",
    env
  )
  expect_dtlog_message(
    quote(DT[, band3 := data.table::fcase(mpg < 15, "low", mpg < 25, "mid",
                                          default = "high")]),
    "mutate: new variable 'band3' \\(character\\) with 3 unique values and 0% NA",
    env
  )
  # no default: the rows that match nothing become NA, and the share is reported
  expect_dtlog_message(
    quote(DT[, top := data.table::fcase(mpg > 30, "top")]),
    "mutate: new variable 'top' \\(character\\) with 2 unique values and 88% NA",
    env
  )
  expect_dtlog_message(
    quote(DT[, gear := data.table::fcase(mpg > 20, 5, default = gear)]),
    "mutate: changed 12 values \\(38%\\) of 'gear' \\(0 new NAs\\)",
    env
  )
  # writing the same values back is still a no-op
  expect_dtlog_message(
    quote(DT[, hp := data.table::fifelse(hp > 0, hp, NA_real_)]),
    "mutate: no changes to 'hp'",
    env
  )
})

test_that("a grouped or multi column update keeps its usual message", {
  env <- fresh_env()
  expect_dtlog_message(
    quote(DT[, fast := data.table::fifelse(mpg > mean(mpg), 1L, 0L), by = cyl]),
    "mutate \\(by cyl\\): new variable 'fast' \\(integer\\)",
    env
  )
  msgs <- dtlog_messages(
    quote(DT[, `:=`(a = data.table::fifelse(mpg > 20, 1L, 0L),
                    b = data.table::fcase(cyl == 4, "four", default = "more"))]),
    env
  )
  expect_length(msgs, 2L)
  expect_match(msgs[1L], "^mutate: new variable 'a' \\(integer\\)")
  expect_match(msgs[2L], "^ {8}new variable 'b' \\(character\\)")
})

test_that("fifelse() and fcase() in i and by are reported like any other call", {
  expect_dtlog_message(
    quote(DT[data.table::fifelse(mpg > 20, TRUE, FALSE)]),
    "filter: removed 18 rows \\(56%\\), 14 rows remaining"
  )
  msgs <- dtlog_messages(
    quote(DT[, .N, by = .(lvl = data.table::fcase(mpg < 20, "low",
                                                  default = "high"))])
  )
  expect_match(msgs[1L], "^group_by: one grouping variable \\(lvl\\)$")
  expect_match(msgs[2L], "^summarize: now 2 rows and 2 columns")
})

test_that("set() reports a column computed with fifelse()", {
  env <- fresh_env()
  msgs <- dtlog_messages(
    quote(set(DT, j = "heavy",
              value = data.table::fifelse(DT$wt > 3, TRUE, FALSE))),
    env
  )
  expect_match(msgs[1L], "^set: new variable 'heavy' \\(logical\\)")
})

fcase_expressions <- as.list(quote(list(
  DT[data.table::fifelse(mpg > thr, TRUE, FALSE)],
  DT[, .(band = data.table::fcase(mpg < 20, "low", default = "high"))],
  DT[, .N, by = .(band = data.table::fcase(mpg < 20, "low", default = "high"))],
  DT[, band := data.table::fifelse(mpg > 20, "high", "low")],
  DT[, band := data.table::fcase(mpg < 15, "low", mpg < 25, "mid",
                                 default = "high")],
  DT[, top := data.table::fcase(mpg > 30, "top")],
  DT[, gear := data.table::fcase(mpg > 20, 5, default = gear)],
  DT[cyl == 4, kpl := data.table::fifelse(mpg > 25, 1, 0)],
  DT[, fast := data.table::fifelse(mpg > mean(mpg), 1L, 0L), by = cyl],
  DT[, `:=`(a = data.table::fifelse(mpg > 20, 1L, 0L),
            b = data.table::fcase(cyl == 4, "four", default = "more"))],
  DT[mpg > 20][, band := data.table::fcase(cyl == 4, "four", default = "more")]
)))[-1L]

test_that("results are identical with and without dtlog", {
  for (expr in fcase_expressions) expect_parity(expr)
})
