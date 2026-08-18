#' dtlog: logging for data.table operations
#'
#' `dtlog` provides feedback about `data.table` operations. It redefines the
#' subsetting method `[.data.table` as well as several functions exported by
#' `data.table`, so it should be loaded **after** `data.table`, otherwise there
#' will be no output. A more explicit way to resolve namespace conflicts is to
#' use the `conflicted` package.
#'
#' The operations themselves are never changed: `dtlog` only adds a message.
#' Modification by reference (`:=`, `set*()`), keys, indices, return values and
#' visibility all behave exactly as they do in `data.table`.
#'
#' @section Options:
#' \describe{
#'   \item{`dtlog.display`}{`NULL` (default) prints with [message()]. A list of
#'     functions sends the output to each of them. An empty list turns logging
#'     off.}
#'   \item{`dtlog.detail`}{`"full"` (default) reports value level information
#'     (types, unique values, share of `NA`, number of changed values).
#'     `"compact"` only reports rows, columns and column names, and never
#'     copies data.}
#'   \item{`dtlog.log_from_packages`}{`FALSE` (default) only logs calls made
#'     from the global environment, so that `data.table` calls inside other
#'     packages stay silent.}
#' }
#'
#' @keywords internal
#' @importFrom stats na.omit
#' @importFrom utils head tail
"_PACKAGE"

# tell data.table that this package is data.table aware, see data.table:::cedta
.datatable.aware <- TRUE

# holds the original data.table functions that dtlog wraps
.dt <- new.env(parent = emptyenv())

# TRUE while dtlog_pause() is in effect
.state <- new.env(parent = emptyenv())
.state$paused <- FALSE

.onLoad <- function(libname, pkgname) {
  # [.data.table is an S3 method that data.table does not export
  .dt$bracket <- utils::getFromNamespace("[.data.table", "data.table")
  invisible(NULL)
}

#' Pause and resume logging
#'
#' `dtlog_pause()` turns off all `dtlog` messages without detaching the
#' package, `dtlog_resume()` turns them back on. This is useful for a block of
#' code that would otherwise produce a lot of output.
#'
#' @return Invisibly `TRUE` if logging was enabled before the call.
#' @examples
#' dtlog_pause()
#' dtlog_resume()
#' @export
dtlog_pause <- function() {
  was <- !.state$paused
  .state$paused <- TRUE
  invisible(was)
}

#' @rdname dtlog_pause
#' @export
dtlog_resume <- function() {
  was <- !.state$paused
  .state$paused <- FALSE
  invisible(was)
}

#' Log a summary of a data table
#'
#' Prints the dimensions, the key and the number of columns of a data table,
#' and returns the object unchanged, so that it can be used within a chain of
#' operations.
#'
#' @param .data A `data.table` (or any data frame).
#' @return `.data`, invisibly changed in no way.
#' @seealso [dt_log()] to write a transcript of a whole session to a file.
#' @examples
#' dt <- data.table::data.table(a = 1:3, b = 4:6)
#' dtlog_summary(dt)
#' @export
dtlog_summary <- function(.data) {
  if (should_display()) {
    display(sprintf(
      "dtlog: %s with %s and %s%s",
      class(.data)[1L],
      plural(nrow(.data), "row"),
      plural(ncol(.data), "column"),
      key_suffix(data.table::key(.data))
    ))
  }
  .data
}
