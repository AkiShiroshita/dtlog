# dtlog must not change what data.table does. Every expression below is
# evaluated twice, once through dtlog's `[` and once through data.table's own
# method, and the results must be indistinguishable.

parity_expressions <- as.list(quote(list(
  DT[],
  DT[3],
  DT[1:5],
  DT[c(1, 1, 2)],
  DT[mpg > 20],
  DT[mpg > 1000],
  DT[order(-mpg)],
  DT[which(mpg > 20)],
  DT[cyl %in% c(4, 6) & mpg > thr],
  DT[mpg > thr, which = TRUE],
  DT[, mpg],
  DT[, .N],
  DT[, sum(mpg)],
  DT[, .(car, mpg)],
  DT[, c("mpg", "cyl"), with = FALSE],
  DT[, cols, with = FALSE],
  DT[2:3, "mpg", with = FALSE],
  DT[, .SD, .SDcols = c("mpg", "hp")],
  DT[, .N, by = cyl],
  DT[, .(m = mean(mpg)), keyby = .(cyl, gear)],
  DT[mpg > 20, .N, by = cyl],
  DT[, lapply(.SD, mean), by = cyl, .SDcols = c("mpg", "hp")],
  DT[, .SD[1], by = cyl],
  DT[, head(.SD, 2), by = cyl],
  DT[, .N, by = .(heavy = wt > 3)],
  DT[, .(m = mean(mpg)), env = list(mpg = "hp")],
  DT[OTHER, on = "cyl"],
  DT[OTHER, on = "cyl", nomatch = 0L],
  DT[OTHER, on = .(cyl), .(car, label)],
  DT[OTHER, .N, by = .EACHI, on = "cyl"],
  DT[OTHER, on = "cyl", mult = "first"],
  ROLL[QUERY, on = "t", roll = TRUE],
  ROLL[QUERY, on = "t", roll = "nearest"],
  DT[, .N, by = cyl][order(cyl)],
  DT[, sum(mpg), by = cyl, verbose = FALSE],
  DT[, {
    tmp <- mpg * 2
    sum(tmp)
  }],
  local({
    limit <- 25
    DT[mpg > limit]
  }),
  (function(limit) DT[mpg > limit])(25),
  DT[, kpl := mpg * 0.425],
  DT[cyl == 4, mpg := NA],
  DT[, `:=`(a = 1, b = "x")],
  DT[, let(c1 = 1L)],
  DT[, (cols) := lapply(.SD, as.integer), .SDcols = cols],
  DT[, c("mpg", "hp") := .(mpg * 2, hp + 1)],
  DT[, car := NULL],
  DT[, mean_mpg := mean(mpg), by = cyl],
  DT[2:4, kpl := 0],
  data.table::setkey(DT, cyl)[.(4)],
  DT[, .N, keyby = cyl][, cumsum(N)]
)))[-1L]

test_that("results are identical with and without dtlog", {
  for (expr in parity_expressions) expect_parity(expr)
})

test_that("modification by reference keeps the same object", {
  env <- fresh_env()
  before_address <- data.table::address(env$DT)
  quiet(eval(quote(DT[, kpl := mpg * 0.425]), env))
  expect_identical(data.table::address(env$DT), before_address)
  expect_true("kpl" %in% names(env$DT))
})

test_that("`:=` still suppresses auto printing at top level", {
  # data.table suppresses the printing of a `:=` result inside
  # print.data.table, and that mechanism only fires for top level (or sourced)
  # code, so run the statements through source()
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c(
    "DT <- data.table::as.data.table(head(mtcars, 3))",
    "DT[, z := 1]",
    "DT[mpg > 0, y := 2]"
  ), script)
  out <- quiet(capture.output(source(script, echo = FALSE, print.eval = TRUE)))
  expect_identical(out, character())

  writeLines(c(
    "DT <- data.table::as.data.table(head(mtcars, 3))",
    "DT[mpg > 0]"
  ), script)
  out2 <- quiet(capture.output(source(script, echo = FALSE, print.eval = TRUE)))
  expect_gt(length(out2), 1L)
})

test_that("errors come from data.table and mention the original call", {
  env <- fresh_env()
  err <- tryCatch(quiet(eval(quote(DT[, doesnotexist]), env)),
                  error = function(e) e)
  expect_s3_class(err, "error")
  expect_true(grepl("doesnotexist", conditionMessage(err), fixed = TRUE))
  # the condition must not carry the deparsed source of `[.data.table`
  expect_lt(nchar(paste(deparse(conditionCall(err)), collapse = "")), 200L)
})

test_that("callers that are not data.table aware still get data.frame rules", {
  # data.table:::cedta() makes `[` behave like `[.data.frame` when the caller
  # is a package that does not import data.table; dtlog must not change that
  body <- quote({
    dt <- data.table::data.table(a = 1:3, b = 4:6)
    list(one_arg = dt["a"], two_args = dt[1:2, 1L])
  })
  logged_fn <- as.function(list(body), envir = asNamespace("stats"))
  native_fn <- as.function(list(body), envir = new.env(parent = asNamespace("stats")))
  assign("[.data.table", dt_native_bracket, envir = environment(native_fn))
  expect_identical(
    lapply(quiet(logged_fn()), canonical),
    lapply(native_fn(), canonical)
  )
})

test_that("data.frames and other classes are untouched", {
  env <- fresh_env()
  df <- as.data.frame(mtcars)
  expect_identical(df[1:2, c("mpg", "cyl")], head(df[, c("mpg", "cyl")], 2L))
  expect_silent(df[df$mpg > 20, ])
})

test_that("the expression that produces the table is evaluated only once", {
  env <- fresh_env()
  env$calls <- 0L
  env$make <- function() {
    calls <<- calls + 1L
    DT
  }
  environment(env$make) <- env
  quiet(eval(quote(make()[mpg > 20]), env))
  expect_identical(env$calls, 1L)

  # a chained update must not be applied twice
  env2 <- fresh_env()
  quiet(eval(quote(DT[, n := 1][, n := n + 1]), env2))
  expect_identical(unique(env2$DT$n), 2)
})

test_that("over-allocation still writes back to the caller's variable", {
  env <- fresh_env()
  # a data.table created by as.data.table(list) has no spare column slots
  quiet(eval(quote({
    small <- data.table::setDT(list(a = 1:3))
    data.table::setalloccol(small, 0L)
    small[, b := a * 2]
  }), env))
  expect_identical(names(env$small), c("a", "b"))

  # the same for a table held inside a list
  env2 <- fresh_env()
  quiet(eval(quote({
    holder <- list(dt = data.table::setalloccol(data.table::data.table(a = 1:3), 0L))
    holder$dt[, b := a * 2]
  }), env2))
  expect_identical(names(env2$holder$dt), c("a", "b"))
})
