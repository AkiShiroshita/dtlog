transcript_of <- function(expr, ...) {
  path <- tempfile(fileext = ".txt")
  dt_log(path, echo = FALSE, ...)
  on.exit(if (!is.null(dt_log_file())) suppressMessages(dt_log_end()), add = TRUE)
  force(expr)
  suppressMessages(dt_log_end())
  readLines(path)
}

test_that("the transcript holds the call and its log", {
  env <- fresh_env()
  lines <- transcript_of({
    eval(quote(DT[mpg > 20]), env)
    eval(quote(DT[, kpl := mpg * 0.425]), env)
  })
  expect_match(lines[1L], "^# dtlog transcript, started")
  expect_match(lines[2L], "data.table")
  expect_true("> DT[mpg > 20]" %in% lines)
  expect_true("filter: removed 18 rows (56%), 14 rows remaining" %in% lines)
  expect_true("> DT[, `:=`(kpl, mpg * 0.425)]" %in% lines)
  expect_match(lines[length(lines)], "^# dtlog transcript, ended .*\\(2 operations\\)$")
})

test_that("S3 methods are written the way they were called", {
  env <- fresh_env()
  lines <- transcript_of({
    eval(quote(head(DT, 5)), env)
    eval(quote(merge(DT, OTHER, by = "cyl")), env)
    eval(quote(unique(DT, by = "cyl")), env)
    eval(quote(as.data.table(list(a = 1:3))), env)
  })
  expect_true("> head(DT, 5)" %in% lines)
  expect_true("> merge(DT, OTHER, by = \"cyl\")" %in% lines)
  expect_true("> unique(DT, by = \"cyl\")" %in% lines)
  # a function that is not an S3 method keeps its name
  expect_true(any(grepl("^> as.data.table\\(", lines)))
})

test_that("code = FALSE writes only the messages", {
  env <- fresh_env()
  lines <- transcript_of(eval(quote(DT[mpg > 20]), env), code = FALSE)
  expect_false(any(grepl("^> ", lines)))
  expect_true("filter: removed 18 rows (56%), 14 rows remaining" %in% lines)
})

test_that("echo controls the console, the file is written either way", {
  env <- fresh_env()
  path <- tempfile(fileext = ".txt")

  dt_log(path, echo = FALSE)
  expect_silent(eval(quote(DT[mpg > 20]), env))
  suppressMessages(dt_log_end())
  expect_true(any(grepl("^filter: removed 18 rows", readLines(path))))

  path2 <- tempfile(fileext = ".txt")
  dt_log(path2, echo = TRUE)
  expect_message(eval(quote(DT[mpg > 20]), env), "filter: removed 18 rows")
  suppressMessages(dt_log_end())
  expect_true(any(grepl("^filter: removed 18 rows", readLines(path2))))
})

test_that("nothing is written before the start or after the end", {
  env <- fresh_env()
  quiet(eval(quote(DT[mpg > 20]), env))          # before

  path <- tempfile(fileext = ".txt")
  dt_log(path, echo = FALSE)
  eval(quote(DT[cyl == 4]), env)
  suppressMessages(dt_log_end())

  quiet(eval(quote(DT[mpg > 15]), env))          # after
  lines <- readLines(path)
  expect_length(grep("^> ", lines), 1L)
  expect_true("> DT[cyl == 4]" %in% lines)
})

test_that("append and overwrite behave as documented", {
  env <- fresh_env()
  path <- tempfile(fileext = ".txt")

  dt_log(path, echo = FALSE)
  eval(quote(DT[mpg > 20]), env)
  suppressMessages(dt_log_end())
  first <- length(readLines(path))

  dt_log(path, append = TRUE, echo = FALSE)
  eval(quote(DT[mpg > 20]), env)
  suppressMessages(dt_log_end())
  expect_gt(length(readLines(path)), first)

  dt_log(path, echo = FALSE)
  eval(quote(DT[mpg > 20]), env)
  suppressMessages(dt_log_end())
  expect_equal(length(readLines(path)), first)
})

test_that("dt_log() rejects arguments that are not flags", {
  expect_error(dt_log(tempfile(), append = data.table::data.table(a = 1)),
               "must be TRUE or FALSE")
  expect_error(dt_log(character()), "must be a single path")
  expect_null(dt_log_file())
})

test_that("dt_log_file() reports the open transcript", {
  expect_null(dt_log_file())
  path <- tempfile(fileext = ".txt")
  dt_log(path, echo = FALSE)
  expect_identical(dt_log_file(), path.expand(path))
  suppressMessages(dt_log_end())
  expect_null(dt_log_file())
  expect_message(dt_log_end(), "no transcript is open")
})

test_that("dt_log(NULL) ends the transcript", {
  path <- tempfile(fileext = ".txt")
  dt_log(path, echo = FALSE)
  expect_identical(suppressMessages(dt_log(NULL)), path.expand(path))
  expect_null(dt_log_file())
})

test_that("a transcript does not change what the operations return", {
  path <- tempfile(fileext = ".txt")
  dt_log(path, echo = FALSE)
  on.exit(suppressMessages(dt_log_end()), add = TRUE)
  for (expr in list(quote(DT[mpg > 20]), quote(DT[, kpl := mpg * 0.425]),
                    quote(merge(DT, OTHER, by = "cyl")), quote(head(DT, 5)))) {
    expect_parity(expr)
  }
})
