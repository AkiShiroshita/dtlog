test_that("get_type() reports the data.table date classes", {
  # IDate extends Date and ITime is stored as an integer, so testing the base
  # classes first would swallow both
  expect_equal(get_type(data.table::as.IDate("2020-01-01")), "IDate")
  expect_equal(get_type(data.table::as.ITime("10:00:00")), "ITime")
  expect_equal(get_type(as.Date("2020-01-01")), "Date")
  expect_equal(get_type(as.POSIXct("2020-01-01 10:00:00", tz = "UTC")), "datetime")
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
