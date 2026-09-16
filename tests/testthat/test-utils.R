test_that("get_type() reports the data.table date classes", {
  # IDate extends Date and ITime is stored as an integer, so testing the base
  # classes first would swallow both
  expect_equal(get_type(data.table::as.IDate("2020-01-01")), "IDate")
  expect_equal(get_type(data.table::as.ITime("10:00:00")), "ITime")
  expect_equal(get_type(as.Date("2020-01-01")), "Date")
  expect_equal(get_type(as.POSIXct("2020-01-01 10:00:00", tz = "UTC")), "datetime")
})

test_that("get_type() separates the two kinds of factor from a list column", {
  expect_equal(get_type(factor("a")), "factor")
  expect_equal(get_type(factor("a", levels = c("a", "b"), ordered = TRUE)),
               "ordered factor")
  expect_equal(get_type(list(1:2, 3L)), "list")
  expect_equal(get_type(1), "double")
})

test_that("a dtlog.display option that is not a function is ignored", {
  env <- fresh_env()
  old <- options(dtlog.display = "not a function")
  on.exit(options(old), add = TRUE)
  # dtlog_summary() does not run inside try_log(), so a bad option used to
  # error out of the caller's own code
  expect_silent(dtlog_summary(data.table::data.table(a = 1)))
  expect_silent(eval(quote(DT[mpg > 20]), env))
})

test_that("dtlog_summary() names the key when the table has one", {
  keyed <- data.table::data.table(a = 2:1, b = 3:4, key = "a")
  expect_message(dtlog_summary(keyed),
                 "^dtlog: data\\.table with 2 rows and 2 columns, keyed by \\(a\\)")
  expect_message(dtlog_summary(data.table::data.table(a = 1)),
                 "^dtlog: data\\.table with one row and one column\n")
  # the table itself comes back untouched, so that it can sit in a chain
  expect_identical(canonical(quiet(dtlog_summary(keyed))), canonical(keyed))
})

test_that("percent() keeps a rounded 100% and a rounded 0% apart from the real ones", {
  # rounding alone would report a filter that kept one row in a thousand as
  # having removed 100% of them, and one that removed that row as having
  # removed 0%
  expect_equal(percent(999, 1000), ">99%")
  expect_equal(percent(1, 1000), "<1%")
  expect_equal(percent(1000, 1000), "100%")
  expect_equal(percent(0, 1000), "0%")
  expect_equal(percent(1, 0), "NA%")
  expect_equal(percent(NA_integer_, 10), "NA%")
})

test_that("display_block() says nothing when it was given nothing to say", {
  expect_message(display_block("mutate: ", list("one line")), "^mutate: one line")
  expect_silent(display_block("mutate: ", list(NULL)))
  expect_silent(display_block("mutate: ", list()))
})

test_that("a warning from the comparison does not discard the change count", {
  registerS3method("Ops", "dtlogNoisy", function(e1, e2) {
    warning("noisy comparison")
    get(.Generic)(unclass(e1), unclass(e2))
  })
  old <- structure(c(1, 2, 3), class = "dtlogNoisy")
  new <- structure(c(1, 9, 3), class = "dtlogNoisy")
  expect_equal(n_changed(old, new), 1L)
  # dtlog's own comparison must not warn at the caller either
  expect_silent(n_changed(old, new))
})

test_that("a comparison that cannot be made leaves the count unknown", {
  registerS3method("Ops", "dtlogBroken", function(e1, e2) stop("no comparison"))
  old <- structure(c(1, 2, 3), class = "dtlogBroken")
  new <- structure(c(1, 9, 3), class = "dtlogBroken")
  expect_identical(n_changed(old, new), NA_integer_)
  # two columns of different lengths are not comparable either
  expect_identical(n_changed(1:3, 1:4), NA_integer_)
})

test_that("n_changed() compares list and factor columns elementwise", {
  # `!=` on lists is an error, and on two factors with different level sets it
  # warns and compares the integer codes, so neither is left to it
  expect_equal(n_changed(list(1:2, 3L), list(1:2, 4L)), 1L)
  expect_equal(n_changed(list(1:2, 3L), list(1:2, 3L)), 0L)
  expect_equal(n_changed(factor(c("a", "b")), factor(c("a", "c"))), 1L)
  expect_equal(n_changed(factor(c("a", "b")), c("a", "b")), 0L)
})

test_that("a list column is described and counted without claiming a number", {
  # is.na() on a list is elementwise and says nothing about a column whose
  # cells are themselves vectors, and uniqueN() means nothing for one either
  expect_equal(n_na(list(1:2, NA)), 0L)
  expect_equal(describe_values(list(1:2, 3L)), "(list) with 0% NA")
})

test_that("na_text() stays singular for a single NA", {
  expect_equal(na_text(c(1, 2), c(NA, 2)), "one new NA")
  expect_equal(na_text(c(NA, 2), c(1, 2)), "one fewer NA")
  expect_equal(na_text(c(1, 2), c(NA, NA)), "2 new NAs")
  expect_equal(na_text(c(NA, NA), c(1, 2)), "2 fewer NAs")
})
