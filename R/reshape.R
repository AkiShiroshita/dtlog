#' Reshape a data table, with a log
#'
#' Reports which columns were reorganized into which, and how the dimensions
#' of the table changed, in the style of `tidylog`'s `pivot_longer()` and
#' `pivot_wider()` messages.
#'
#' @param data The table to reshape.
#' @param ... All other arguments of [data.table::melt.data.table()] and
#'   [data.table::dcast.data.table()].
#' @return The reshaped data table.
#' @examples
#' dt <- data.table::data.table(id = 1:2, a = 3:4, b = 5:6)
#' long <- data.table::melt(dt, id.vars = "id")
#' data.table::dcast(long, id ~ variable)
#' @name reshape
NULL

#' @rdname reshape
#' @rawNamespace export("melt")
melt <- function(data, ...) {
  logged("melt", sys.call(), parent.frame(), log_melt,
         if (missing(data)) NULL else list(data = data))
}

#' @rdname reshape
#' @rawNamespace export("melt.data.table")
melt.data.table <- function(data, ...) {
  logged("melt.data.table", sys.call(), parent.frame(), log_melt,
         if (missing(data)) NULL else list(data = data))
}

#' @rdname reshape
#' @rawNamespace export("dcast")
dcast <- function(data, ...) {
  logged("dcast", sys.call(), parent.frame(), log_dcast,
         if (missing(data)) NULL else list(data = data))
}

#' @rdname reshape
#' @rawNamespace export("dcast.data.table")
dcast.data.table <- function(data, ...) {
  logged("dcast.data.table", sys.call(), parent.frame(), log_dcast,
         if (missing(data)) NULL else list(data = data))
}

log_melt <- function(out, before, cl, pf) {
  log_reshape("melt", out, before$data, melted_columns(cl, pf))
}

log_dcast <- function(out, before, cl, pf) {
  log_reshape("dcast", out, before$data)
}

# the columns melt() actually stacked, when they were given as a plain
# character vector -- everything else that disappeared was simply dropped
melted_columns <- function(cl, pf) {
  expr <- matched_arg(cl, "melt.data.table", "measure.vars")
  if (is.null(expr)) return(NULL)
  value <- tryCatch(eval(expr, pf), error = function(e) NULL)
  if (is.character(value)) value else NULL
}

log_reshape <- function(fun, out, before, melted = NULL) {
  if (!is.data.frame(out)) return(invisible(NULL))
  if (is.null(before)) {
    return(display(sprintf(
      "%s: now %s and %s", fun, plural(nrow(out), "row"),
      plural(ncol(out), "column")
    )))
  }
  gone <- setdiff(before$names, names(out))
  new <- setdiff(names(out), before$names)
  dropped <- if (is.null(melted)) character() else setdiff(gone, melted)
  if (length(dropped)) gone <- setdiff(gone, dropped)
  display(sprintf(
    "%s: reorganized (%s) into (%s) [was %sx%s, now %sx%s]%s",
    fun, format_list(gone), format_list(new),
    before$nrow, before$ncol, nrow(out), ncol(out),
    if (length(dropped)) {
      sprintf(", dropped %s (%s)", plural(length(dropped), "variable"),
              format_list(dropped))
    } else ""
  ))
}
