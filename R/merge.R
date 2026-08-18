#' Merge two data tables, with a log
#'
#' Reports the columns the merge added and how the rows of the two inputs were
#' matched, in the style of `tidylog`'s join messages. The counts of unmatched
#' rows are only computed when `options(dtlog.detail = "full")` (the default);
#' they cost two additional matching passes over the inputs.
#'
#' @param x,y The data tables to merge.
#' @param ... All other arguments of [data.table::merge.data.table()].
#' @return The merged data table, exactly as [data.table::merge.data.table()]
#'   returns it.
#' @examples
#' a <- data.table::data.table(id = 1:3, v = 1:3)
#' b <- data.table::data.table(id = 2:4, w = 4:6)
#' merge(a, b, by = "id")
#' @rawNamespace export("merge.data.table")
#' @export
merge.data.table <- function(x, y, ...) {
  values <- list()
  if (!missing(x)) values$x <- x
  if (!missing(y)) values$y <- y
  logged("merge.data.table", sys.call(), parent.frame(), log_merge, values)
}

log_merge <- function(out, before, cl, pf) {
  x <- before$x
  y <- before$y
  if (is.null(x) || is.null(out)) return(invisible(NULL))
  added <- setdiff(names(out), x$names)
  type <- join_type(cl, pf)
  first <- sprintf(
    "added %s%s", plural(length(added), "column"),
    if (length(added)) sprintf(" (%s)", format_list(added)) else ""
  )
  stats <- if (detail_full()) try_log(join_stats(x, y, cl, pf)) else NULL
  written <- before$.call %||% cl
  rest <- if (is.null(stats)) {
    list(row_change(x$nrow, nrow(out)))
  } else {
    join_lines(stats, nrow(out), type, x$nrow, y$nrow,
               arg_label(written, "x"), arg_label(written, "y"))
  }
  display_block(paste0(type, ": "), c(list(first), rest))
}

join_type <- function(cl, pf) {
  get_flag <- function(name) {
    expr <- matched_arg(cl, "merge.data.table", name)
    if (is.null(expr)) return(NULL)
    isTRUE(tryCatch(eval(expr, pf), error = function(e) FALSE))
  }
  all <- get_flag("all")
  all_x <- get_flag("all.x") %||% all %||% FALSE
  all_y <- get_flag("all.y") %||% all %||% FALSE
  if (all_x && all_y) "full_join" else
    if (all_x) "left_join" else
      if (all_y) "right_join" else "inner_join"
}

# the columns the two tables are matched on
merge_by <- function(x, y, cl, pf) {
  value <- function(name) {
    expr <- matched_arg(cl, "merge.data.table", name)
    if (is.null(expr)) return(NULL)
    v <- tryCatch(eval(expr, pf), error = function(e) NULL)
    if (is.character(v)) v else NULL
  }
  by <- value("by")
  by_x <- value("by.x") %||% by
  by_y <- value("by.y") %||% by
  if (is.null(by_x) || is.null(by_y)) {
    common <- intersect(x$names, y$names)
    if (!length(common)) return(NULL)
    by_x <- by_y <- common
  }
  if (length(by_x) != length(by_y)) return(NULL)
  list(x = by_x, y = by_y)
}

join_stats <- function(x, y, cl, pf) {
  if (is.null(y) || is.null(x$obj) || is.null(y$obj)) return(NULL)
  by <- merge_by(x, y, cl, pf)
  if (is.null(by)) return(NULL)
  bracket <- .dt$bracket
  # for every row of x the first matching row of y, and the other way round
  match_x <- bracket(y$obj, x$obj, on = stats::setNames(by$x, by$y),
                     which = TRUE, mult = "first", nomatch = NA)
  match_y <- bracket(x$obj, y$obj, on = stats::setNames(by$y, by$x),
                     which = TRUE, mult = "first", nomatch = NA)
  list(
    only_x = sum(is.na(match_x)),
    only_y = sum(is.na(match_y)),
    matched_x = sum(!is.na(match_x)),
    matched_y = sum(!is.na(match_y))
  )
}

# how the two tables were called, for the labels of the summary block
arg_label <- function(cl, arg) {
  expr <- matched_arg(cl, "merge.data.table", arg)
  label <- if (is.null(expr)) arg else deparse_short(expr)
  if (!nzchar(label) || label %in% c(".", "x", "y")) arg else shorten(label, 20L)
}

# the same layout tidylog uses: rows that the join type throws away are shown
# in parentheses
join_lines <- function(stats, total, type, nrow_x, nrow_y,
                       name_x = "x", name_y = "y") {
  drop_x <- type %in% c("inner_join", "right_join")
  drop_y <- type %in% c("inner_join", "left_join")
  # the rows of the result that come from a match, the way tidylog counts them
  matched <- switch(type,
    inner_join = total,
    left_join = total - stats$only_x,
    right_join = total - stats$only_y,
    total - stats$only_x - stats$only_y
  )
  base <- if (identical(type, "right_join")) {
    nrow_y - stats$only_y
  } else {
    nrow_x - stats$only_x
  }
  duplicated_matches <- matched > base
  num_width <- max(nchar(fmt_n(c(stats$only_x, stats$only_y, matched, total))))
  fmt <- function(n, dropped) {
    padded <- formatC(fmt_n(n), width = num_width)
    if (dropped) paste0("(", padded, ")") else padded
  }
  values <- c(fmt(stats$only_x, drop_x), fmt(stats$only_y, drop_y),
              fmt_n(matched), fmt_n(total))
  width <- num_width + 2L
  labels <- c(paste("rows only in", name_x), paste("rows only in", name_y),
              "matched rows", "rows total")
  label_width <- max(nchar(labels))
  line <- function(i, note = "") {
    sprintf("> %-*s %*s%s", label_width, labels[i], width, values[i], note)
  }
  c(
    line(1L), line(2L),
    line(3L, if (duplicated_matches) "    (includes duplicates)" else ""),
    sprintf("> %-*s %s", label_width, "", strrep("=", width)),
    line(4L)
  )
}
