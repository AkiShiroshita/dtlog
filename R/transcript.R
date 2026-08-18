#' Write the code and its log to a text file
#'
#' `dt_log()` starts a transcript: from that point on, every operation that
#' dtlog reports is appended to a text file, together with the call that
#' produced it. `dt_log_end()` closes the transcript. Start and end are up to
#' you; nothing is written before the first call or after the second.
#'
#' The file is written with plain [cat()] and is flushed after every
#' operation, so it stays readable while a long script is running and survives
#' a session that ends without `dt_log_end()` (only the closing line is then
#' missing).
#'
#' @param file Path of the text file. `NULL` ends the current transcript, so
#'   `dt_log(NULL)` is the same as `dt_log_end()`.
#' @param append Append to an existing file instead of overwriting it.
#' @param code Write the call above its log. Set to `FALSE` for the messages
#'   alone.
#' @param echo Keep printing to the console as well. `FALSE` writes only to
#'   the file.
#' @return The path of the transcript, invisibly.
#' @examples
#' path <- tempfile(fileext = ".txt")
#' dt_log(path, echo = FALSE)
#' dt <- data.table::as.data.table(mtcars)
#' dt[mpg > 20]
#' dt[, kpl := mpg * 0.425]
#' dt_log_end()
#' cat(readLines(path), sep = "\n")
#' @export
dt_log <- function(file = "dtlog.txt", append = FALSE, code = TRUE, echo = TRUE) {
  if (is.null(file)) return(dt_log_end())
  flag <- function(x) is.logical(x) && length(x) == 1L && !is.na(x)
  if (!is.character(file) || length(file) != 1L || !nzchar(file)) {
    stop("dt_log(): `file` must be a single path, or NULL to end the transcript",
         call. = FALSE)
  }
  if (!flag(append) || !flag(code) || !flag(echo)) {
    stop("dt_log(): `append`, `code` and `echo` must be TRUE or FALSE",
         call. = FALSE)
  }
  if (!is.null(.state$sink)) dt_log_end()
  path <- path.expand(file)
  if (!append && file.exists(path)) file.remove(path)
  .state$sink <- list(path = path, code = isTRUE(code), echo = isTRUE(echo), n = 0L)
  write_lines(c(
    sprintf("# dtlog transcript, started %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    sprintf("# %s, data.table %s, dtlog %s",
            R.version.string,
            utils::packageVersion("data.table"),
            utils::packageVersion("dtlog"))
  ))
  invisible(path)
}

#' @rdname dt_log
#' @export
dt_log_end <- function() {
  sink_state <- .state$sink
  if (is.null(sink_state)) {
    message("dt_log: no transcript is open")
    return(invisible(NULL))
  }
  write_lines(c("", sprintf(
    "# dtlog transcript, ended %s (%s)",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    plural(sink_state$n, "operation")
  )))
  .state$sink <- NULL
  message(sprintf("dt_log: wrote %s to '%s'",
                  plural(sink_state$n, "operation"), sink_state$path))
  invisible(sink_state$path)
}

#' @rdname dt_log
#' @export
dt_log_file <- function() {
  if (is.null(.state$sink)) NULL else .state$sink$path
}

# ---- internals -------------------------------------------------------------

sink_active <- function() !is.null(.state$sink)

write_lines <- function(lines) {
  cat(paste0(lines, "\n", collapse = ""), file = .state$sink$path, append = TRUE)
}

# remember which call is being logged, so that the transcript can show it
with_logged_call <- function(call, expr) {
  old_call <- .state$call
  old_written <- .state$call_written
  .state$call <- call
  .state$call_written <- FALSE
  on.exit({
    .state$call <- old_call
    .state$call_written <- old_written
  }, add = TRUE)
  expr
}

# one message, on its way to the transcript
sink_write <- function(text) {
  if (!sink_active()) return(invisible(NULL))
  lines <- character()
  if (!isTRUE(.state$call_written)) {
    .state$call_written <- TRUE
    .state$sink$n <- .state$sink$n + 1L
    if (.state$sink$code) {
      lines <- c(if (.state$sink$n > 1L) "" else NULL, format_call(.state$call))
    } else if (.state$sink$n > 1L) {
      lines <- ""
    }
  }
  write_lines(c(lines, text))
  invisible(NULL)
}

# the call as the user wrote it, in the style of a console transcript
format_call <- function(call) {
  if (is.null(call)) return("> <call unavailable>")
  txt <- deparse(readable_call(call), width.cutoff = 80L)
  paste0(c("> ", rep("+ ", length(txt) - 1L)), txt)
}

# S3 dispatch leaves the name of the method in the call. Turn
# `[.data.table`(dt, i) back into dt[i], and head.data.table(dt) into head(dt).
dispatched_methods <- c(
  "[.data.table" = "[", "head.data.table" = "head", "tail.data.table" = "tail",
  "merge.data.table" = "merge", "unique.data.table" = "unique",
  "duplicated.data.table" = "duplicated", "na.omit.data.table" = "na.omit"
)

readable_call <- function(call) {
  if (!is.call(call) || !is.name(call[[1L]])) return(call)
  generic <- unname(dispatched_methods[as.character(call[[1L]])])
  if (!is.na(generic)) call[[1L]] <- as.name(generic)
  call
}
