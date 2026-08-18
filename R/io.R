#' Read a file into a data table, with a log
#'
#' @param ... All arguments of [data.table::fread()].
#' @return The data table that [data.table::fread()] returns.
#' @examples
#' fread(text = "a,b\n1,2\n3,4")
#' @rawNamespace export("fread")
fread <- function(...) {
  logged("fread", sys.call(), parent.frame(), log_fread,
         args = c("input", "file"), match = TRUE)
}

log_fread <- function(out, before, cl, pf) {
  if (!is.data.frame(out)) return(invisible(NULL))
  source <- before$input$obj %||% before$file$obj
  display(sprintf(
    "fread: read %s and %s%s",
    plural(nrow(out), "row"), plural(ncol(out), "column"),
    if (is_path(source)) sprintf(" from '%s'", shorten(basename(source), 40L)) else ""
  ))
}

# a single, non-empty string, i.e. something that could name a file
is_file_string <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

# input= can be a path or the data itself. data.table decides between the two
# on the presence of a line break, so dtlog does the same rather than printing
# a csv into the log message. The length cap on top of that is dtlog's own: a
# long single line of data carries no line break either, and no file name worth
# printing is that long. fwrite()'s file= is never ambiguous in this way, so it
# only needs is_file_string().
is_path <- function(x) {
  is_file_string(x) &&
    nchar(x) < 100L && !grepl("[\r\n]", x)
}

#' Write a data table to a file, with a log
#'
#' @param x The table to write.
#' @param ... All other arguments of [data.table::fwrite()].
#' @return `NULL`, invisibly, as [data.table::fwrite()] returns it.
#' @examples
#' dt <- data.table::data.table(a = 1:2, b = 3:4)
#' fwrite(dt, tempfile())
#' @rawNamespace export("fwrite")
fwrite <- function(x, ...) {
  logged("fwrite", sys.call(), parent.frame(), log_fwrite,
         if (missing(x)) NULL else list(x = x),
         args = c("file", "append"), match = TRUE)
}

log_fwrite <- function(out, before, cl, pf) {
  x <- before$x
  if (is.null(x)) return(invisible(NULL))
  appended <- isTRUE(before$append$obj)
  target <- before$file$obj
  display(sprintf(
    "fwrite: %s %s and %s%s",
    if (appended) "appended" else "wrote",
    plural(x$nrow, "row"), plural(x$ncol, "column"),
    if (is_file_string(target)) {
      sprintf(" to '%s'", shorten(basename(target), 40L))
    } else ""
  ))
}
