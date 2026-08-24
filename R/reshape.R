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
#' @method melt data.table
#' @rawNamespace export("melt.data.table")
#' @export
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
#' @method dcast data.table
#' @rawNamespace export("dcast.data.table")
#' @export
dcast.data.table <- function(data, ...) {
  logged("dcast.data.table", sys.call(), parent.frame(), log_dcast,
         if (missing(data)) NULL else list(data = data))
}

log_melt <- function(out, before, cl, pf) {
  log_reshape("melt", out, before$data, melted_columns(out, before$data))
}

log_dcast <- function(out, before, cl, pf) {
  log_reshape("dcast", out, before$data)
}

# The columns melt() actually stacked -- everything else that disappeared was
# simply dropped. They are read off the result rather than off measure.vars:
# melt() runs substitute() on that argument and resolves it against the column
# names itself, so evaluating it here would both run it a second time and risk
# resolving it against the caller's variables instead. The variable column of
# the result names the stacked columns and nothing else, whatever form
# measure.vars took -- names, numbers or patterns().
#
# melt() writes the variable column before the value columns, so it is the
# first column of the result that was not in the input, and it counts only if
# every one of its values is the name of a column that disappeared. Otherwise
# the answer is NULL and nothing is reported as dropped, rather than the wrong
# columns being reported: that is what happens for the list form of a
# multi-value melt, whose variable column holds group numbers, not names.
melted_columns <- function(out, before) {
  if (is.null(before) || !is.data.frame(out)) return(NULL)
  gone <- setdiff(before$names, names(out))
  new <- setdiff(names(out), before$names)
  if (!length(gone) || !length(new)) return(NULL)
  column <- out[[new[1L]]]
  seen <- if (is.factor(column)) levels(column) else
    if (is.character(column)) unique(column) else NULL
  if (length(seen) && all(seen %in% gone)) seen else NULL
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
