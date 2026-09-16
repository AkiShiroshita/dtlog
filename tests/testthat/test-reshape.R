# dcast.data.table() is exported both as the method and through dcast(), so a
# caller that reaches for the method by name goes through a wrapper of its own.
test_that("the dcast method logs what the generic logs", {
  env <- fresh_env()
  expect_dtlog_message(quote(dcast.data.table(LONG, id ~ variable)),
                       "dcast: reorganized \\(variable, value\\) into \\(p, q\\)", env)
  expect_parity(quote(dcast.data.table(LONG, id ~ variable)))
})

# The branches below are what the reshape log falls back to when snap() could
# not read the input, or when the result is not a table. Neither is reachable
# from a call a user can write, and both decide what dtlog says when its own
# bookkeeping has failed, so they are checked directly.
test_that("a reshape whose input was not captured reports only the result", {
  expect_message(log_reshape("melt", data.table::data.table(a = 1:2), NULL),
                 "^melt: now 2 rows and one column")
  expect_silent(log_reshape("melt", 1:3, NULL))
})

test_that("melted_columns() names the stacked columns only when it is sure", {
  wide <- data.table::data.table(a = 1:2)
  # not a table, so nothing can be read off the result
  expect_null(melted_columns(1:3, list(names = "a")))
  # no input to compare the result against
  expect_null(melted_columns(wide, NULL))
  # nothing disappeared and nothing appeared: no column was stacked
  expect_null(melted_columns(wide, list(names = "a")))
})
