# Every log function checks the shape of what it is about to describe before it
# describes it. When snap() could not read the input, or the result is not the
# shape the wrapped function normally returns, dtlog says nothing rather than
# something wrong -- the message is never worth a wrong number. No call a user
# can write reaches these branches, so they are exercised directly, the way the
# reshape fallbacks are in test-reshape.R.

test_that("setnafill says nothing when it cannot count the NAs", {
  dt <- data.table::data.table(a = c(1, NA), b = c(NA, 2))
  # a table is what the NAs are counted in; anything else has no columns
  expect_null(na_counts(1:3))
  # the input was never captured
  expect_silent(log_setnafill(dt, list(), NULL, NULL))
  # the count was taken over a different set of columns than the table now has,
  # so filled = before - after would be nonsense
  expect_silent(log_setnafill(dt, list(x = snap(dt), na = c(a = 0L)), NULL, NULL))
})

test_that("setdroplevels says nothing when it cannot read the levels", {
  f <- data.table::data.table(k = factor("a"))
  expect_null(factor_levels(1:3))
  expect_silent(log_setdroplevels(f, list(), NULL, NULL))
  # the object the call wrote to is not a table, so there is no level set to
  # compare the one taken beforehand against
  expect_silent(log_setdroplevels(f, list(x = snap(1:3), levels = list()),
                                  NULL, NULL))
})

test_that("foverlaps says nothing about a result it cannot read", {
  x <- data.table::data.table(s = 1, e = 2)
  expect_silent(log_foverlaps(x, list(), NULL, NULL))
  # neither the matched rows nor a vector of row numbers
  expect_silent(log_foverlaps(list(1, 2), list(x = snap(x)), NULL, NULL))
})

test_that("fsetequal reports what it can and no more", {
  # not the one TRUE or FALSE the function answers with
  expect_silent(log_fsetequal(c(TRUE, FALSE), list(), NULL, NULL))
  # the answer stands on its own when the two inputs were not captured: the
  # sizes are left off rather than guessed
  expect_message(log_fsetequal(TRUE, list(), NULL, NULL),
                 "^fsetequal: the two tables hold the same rows")
  expect_message(log_fsetequal(FALSE, list(), NULL, NULL),
                 "^fsetequal: the two tables do not hold the same rows")
})
