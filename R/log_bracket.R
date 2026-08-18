`%||%` <- function(x, y) if (is.null(x)) y else x

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
    sprintf("mutate (by %s): ", format_list(by_vars(info)))
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
  # when j aggregates, the number of rows in the result says nothing about how
  # many rows i selected, so the two are reported together instead
  aggregated <- info$has_by ||
    (info$has_j && !j_is_selection(x, info) && nrow(out) != before$nrow)
  if (info$has_i && !aggregated) log_i(out, info, before)
  if (info$has_by) log_group_by(info)
  if (aggregated) return(log_summarize(out, info, before))
  if (info$has_j) log_j(x, out, info, before)
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

log_group_by <- function(info) {
  vars <- by_vars(info)
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

log_j <- function(x, out, info, before) {
  old <- before$names
  new <- names(out)
  dropped <- setdiff(old, new)
  added <- setdiff(new, old)
  same_rows <- identical(nrow(x), nrow(out))
  lines <- list()
  if (length(dropped) && !length(added)) {
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
  if (detail_full() && same_rows && !info$has_i) {
    for (nm in intersect(old, new)) {
      changed <- n_changed(x[[nm]], out[[nm]])
      if (!is.na(changed) && changed > 0L) {
        lines <- c(lines, describe_update(nm, x[[nm]], out[[nm]]))
      }
    }
  }
  prefix <- if (length(added) && !length(intersect(old, new))) {
    "transmute: "
  } else {
    "mutate: "
  }
  if (!length(lines)) {
    if (!identical(new, old)) {
      lines <- list(sprintf("reordered variables (%s)", format_list(new)))
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

by_vars <- function(info) {
  expr <- info$by_expr
  if (is.null(expr)) return(character())
  value <- NULL
  if (is.character(expr)) {
    value <- expr
  } else if (is.name(expr)) {
    resolved <- tryCatch(get0(as.character(expr), envir = info$pf), error = function(e) NULL)
    value <- if (is.character(resolved)) resolved else as.character(expr)
  } else if (is_call_to(expr, c(".", "list", "c"))) {
    parts <- as.list(expr)[-1L]
    nms <- names(parts)
    value <- vapply(seq_along(parts), function(k) {
      if (!is.null(nms) && nzchar(nms[k])) nms[k] else deparse_short(parts[[k]])
    }, character(1L))
  } else {
    value <- deparse_short(expr)
  }
  value
}

# `on = "cyl"` and `on = .(cyl)` should both read as `on cyl`
format_on <- function(expr) {
  value <- tryCatch(eval(expr, envir = baseenv()), error = function(e) NULL)
  if (is.character(value)) {
    nms <- names(value)
    if (!is.null(nms)) value <- ifelse(nzchar(nms), paste(nms, value, sep = " == "), value)
    return(format_list(unname(value)))
  }
  deparse_short(expr)
}

deparse_short <- function(expr) {
  shorten(paste(deparse(expr, width.cutoff = 200L), collapse = " "), 40L)
}
