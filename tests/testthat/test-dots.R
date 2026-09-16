# A call that reaches dtlog through a function which passes its own dots on
# arrives as FUN(X[[i]], ...). That `...` belongs to the caller, not to the
# wrapper, and dtlog has to re-evaluate the call without mistaking it for the
# dots of its own function(...) signature.

two_csv_files <- function() {
  dir <- file.path(tempdir(), "dtlog-dots")
  dir.create(dir, showWarnings = FALSE)
  paths <- file.path(dir, c("first.csv", "second.csv"))
  writeLines(c("a;b", "1;2"), paths[1L])
  writeLines(c("a;c", "3;4"), paths[2L])
  paths
}

test_that("fread() works when lapply() passes it the file name", {
  env <- fresh_env()
  env$FILES <- two_csv_files()
  on.exit(unlink(dirname(env$FILES[1L]), recursive = TRUE), add = TRUE)

  out <- suppressMessages(eval(quote(
    rbindlist(lapply(FILES, fread), use.names = TRUE, fill = TRUE)
  ), env))
  native <- data.table::rbindlist(lapply(env$FILES, data.table::fread),
                                  use.names = TRUE, fill = TRUE)
  expect_identical(canonical(out), canonical(native))
})

test_that("an argument passed through the dots keeps the caller's environment", {
  # the ..1 dtlog writes into the call must be the caller's promise, not the
  # expression pulled out of it: `sep_local` lives in the caller's frame, and
  # nowhere along the chain dtlog evaluates the call in
  env <- fresh_env()
  env$FILES <- two_csv_files()
  env$sep_local <- ";"
  on.exit(unlink(dirname(env$FILES[1L]), recursive = TRUE), add = TRUE)

  out <- suppressMessages(eval(quote(lapply(FILES, fread, sep = sep_local)), env))
  native <- lapply(env$FILES, data.table::fread, sep = ";")
  expect_identical(lapply(out, canonical), lapply(native, canonical))

  env$call_with_dots <- function(f, ...) f(...)
  out <- suppressMessages(
    eval(quote(call_with_dots(fread, FILES[1L], sep = sep_local)), env)
  )
  expect_identical(canonical(out),
                   canonical(data.table::fread(env$FILES[1L], sep = ";")))
})

test_that("a call arriving through the dots is still logged and described", {
  env <- fresh_env()
  env$FILES <- two_csv_files()
  on.exit(unlink(dirname(env$FILES[1L]), recursive = TRUE), add = TRUE)

  messages <- loud(eval(quote(lapply(FILES, fread)), env))
  expect_match(messages, "fread: read one row and 2 columns from 'first.csv'",
               fixed = TRUE, all = FALSE)
  expect_match(messages, "from 'second.csv'", fixed = TRUE, all = FALSE)

  env$forward <- function(...) fwrite(...)
  messages <- loud(eval(quote(forward(OTHER, TMPFILE)), env))
  expect_match(messages, "fwrite: wrote 2 rows and 2 columns", all = FALSE)
})
