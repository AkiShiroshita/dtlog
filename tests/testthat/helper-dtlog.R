dt_native_bracket <- utils::getFromNamespace("[.data.table", "data.table")

# the data.table functions that dtlog redefines
wrapped_names <- function() {
  exports <- getNamespaceExports("dtlog")
  exports[vapply(exports, function(nm) {
    !is.null(tryCatch(utils::getFromNamespace(nm, "data.table"),
                      error = function(e) NULL))
  }, logical(1L))]
}

# an environment that looks like the global environment to dtlog, filled with
# the objects the test expressions use
fresh_env <- function(native = FALSE) {
  env <- new.env(parent = globalenv())
  env$DT <- data.table::as.data.table(mtcars, keep.rownames = "car")
  env$OTHER <- data.table::data.table(
    cyl = c(4, 6), label = c("four", "six")
  )
  env$HALF <- data.table::data.table(cyl = 4, label = "four")
  env$ROLL <- data.table::data.table(t = c(1, 5, 10), v = c("a", "b", "c"),
                                     key = "t")
  env$QUERY <- data.table::data.table(t = c(2, 7), key = "t")
  env$cols <- c("hp", "wt")
  env$WITH_NA <- data.table::data.table(a = c(1, NA, 3), b = c(NA, 2, 3))
  env$WIDE <- data.table::data.table(id = 1:2, p = 3:4, q = 5:6)
  env$LONG <- data.table::melt(
    data.table::data.table(id = 1:2, p = 3:4, q = 5:6), id.vars = "id"
  )
  env$thr <- 20
  env$TMPFILE <- tempfile(fileext = ".csv")
  if (native) {
    # shadow every function dtlog redefines with the original from data.table
    for (nm in wrapped_names()) {
      assign(nm, utils::getFromNamespace(nm, "data.table"), envir = env)
    }
  }
  env
}

# a comparable representation of a result, without the internal self reference
# pointer that differs between two independently created data tables
canonical <- function(x) {
  if (data.table::is.data.table(x)) {
    list(
      columns = as.list(x),
      names = names(x),
      key = data.table::key(x),
      class = class(x),
      indices = data.table::indices(x)
    )
  } else if (is.data.frame(x)) {
    list(columns = as.list(x), names = names(x), class = class(x),
         rownames = rownames(x))
  } else {
    x
  }
}

quiet <- function(code) {
  old <- options(dtlog.display = list())
  on.exit(options(old), add = TRUE)
  force(code)
}

# run the full logging machinery, including for calls made from inside a
# package, but collect the output instead of printing it
loud <- function(code) {
  collected <- character()
  old <- options(dtlog.log_from_packages = TRUE,
                 dtlog.display = list(function(x) collected <<- c(collected, x)))
  on.exit(options(old), add = TRUE)
  force(code)
  invisible(collected)
}

# evaluate an expression the way a user would (from the global environment)
# and check the messages it produces
expect_dtlog_message <- function(expr, regexp, env = fresh_env()) {
  testthat::expect_message(eval(expr, env), regexp)
}

dtlog_messages <- function(expr, env = fresh_env()) {
  out <- character()
  withCallingHandlers(
    eval(expr, env),
    message = function(m) {
      out <<- c(out, sub("\\n$", "", conditionMessage(m)))
      invokeRestart("muffleMessage")
    }
  )
  out
}

# run one expression with and without dtlog and compare everything that is
# observable: the value, its visibility, and the (possibly modified) inputs
expect_parity <- function(expr) {
  logged_env <- fresh_env(native = FALSE)
  native_env <- fresh_env(native = TRUE)
  logged <- quiet(withVisible(eval(expr, logged_env)))
  native <- withVisible(eval(expr, native_env))
  label <- paste(deparse(expr), collapse = " ")
  testthat::expect_identical(
    canonical(logged$value), canonical(native$value),
    label = paste0("value of `", label, "`")
  )
  testthat::expect_identical(
    logged$visible, native$visible,
    label = paste0("visibility of `", label, "`")
  )
  testthat::expect_identical(
    canonical(logged_env$DT), canonical(native_env$DT),
    label = paste0("DT after `", label, "`")
  )
  invisible(TRUE)
}
