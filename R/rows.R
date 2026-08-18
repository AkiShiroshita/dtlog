#' Row operations with a log
#'
#' These functions behave exactly like their `data.table` counterparts and
#' report how many rows they removed, kept or combined.
#'
#' @param x,y,object,l The inputs, as in the corresponding `data.table`
#'   function.
#' @param ... All other arguments, passed on unchanged.
#' @return Whatever the `data.table` function returns.
#' @examples
#' dt <- data.table::data.table(a = c(1, 1, 2), b = c(NA, 2, 3))
#' unique(dt, by = "a")
#' stats::na.omit(dt)
#' @name rows
NULL

#' @rdname rows
#' @rawNamespace export("unique.data.table")
#' @export
unique.data.table <- function(x, ...) {
  logged("unique.data.table", sys.call(), parent.frame(), log_unique,
         if (missing(x)) NULL else list(x = x))
}

log_unique <- function(out, before, cl, pf) {
  if (is.null(before$x) || !is.data.frame(out)) return(invisible(NULL))
  display(paste0("distinct: ", rows_removed(before$x$nrow, nrow(out))))
}

#' @rdname rows
#' @rawNamespace export("duplicated.data.table")
#' @export
duplicated.data.table <- function(x, ...) {
  logged("duplicated.data.table", sys.call(), parent.frame(), log_duplicated,
         if (missing(x)) NULL else list(x = x))
}

log_duplicated <- function(out, before, cl, pf) {
  if (!is.logical(out)) return(invisible(NULL))
  n <- sum(out)
  display(sprintf(
    "duplicated: %s of %s marked as duplicates (%s)",
    fmt_n(n), plural(length(out), "row"), percent(n, length(out))
  ))
}

#' @rdname rows
#' @rawNamespace export("na.omit.data.table")
#' @export
na.omit.data.table <- function(object, ...) {
  logged("na.omit.data.table", sys.call(), parent.frame(), log_na_omit,
         if (missing(object)) NULL else list(object = object))
}

log_na_omit <- function(out, before, cl, pf) {
  if (is.null(before$object) || !is.data.frame(out)) return(invisible(NULL))
  invert <- isTRUE(tryCatch(eval(matched_arg(cl, "na.omit.data.table", "invert"), pf),
                            error = function(e) FALSE))
  if (invert) {
    return(display(sprintf(
      "na.omit (invert): kept the %s with NA (%s)",
      plural(nrow(out), "row"), percent(nrow(out), before$object$nrow)
    )))
  }
  display(paste0("drop_na: ", rows_removed(before$object$nrow, nrow(out))))
}

#' @rdname rows
#' @rawNamespace export("rbindlist")
rbindlist <- function(l, ...) {
  logged("rbindlist", sys.call(), parent.frame(), log_rbindlist,
         if (missing(l)) NULL else list(l = l))
}

log_rbindlist <- function(out, before, cl, pf) {
  if (!is.data.frame(out)) return(invisible(NULL))
  parts <- before$l$obj
  n_parts <- if (is.list(parts) && !is.data.frame(parts)) length(parts) else NA_integer_
  display(sprintf(
    "rbindlist: %s into %s and %s",
    if (is.na(n_parts)) "combined tables" else paste("combined", plural(n_parts, "table")),
    plural(nrow(out), "row"), plural(ncol(out), "column")
  ))
}

#' @rdname rows
#' @rawNamespace export("funion")
funion <- function(x, y, ...) {
  logged("funion", sys.call(), parent.frame(), log_set_op("funion"),
         set_op_values(x, y))
}

#' @rdname rows
#' @rawNamespace export("fintersect")
fintersect <- function(x, y, ...) {
  logged("fintersect", sys.call(), parent.frame(), log_set_op("fintersect"),
         set_op_values(x, y))
}

#' @rdname rows
#' @rawNamespace export("fsetdiff")
fsetdiff <- function(x, y, ...) {
  logged("fsetdiff", sys.call(), parent.frame(), log_set_op("fsetdiff"),
         set_op_values(x, y))
}

set_op_values <- function(x, y) {
  values <- list()
  if (!missing(x)) values$x <- x
  if (!missing(y)) values$y <- y
  values
}

log_set_op <- function(fun) {
  function(out, before, cl, pf) {
    if (!is.data.frame(out)) return(invisible(NULL))
    if (is.null(before$x) || is.null(before$y)) {
      return(display(sprintf("%s: now %s", fun, plural(nrow(out), "row"))))
    }
    display(sprintf(
      "%s: %s and %s in, %s out",
      fun, plural(before$x$nrow, "row"), plural(before$y$nrow, "row"),
      plural(nrow(out), "row")
    ))
  }
}

#' Convert an object to a data table, with a log
#'
#' @param x The object to convert.
#' @param ... All other arguments of [data.table::as.data.table()].
#' @return The `data.table` that [data.table::as.data.table()] returns.
#' @examples
#' data.table::as.data.table(head(mtcars, 3), keep.rownames = "car")
#' @rawNamespace export("as.data.table")
as.data.table <- function(x, ...) {
  logged("as.data.table", sys.call(), parent.frame(), log_as_data_table,
         if (missing(x)) NULL else list(x = x))
}

log_as_data_table <- function(out, before, cl, pf) {
  if (!is.data.frame(out)) return(invisible(NULL))
  from <- if (is.null(before$x)) "input" else before$x$class
  known <- before$x$names %||% character()
  added <- if (length(known)) setdiff(names(out), known) else character()
  display(sprintf(
    "as.data.table: converted %s to data.table (%s, %s)%s",
    from, plural(nrow(out), "row"), plural(ncol(out), "column"),
    if (length(added)) sprintf(", added (%s)", format_list(added)) else ""
  ))
}

#' First or last rows of a data table, with a log
#'
#' @param x The data table.
#' @param ... All other arguments of [utils::head()] and [utils::tail()], i.e.
#'   `n`.
#' @return The same rows `data.table` would return.
#' @examples
#' head(data.table::as.data.table(mtcars), 3)
#' @name head_tail
NULL

#' @rdname head_tail
#' @rawNamespace export("head.data.table")
#' @export
head.data.table <- function(x, ...) {
  logged("head.data.table", sys.call(), parent.frame(), log_head_tail("head"),
         if (missing(x)) NULL else list(x = x))
}

#' @rdname head_tail
#' @rawNamespace export("tail.data.table")
#' @export
tail.data.table <- function(x, ...) {
  logged("tail.data.table", sys.call(), parent.frame(), log_head_tail("tail"),
         if (missing(x)) NULL else list(x = x))
}

log_head_tail <- function(fun) {
  function(out, before, cl, pf) {
    if (is.null(before$x) || !is.data.frame(out)) return(invisible(NULL))
    display(paste0(fun, ": ", rows_removed(before$x$nrow, nrow(out))))
  }
}
