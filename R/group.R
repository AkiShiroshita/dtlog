#' Aggregate over several grouping sets, with a log
#'
#' [data.table::rollup()], [data.table::cube()] and
#' [data.table::groupingsets()] run one aggregation per grouping set and stack
#' the results. Each reports the size of the table it produced next to the size
#' of the table it started from, in the wording an aggregating `j` uses.
#'
#' @param x The data table to aggregate.
#' @param ... All other arguments, as in the corresponding `data.table`
#'   function.
#' @return Whatever the `data.table` function returns.
#' @examples
#' dt <- data.table::data.table(g = c("a", "a", "b"), h = c("x", "y", "x"),
#'                              v = 1:3)
#' data.table::rollup(dt, j = sum(v), by = c("g", "h"))
#' data.table::cube(dt, j = sum(v), by = c("g", "h"))
#' @name grouping_sets
NULL

#' @rdname grouping_sets
#' @rawNamespace export("rollup")
rollup <- function(x, ...) {
  logged("rollup", sys.call(), parent.frame(), log_grouping_sets("rollup"),
         if (missing(x)) NULL else list(x = x), quiet = TRUE)
}

#' @rdname grouping_sets
#' @rawNamespace export("cube")
cube <- function(x, ...) {
  logged("cube", sys.call(), parent.frame(), log_grouping_sets("cube"),
         if (missing(x)) NULL else list(x = x), quiet = TRUE)
}

#' @rdname grouping_sets
#' @rawNamespace export("groupingsets")
groupingsets <- function(x, ...) {
  logged("groupingsets", sys.call(), parent.frame(),
         log_grouping_sets("groupingsets"),
         if (missing(x)) NULL else list(x = x), quiet = TRUE)
}

# How many grouping sets there were is not read off the call: rollup() and
# cube() are declared as function(x, ...) and work the sets out from `by`,
# which may be given positionally, by name, or not at all. The shape of the
# result is the part that is always true, and it is the part that says whether
# the aggregation did what was meant.
log_grouping_sets <- function(fun) {
  function(out, before, cl, pf) {
    if (!is.data.frame(out)) return(invisible(NULL))
    was <- before$x
    display(sprintf(
      "%s: now %s and %s%s", fun,
      plural(nrow(out), "row"), plural(ncol(out), "column"),
      if (is.null(was)) "" else sprintf(
        " (was %s and %s)", plural(was$nrow, "row"), plural(was$ncol, "column")
      )
    ))
  }
}

#' Split a data table, with a log
#'
#' Reports how many tables the rows were split into, and how many rows each of
#' them holds.
#'
#' @param x The data table to split.
#' @param f The grouping factor, as in [base::split()]. `data.table`'s own
#'   `by=` is the usual way to give it instead.
#' @param drop Whether to drop unused levels, as in [base::split()].
#' @param ... All other arguments of `data.table`'s `split()` method, i.e.
#'   `by`, `sorted`, `keep.by` and `flatten`.
#' @return The list of data tables that `data.table` returns.
#' @examples
#' dt <- data.table::data.table(g = c("a", "a", "b"), v = 1:3)
#' split(dt, by = "g")
#' @rawNamespace export("split.data.table")
#' @export
split.data.table <- function(x, f, drop = FALSE, ...) {
  logged("split.data.table", sys.call(), parent.frame(), log_split,
         if (missing(x)) NULL else list(x = x))
}

log_split <- function(out, before, cl, pf) {
  # a data.frame is a list, and is not what a split returns
  if (!is.list(out) || is.data.frame(out)) return(invisible(NULL))
  was <- before$x
  from <- if (is.null(was)) "the table" else plural(was$nrow, "row")
  rows <- vapply(out, function(part) {
    if (is.data.frame(part)) nrow(part) else NA_integer_
  }, integer(1L))
  # split(flatten = FALSE) nests one list inside another, and then there is no
  # row count to report for the parts
  if (anyNA(rows)) {
    return(display(sprintf("split: %s into %s", from, plural(length(out), "table"))))
  }
  sizes <- vapply(rows, function(n) plural(n, "row"), character(1L))
  labels <- if (is.null(names(out))) sizes else sprintf("%s: %s", names(out), sizes)
  display(sprintf(
    "split: %s into %s (%s)", from, plural(length(out), "table"),
    format_list(labels)
  ))
}
