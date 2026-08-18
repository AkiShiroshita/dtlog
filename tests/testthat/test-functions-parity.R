# the same check as test-parity.R, for the functions other than `[`

function_expressions <- as.list(quote(list(
  merge(DT, OTHER, by = "cyl"),
  merge(DT, OTHER, by = "cyl", all.x = TRUE),
  merge(DT, OTHER, by = "cyl", all = TRUE),
  merge(DT, OTHER, by.x = "cyl", by.y = "cyl", all.y = TRUE),
  unique(DT, by = "cyl"),
  unique(DT[, .(cyl, gear)]),
  duplicated(DT, by = "cyl"),
  stats::na.omit(WITH_NA),
  stats::na.omit(WITH_NA, cols = "b"),
  stats::na.omit(WITH_NA, invert = TRUE),
  head(DT, 5),
  head(DT, -2),
  head(DT, 100),
  tail(DT, 5),
  tail(DT, 0),
  head(DT[order(-mpg)], 5),
  rbindlist(list(OTHER, OTHER)),
  rbindlist(list(OTHER, OTHER), idcol = "src"),
  funion(OTHER, HALF),
  fintersect(OTHER, HALF),
  fsetdiff(OTHER, HALF),
  melt(WIDE, id.vars = "id"),
  melt(WIDE, id.vars = "id", measure.vars = "p", value.name = "val"),
  dcast(LONG, id ~ variable),
  dcast(LONG, id ~ variable, fun.aggregate = sum),
  fread(text = "a,b\n1,2\n3,4"),
  fwrite(OTHER, TMPFILE),
  fwrite(OTHER, TMPFILE, append = TRUE),
  as.data.table(as.data.frame(OTHER)),
  as.data.table(head(mtcars, 3), keep.rownames = "car"),
  as.data.table(list(a = 1:3, b = 4:6)),
  as.data.table(matrix(1:4, 2)),
  setnames(data.table::copy(OTHER), "label", "name"),
  setcolorder(data.table::copy(OTHER), c("label", "cyl")),
  setkey(data.table::copy(OTHER), cyl),
  setkeyv(data.table::copy(OTHER), "label"),
  setorder(data.table::copy(DT), -mpg),
  setorderv(data.table::copy(DT), c("cyl", "mpg")),
  setindex(data.table::copy(DT), cyl),
  setindexv(data.table::copy(DT), "gear"),
  set(data.table::copy(DT), i = 1L, j = "mpg", value = 0),
  set(data.table::copy(DT), j = "gear", value = NULL),
  setDT(as.data.frame(OTHER)),
  setDF(data.table::copy(OTHER)),
  setattr(data.table::copy(OTHER), "myattr", "value")
)))[-1L]

test_that("the wrapped functions return what data.table returns", {
  for (expr in function_expressions) expect_parity(expr)
})

test_that("set functions still work by reference on the caller's variable", {
  # setnames
  env <- fresh_env()
  quiet(eval(quote(setnames(DT, "mpg", "miles")), env))
  expect_true("miles" %in% names(env$DT))

  # setkey
  quiet(eval(quote(setkey(DT, cyl)), env))
  expect_identical(data.table::key(env$DT), "cyl")

  # setDT converts the caller's variable in place
  env2 <- fresh_env()
  env2$df <- data.frame(a = 1:3)
  quiet(eval(quote(setDT(df)), env2))
  expect_s3_class(env2$df, "data.table")

  # setDF converts it back
  quiet(eval(quote(setDF(df)), env2))
  expect_false(data.table::is.data.table(env2$df))

  # set() writes into the existing table
  env3 <- fresh_env()
  quiet(eval(quote(set(DT, i = 1L, j = "mpg", value = 0)), env3))
  expect_identical(env3$DT$mpg[1L], 0)
})

test_that("arguments of the wrapped functions are evaluated only once", {
  env <- fresh_env()
  env$calls <- 0L
  env$make <- function() {
    calls <<- calls + 1L
    OTHER
  }
  environment(env$make) <- env
  quiet(eval(quote(unique(make())), env))
  expect_identical(env$calls, 1L)
  quiet(eval(quote(merge(make(), make(), by = "cyl")), env))
  expect_identical(env$calls, 3L)
})
