# ---- entry point -----------------------------------------------------------

log_bracket <- function(x, out, info, before) {
  if (is.null(info) || is.null(before) || !should_display()) {
    return(invisible(NULL))
  }
  if (isTRUE(info$is_assign)) return(log_assign(x, info, before))
  if (!info$has_i && !info$has_j) return(invisible(NULL))
  if (!is.data.frame(out)) return(log_non_table(out, info, before))
  if (isTRUE(info$is_join)) return(log_join(out, info, before))
  log_subset(x, out, info, before)
}

# ---- := --------------------------------------------------------------------

log_assign <- function(x, info, before) {
  after_names <- names(x)
  added <- setdiff(after_names, before$names)
  dropped <- setdiff(before$names, after_names)
  prefix <- if (info$has_by) {
    sprintf("mutate (by %s): ", format_list(by_vars(info, before$names)))
  } else {
    "mutate: "
  }
  lines <- list()
  if (length(dropped)) {
    lines <- c(lines, sprintf(
      "dropped %s (%s)", plural(length(dropped), "variable"), format_list(dropped)
    ))
  }
  for (nm in added) {
    lines <- c(lines, sprintf("new variable '%s' %s", nm, describe_values(x[[nm]])))
  }
  updated <- setdiff(intersect(names(before$cols) %||% character(), after_names), added)
  if (length(updated)) {
    for (nm in updated) {
      lines <- c(lines, describe_update(nm, before$cols[[nm]], x[[nm]]))
    }
  } else if (!detail_full() && !length(added) && !length(dropped)) {
    targets <- intersect(info$assign_targets %||% character(), after_names)
    if (length(targets)) {
      lines <- c(lines, sprintf(
        "updated %s (%s)", plural(length(targets), "variable"), format_list(targets)
      ))
    }
  }
  if (!length(lines)) lines <- list("no changes")
  display_block(prefix, lines)
}

describe_update <- function(nm, old, new) {
  type_old <- get_type(old)
  type_new <- get_type(new)
  changed <- n_changed(old, new)
  if (!identical(type_old, type_new)) {
    detail <- if (n_na(new) == length(new) && length(new)) {
      "now 100% NA"
    } else {
      na_text_converted(old, new)
    }
    return(sprintf("converted '%s' from %s to %s (%s)", nm, type_old, type_new, detail))
  }
  if (is.na(changed)) {
    return(sprintf("updated '%s' (%s)", nm, type_new))
  }
  if (changed == 0L) {
    return(sprintf("no changes to '%s'", nm))
  }
  sprintf(
    "changed %s (%s) of '%s' (%s)",
    plural(changed, "value"), percent(changed, length(new)), nm, na_text(old, new)
  )
}

# ---- j returning something that is not a table -----------------------------

log_non_table <- function(out, info, before) {
  if (isTRUE(info$which_true)) {
    n <- length(out)
    return(display(sprintf(
      "which: %s out of %s match (%s)",
      fmt_n(n), plural(before$nrow, "row"), percent(n, before$nrow)
    )))
  }
  if (length(out) == 1L) {
    display(sprintf("summarize: returned one value (%s)", get_type(out)))
  } else {
    display(sprintf(
      "summarize: returned %s of length %s (was %s)",
      get_type(out), fmt_n(length(out)), plural(before$nrow, "row")
    ))
  }
}

# ---- joins -----------------------------------------------------------------

log_join <- function(out, info, before) {
  added <- setdiff(names(out), before$names)
  on <- if (!is.null(info$on)) sprintf(" (on %s)", format_on(info$on)) else ""
  first <- if (length(added)) {
    sprintf("added %s (%s)", plural(length(added), "column"), format_list(added))
  } else {
    "added no columns"
  }
  display_block(sprintf("join%s: ", on),
                list(first, row_change(before$nrow, nrow(out))))
}

row_change <- function(before_n, after_n) {
  if (before_n == after_n) {
    return(sprintf("%s unchanged", plural(after_n, "row")))
  }
  sprintf(
    "rows: was %s, now %s (%s%s)",
    fmt_n(before_n), fmt_n(after_n),
    if (after_n > before_n) "+" else "-", fmt_n(abs(after_n - before_n))
  )
}

# ---- i / j / by ------------------------------------------------------------

log_subset <- function(x, out, info, before) {
  selection <- j_is_selection(x, info)
  # Without by=, a j that aggregates collapses the result into a single row,
  # so a result that still has several rows was shaped by i and the two can be
  # reported one after the other. Where i and an aggregation do meet, the row
  # count of the result says nothing about how many rows i selected, and they
  # are reported together instead. (A j that recycles the rows i selected into
  # a longer result is read as a filter here; that is rare enough to be worth
  # the clearer message in the common case.)
  aggregated <- info$has_by ||
    (info$has_j && !selection && nrow(out) != before$nrow &&
       (!info$has_i || nrow(out) == 1L))
  if (info$has_i && !aggregated) log_i(out, info, before)
  if (info$has_by) log_group_by(info, before$names)
  if (aggregated) return(log_summarize(out, info, before))
  if (info$has_j) log_j(x, out, info, before, selection)
  invisible(NULL)
}

# does j only pick existing columns? then it leaves the rows alone
j_is_selection <- function(x, info) {
  j <- info$j
  if (is.null(j) || isTRUE(info$with_false)) return(TRUE)
  nms <- names(x)
  is_column <- function(e) {
    (is.name(e) && as.character(e) %in% nms) ||
      (is.character(e) && all(e %in% nms))
  }
  if (identical(j, quote(.SD)) || is_column(j)) return(TRUE)
  # DT[, ..cols] reads the column names off a variable one frame up; there is
  # nothing else a `..` prefixed symbol can hold
  if (is.name(j) && startsWith(as.character(j), "..")) return(TRUE)
  # DT[, !c("vs", "am")] and DT[, -c("vs", "am")] drop columns by name, which
  # is a selection too. Only the character forms are: `-mpg` and `!vs` negate
  # the values of a column instead of leaving it out.
  if (is_call_to(j, c("!", "-")) && length(j) == 2L) {
    inner <- j[[2L]]
    parts <- if (is_call_to(inner, "c")) as.list(inner)[-1L] else list(inner)
    return(length(parts) > 0L && all(vapply(
      parts, function(e) is.character(e) && all(e %in% nms), logical(1L)
    )))
  }
  if (is_call_to(j, c(".", "list", "c"))) {
    parts <- as.list(j)[-1L]
    return(length(parts) > 0L && all(vapply(parts, is_column, logical(1L))))
  }
  FALSE
}

log_i <- function(out, info, before) {
  after_n <- nrow(out)
  removed <- before$nrow - after_n
  if (removed == 0L) {
    if (isTRUE(info$is_order)) {
      return(display(sprintf("arrange: reordered %s", plural(after_n, "row"))))
    }
    return(display("filter: no rows removed"))
  }
  if (removed < 0L) {
    return(display(sprintf(
      "filter: added %s, %s total",
      plural(-removed, "row"), plural(after_n, "row")
    )))
  }
  if (after_n == 0L) return(display("filter: removed all rows (100%)"))
  display(sprintf(
    "filter: removed %s (%s), %s remaining",
    plural(removed, "row"), percent(removed, before$nrow), plural(after_n, "row")
  ))
}

log_group_by <- function(info, nms = character()) {
  vars <- by_vars(info, nms)
  display(sprintf(
    "group_by: %s (%s)", plural(length(vars), "grouping variable"), format_list(vars)
  ))
}

log_summarize <- function(out, info, before) {
  display(sprintf(
    "summarize: now %s and %s (was %s and %s%s)",
    plural(nrow(out), "row"), plural(ncol(out), "column"),
    plural(before$nrow, "row"), plural(length(before$names), "column"),
    if (info$has_i) ", after filtering with i" else ""
  ))
}

log_j <- function(x, out, info, before, selection = j_is_selection(x, info)) {
  old <- before$names
  new <- names(out)
  dropped <- setdiff(old, new)
  added <- setdiff(new, old)
  same_rows <- identical(nrow(x), nrow(out))
  lines <- list()
  # only a j that picks existing columns turns into a plain select; one that
  # computes its columns keeps the mutate wording even when every name it
  # returns was already there
  if (selection && length(dropped) && !length(added)) {
    display(sprintf(
      "select: dropped %s (%s)",
      plural(length(dropped), "variable"), format_list(dropped)
    ))
    return(invisible(NULL))
  }
  for (nm in added) {
    lines <- c(lines, sprintf("new variable '%s' %s", nm, describe_values(out[[nm]])))
  }
  if (length(dropped)) {
    lines <- c(lines, sprintf(
      "dropped %s (%s)", plural(length(dropped), "variable"), format_list(dropped)
    ))
  }
  # values can only be compared when the rows still line up, but a column
  # whose type changed is worth a line either way -- and a conversion that
  # leaves the values as they were, as.numeric() on a column of digits,
  # changes no value at all
  comparable <- same_rows && !info$has_i
  if (detail_full()) {
    for (nm in intersect(old, new)) {
      before_col <- x[[nm]]
      after_col <- out[[nm]]
      if (!identical(get_type(before_col), get_type(after_col))) {
        lines <- c(lines, if (comparable) {
          describe_update(nm, before_col, after_col)
        } else {
          sprintf("converted '%s' from %s to %s", nm,
                  get_type(before_col), get_type(after_col))
        })
        next
      }
      if (!comparable) next
      changed <- n_changed(before_col, after_col)
      if (!is.na(changed) && changed > 0L) {
        lines <- c(lines, describe_update(nm, before_col, after_col))
      }
    }
  }
  # a j that only picks existing columns is a select, even when it happens to
  # keep all of them: reporting that as "mutate" would suggest that values
  # were computed. The case where it drops columns is handled above.
  prefix <- if (length(added) && !length(intersect(old, new))) {
    "transmute: "
  } else if (selection && !length(added) && !length(dropped)) {
    "select: "
  } else {
    "mutate: "
  }
  if (!length(lines)) {
    if (!identical(new, old)) {
      lines <- list(sprintf("columns reordered (%s)", format_list(new)))
    } else if (!info$has_i) {
      lines <- list("no changes")
    } else {
      return(invisible(NULL))
    }
  }
  if (nrow(out) != before$nrow && !info$has_i) {
    lines <- c(lines, row_change(before$nrow, nrow(out)))
  }
  display_block(prefix, lines)
}

# ---- helpers ---------------------------------------------------------------

by_vars <- function(info, nms = character()) {
  expr <- info$by_expr
  if (is.null(expr)) return(character())
  value <- NULL
  if (is.character(expr)) {
    value <- expr
  } else if (is.name(expr)) {
    value <- by_symbol(as.character(expr), nms, info$pf)
  } else if (is_call_to(expr, c(".", "list", "c"))) {
    parts <- as.list(expr)[-1L]
    part_nms <- names(parts)
    value <- vapply(seq_along(parts), function(k) {
      if (!is.null(part_nms) && nzchar(part_nms[k])) return(part_nms[k])
      part <- parts[[k]]
      # by = c("cyl", "gear") -- the strings are the column names themselves
      if (is.character(part) && length(part) == 1L) return(part)
      deparse_short(part)
    }, character(1L))
  } else {
    value <- deparse_short(expr)
  }
  value
}

# `by = cyl` groups by the column cyl whenever the table has one, and only
# otherwise by the value of a variable cyl in the caller. That is the order
# data.table uses -- inside by= the columns shadow the calling frame -- so
# resolving the caller first would name the wrong columns in the message.
by_symbol <- function(nm, nms, pf) {
  if (nm %in% nms) return(nm)
  resolved <- tryCatch(get0(nm, envir = pf), error = function(e) NULL)
  if (is.character(resolved)) resolved else nm
}

# `on = "cyl"`, `on = c(x = "y")` and `on = .(cyl)` should all read as column
# names rather than as the expression that was typed
format_on <- function(expr) {
  value <- tryCatch(eval(expr, envir = baseenv()), error = function(e) NULL)
  if (is.character(value)) {
    nms <- names(value)
    if (!is.null(nms)) value <- ifelse(nzchar(nms), paste(nms, value, sep = " == "), value)
    return(format_list(unname(value)))
  }
  # `.()` is data.table's own alias for list() and does not exist outside it,
  # so `.(cyl)` and `.(x == y)` always fail to evaluate; read the parts off the
  # expression instead of falling back to the deparsed call.
  if (is_call_to(expr, c(".", "list"))) {
    parts <- as.list(expr)[-1L]
    nms <- names(parts)
    return(format_list(vapply(seq_along(parts), function(k) {
      label <- deparse_short(parts[[k]])
      if (!is.null(nms) && nzchar(nms[k])) paste(nms[k], label, sep = " == ") else label
    }, character(1L))))
  }
  deparse_short(expr)
}

deparse_short <- function(expr) {
  shorten(paste(deparse(expr, width.cutoff = 200L), collapse = " "), 40L)
}
