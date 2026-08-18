# The native pipe is a syntax transformation, so `x |> f(y)` reaches dtlog as
# an ordinary call to f(x, y). What is new is the shape of the first argument:
# it is a call rather than a name, which is also what `f(g(x))` looks like.
#
# `_[i, j, by]` only parses on R >= 4.3.0, so those expressions are parsed at
# run time rather than written literally into this file.
pipe_expr <- function(text) {
  testthat::skip_if(getRversion() < "4.3.0",
                    "the `_` placeholder in `_[` needs R >= 4.3.0")
  parse(text = text)[[1L]]
}

test_that("`|>` with the `_` placeholder logs every step of the chain", {
  msgs <- dtlog_messages(pipe_expr(
    "DT |> _[mpg > 20] |> _[, .(m = mean(hp)), by = cyl] |> _[order(cyl)]"
  ))
  expect_match(msgs[1L], "^filter: removed 18 rows \\(56%\\), 14 rows remaining$")
  expect_match(msgs[2L], "^group_by: one grouping variable \\(cyl\\)$")
  expect_match(msgs[3L], "^summarize: now 2 rows and 2 columns")
  expect_match(msgs[4L], "^arrange: reordered 2 rows$")
})

test_that("a piped chain returns exactly what data.table returns", {
  expect_parity(pipe_expr("DT |> _[mpg > 20] |> _[, .(m = mean(hp)), by = cyl]"))
  expect_parity(pipe_expr("DT |> _[, .(car, mpg)] |> unique() |> head(3)"))
  expect_parity(pipe_expr("DT |> _[mpg > 20] |> merge(OTHER, by = \"cyl\")"))
  expect_parity(pipe_expr("DT |> _[, kpl := mpg * 0.425]"))
  expect_parity(pipe_expr("DT |> _[mpg > 20] |> setorder(cyl)"))
})

test_that("set*() reports what it changed when the table is a temporary", {
  last <- function(expr) {
    msgs <- dtlog_messages(expr)
    msgs[length(msgs)]
  }
  expect_match(last(quote(setorder(DT[mpg > 20], cyl))),
               "^arrange: sorted 14 rows by \\(cyl\\)$")
  expect_match(last(quote(setorderv(DT[mpg > 20], "cyl"))),
               "^arrange: sorted 14 rows by \\(cyl\\)$")
  expect_match(last(quote(setkey(DT[mpg > 20], cyl))),
               "^setkey: keyed by \\(cyl\\), 14 rows sorted$")
  expect_match(last(quote(setkeyv(DT[mpg > 20], "cyl"))),
               "^setkeyv: keyed by \\(cyl\\), 14 rows sorted$")
  expect_match(last(quote(setnames(DT[, .(car, mpg)], "mpg", "miles"))),
               "^rename: renamed one variable \\(mpg -> miles\\)$")
  expect_match(last(quote(setcolorder(DT[, .(car, mpg)], c("mpg", "car")))),
               "^relocate: columns reordered \\(mpg, car\\)$")
  expect_match(last(quote(setindex(DT[mpg > 20], cyl))),
               "^setindex: added index \\(cyl\\)$")
  expect_match(last(quote(set(DT[, .(car, mpg)], 1L, "mpg", 0))),
               "^set: changed one value \\(3%\\) of 'mpg'")
  # the same call written as a pipe
  expect_match(last(pipe_expr("DT |> _[mpg > 20] |> setorder(cyl)")),
               "^arrange: sorted 14 rows by \\(cyl\\)$")
})

test_that("a temporary first argument is computed exactly once", {
  count_calls <- function(expr, run) {
    env <- fresh_env()
    eval(quote({
      calls <- 0L
      make <- function() {
        calls <<- calls + 1L
        data.table::data.table(g = c("b", "a", "c"), v = 1:3)
      }
    }), env)
    run(eval(expr, env))
    env$calls
  }
  for (run in list(loud, quiet)) {
    expect_identical(count_calls(quote(setorder(make(), g)), run), 1L)
    expect_identical(count_calls(quote(setkey(make(), g)), run), 1L)
    expect_identical(count_calls(quote(setnames(make(), "v", "value")), run), 1L)
    expect_identical(count_calls(quote(set(make(), 1L, "v", 99L)), run), 1L)
    expect_identical(count_calls(quote(make()[v > 1]), run), 1L)
    expect_identical(count_calls(pipe_expr("make() |> _[v > 1] |> setorder(g)"), run), 1L)
  }
})

test_that("set*() still writes back into the caller when given a name", {
  env <- fresh_env()
  eval(quote(df <- data.frame(a = 1:3)), env)
  loud(eval(quote(setDT(df)), env))
  expect_true(data.table::is.data.table(env$df))

  eval(quote(l <- list(dt = data.table::data.table(g = c("b", "a"), v = 1:2))), env)
  loud(eval(quote(setkey(l$dt, g)), env))
  expect_identical(data.table::key(env$l$dt), "g")

  loud(eval(quote(setorder(DT, mpg)), env))
  expect_false(is.unsorted(env$DT$mpg))
})

test_that("the transcript records the call as written, not the placeholder", {
  env <- fresh_env()
  path <- tempfile(fileext = ".txt")
  dt_log(path, echo = FALSE)
  eval(quote(setorder(DT[mpg > 20], cyl)), env)
  suppressMessages(dt_log_end())
  lines <- readLines(path)
  expect_false(any(grepl(".dtlog_", lines, fixed = TRUE)))
  expect_true("> setorder(DT[mpg > 20], cyl)" %in% lines)
  expect_true("arrange: sorted 14 rows by (cyl)" %in% lines)
})
