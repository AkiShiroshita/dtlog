# dtlog only reads. These are the invariants that say so.

test_that("logging leaves the columns of the input untouched", {
  env <- fresh_env()
  dt <- env$DT
  before_values <- lapply(dt, function(col) col[])
  before_addresses <- vapply(dt, data.table::address, character(1L))
  before_meta <- list(key = data.table::key(dt), indices = data.table::indices(dt),
                      truelength = data.table::truelength(dt), names = names(dt))

  loud({
    dt[mpg > 20]
    dt[, .(car, mpg)]
    dt[, .(m = mean(mpg)), by = cyl]
    dt[, sum(mpg)]
    unique(dt, by = "cyl")
    stats::na.omit(dt)
    data.table::melt(dt, id.vars = "car", measure.vars = "mpg")
  })

  expect_identical(lapply(dt, function(col) col[]), before_values)
  expect_identical(vapply(dt, data.table::address, character(1L)), before_addresses)
  expect_identical(
    list(key = data.table::key(dt), indices = data.table::indices(dt),
         truelength = data.table::truelength(dt), names = names(dt)),
    before_meta
  )
})

test_that("`:=` still updates in place, without an extra copy", {
  env <- fresh_env()
  dt <- env$DT
  dt_address <- data.table::address(dt)
  col_address <- data.table::address(dt$mpg)

  loud(dt[2:3, mpg := 0])

  expect_identical(data.table::address(dt), dt_address)
  expect_identical(data.table::address(dt$mpg), col_address)
  expect_identical(dt$mpg[2:3], c(0, 0))
})

test_that("logging a merge does not add keys or indices to the inputs", {
  # the join statistics run two extra matching passes over x and y
  a <- data.table::data.table(id = c(3L, 1L, 2L), v = 1:3)
  b <- data.table::data.table(id = c(2L, 3L, 4L), w = c("x", "y", "z"))
  loud(merge(a, b, by = "id"))
  expect_null(data.table::key(a))
  expect_null(data.table::key(b))
  expect_null(data.table::indices(a))
  expect_null(data.table::indices(b))
})

test_that("automatic indexing still happens exactly as in data.table", {
  a <- data.table::data.table(id = c(3L, 1L, 2L), v = 1:3)
  loud(a[id == 2L])
  expect_identical(data.table::indices(a), "id")
})

test_that("nothing is left behind in the calling environment", {
  env <- fresh_env()
  before <- sort(ls(env, all.names = TRUE))
  loud({
    eval(quote(DT[, b := mpg * 2]), env)
    eval(quote(DT[mpg > 20]), env)
    eval(quote(setnames(DT, "b", "bb")), env)
    eval(quote(merge(DT, OTHER, by = "cyl")), env)
  })
  expect_identical(sort(ls(env, all.names = TRUE)), before)
})

test_that("dtlog sets no options of its own", {
  before <- options()[grep("^datatable\\.", names(options()))]
  env <- fresh_env()
  loud({
    eval(quote(DT[mpg > 20]), env)
    eval(quote(DT[, kpl := mpg * 0.425]), env)
    eval(quote(merge(DT, OTHER, by = "cyl")), env)
  })
  expect_identical(options()[grep("^datatable\\.", names(options()))], before)
})

test_that("a failing log function cannot break the operation", {
  env <- fresh_env()
  old <- options(dtlog.display = list(function(x) stop("boom")))
  on.exit(options(old), add = TRUE)
  result <- eval(quote(DT[mpg > 20]), env)
  expect_identical(nrow(result), 14L)
  eval(quote(DT[, kpl := mpg * 0.425]), env)
  expect_true("kpl" %in% names(env$DT))
})

test_that("data.table's own optimisations still fire", {
  # if dtlog changed how the call reaches data.table, GForce would stop
  # applying and the verbose output would say so
  env <- fresh_env()
  env$BIG <- data.table::data.table(g = rep(1:5, 40), v = seq_len(200) / 7)
  out <- quiet(capture.output(
    eval(quote(BIG[, .(m = mean(v)), by = g, verbose = TRUE]), env)
  ))
  expect_true(any(grepl("GForce optimized j", out, fixed = TRUE)))
  out2 <- quiet(capture.output(
    eval(quote(BIG[g == 3L, verbose = TRUE]), env)
  ))
  expect_true(any(grepl("index", out2, fixed = TRUE)))
})

test_that("code inside j still sees the caller's variables", {
  env <- fresh_env()
  env$counter <- 0
  env$outer_var <- 7

  # <<- walks past dtlog's evaluation environment and reaches the caller
  quiet(eval(quote(DT[, {
    counter <<- counter + 1
    sum(mpg)
  }]), env))
  expect_identical(env$counter, 1)

  # get() and exists() find the caller's objects
  expect_true(quiet(eval(quote(DT[, exists("outer_var")]), env)))
  expect_identical(quiet(eval(quote(DT[, get("outer_var")]), env)), 7)

  # a plain assignment in j stays in data.table's own environment, as always
  quiet(eval(quote(DT[, {
    tmp_in_j <- 99
    sum(mpg)
  }]), env))
  expect_false(exists("tmp_in_j", envir = env, inherits = FALSE))

  # the same inside a function
  env$f <- function() {
    n <- 0
    DT[, {
      n <<- n + 10
      sum(mpg)
    }]
    n
  }
  environment(env$f) <- env
  expect_identical(quiet(eval(quote(f()), env)), 10)
})

test_that("dtlog is visible on the call stack, and that is the only trace", {
  # documented consequence of re-evaluating the call: j runs a few frames
  # deeper. Nothing else about the evaluation changes.
  env <- fresh_env()
  env$native_bracket <- dt_native_bracket
  deep <- quiet(eval(quote(DT[, sys.nframe()]), env))
  shallow <- quiet(eval(quote(native_bracket(DT, , sys.nframe())), env))
  expect_gt(deep, shallow)
})
