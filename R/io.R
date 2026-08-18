#' Read a file into a data table, with a log
#'
#' @param ... All arguments of [data.table::fread()].
#' @return The data table that [data.table::fread()] returns.
#' @examples
#' data.table::fread(text = "a,b\n1,2\n3,4")
#' @rawNamespace export("fread")
fread <- function(...) {
  logged("fread", sys.call(), parent.frame(), log_fread)
}

log_fread <- function(out, before, cl, pf) {
  if (!is.data.frame(out)) return(invisible(NULL))
  source <- tryCatch({
    expr <- matched_arg(cl, "fread", "input")
    if (is.null(expr)) expr <- matched_arg(cl, "fread", "file")
    if (is.null(expr)) NULL else eval(expr, pf)
  }, error = function(e) NULL)
  display(sprintf(
    "fread: read %s and %s%s",
    plural(nrow(out), "row"), plural(ncol(out), "column"),
    if (is.character(source) && length(source) == 1L && nchar(source) < 100L) {
      sprintf(" from '%s'", shorten(basename(source), 40L))
    } else ""
  ))
}

#' Write a data table to a file, with a log
#'
#' @param x The table to write.
#' @param ... All other arguments of [data.table::fwrite()].
#' @return `NULL`, invisibly, as [data.table::fwrite()] returns it.
#' @examples
#' dt <- data.table::data.table(a = 1:2, b = 3:4)
#' data.table::fwrite(dt, tempfile())
#' @rawNamespace export("fwrite")
fwrite <- function(x, ...) {
  logged("fwrite", sys.call(), parent.frame(), log_fwrite,
         if (missing(x)) NULL else list(x = x))
}

log_fwrite <- function(out, before, cl, pf) {
  x <- before$x
  if (is.null(x)) return(invisible(NULL))
  appended <- isTRUE(tryCatch(eval(matched_arg(cl, "fwrite", "append"), pf),
                              error = function(e) FALSE))
  target <- tryCatch(eval(matched_arg(cl, "fwrite", "file"), pf),
                     error = function(e) NULL)
  display(sprintf(
    "fwrite: %s %s and %s%s",
    if (appended) "appended" else "wrote",
    plural(x$nrow, "row"), plural(x$ncol, "column"),
    if (is.character(target) && length(target) == 1L && nzchar(target)) {
      sprintf(" to '%s'", shorten(basename(target), 40L))
    } else ""
  ))
}
