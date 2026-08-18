`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- output ----------------------------------------------------------------

display_functions <- function() {
  d <- getOption("dtlog.display", NULL)
  if (is.null(d)) return(list(message))
  if (!is.list(d)) d <- list(d)
  # Anything that is not a function is dropped rather than called. Most log
  # calls run inside try_log() and would swallow the error, but dtlog_summary()
  # does not, and an option set to the wrong thing must not break it.
  d[vapply(d, is.function, logical(1L))]
}

should_display <- function() {
  !isTRUE(.state$paused) && (length(display_functions()) > 0L || sink_active())
}

display <- function(text) {
  sink_write(text)
  if (!sink_active() || isTRUE(.state$sink$echo)) {
    for (f in display_functions()) f(text)
  }
  invisible(NULL)
}

# emit a block of lines, the first one prefixed with `prefix`, the following
# ones indented so that they line up underneath it (as tidylog does)
display_block <- function(prefix, lines) {
  lines <- lines[!vapply(lines, is.null, logical(1L))]
  lines <- unlist(lines, use.names = FALSE)
  if (!length(lines)) return(invisible(NULL))
  pad <- strrep(" ", nchar(prefix))
  for (i in seq_along(lines)) {
    display(paste0(if (i == 1L) prefix else pad, lines[[i]]))
  }
  invisible(NULL)
}

detail_full <- function() {
  !identical(getOption("dtlog.detail", "full"), "compact")
}

# logging must never interfere with the actual computation
try_log <- function(expr) {
  tryCatch(expr, error = function(e) invisible(NULL))
}

# should the call that is currently being evaluated produce output?
should_log_call <- function(pf) {
  if (!should_display()) return(FALSE)
  if (isTRUE(getOption("dtlog.log_from_packages", FALSE))) return(TRUE)
  identical(topenv(pf), globalenv())
}

# ---- formatting ------------------------------------------------------------

fmt_n <- function(n) format(n, big.mark = ",", trim = TRUE, scientific = FALSE)

plural <- function(n, noun, plural_form = paste0(noun, "s")) {
  if (isTRUE(n == 1L)) paste("one", noun) else paste(fmt_n(n), plural_form)
}

percent <- function(n, total) {
  if (is.na(n) || is.na(total) || total == 0) return("NA%")
  p <- n / total * 100
  if (p > 99 && p < 100) return(">99%")
  if (p > 0 && p < 1) return("<1%")
  paste0(round(p), "%")
}

shorten <- function(x, max_length = 25L) {
  x <- as.character(x)
  ifelse(nchar(x) > max_length, paste0(substr(x, 1L, max_length - 2L), ".."), x)
}

format_list <- function(x, max_show = 5L) {
  x <- shorten(x)
  if (length(x) > max_show) {
    paste0(paste(x[seq_len(max_show)], collapse = ", "), ", \u2026")
  } else {
    paste(x, collapse = ", ")
  }
}

get_type <- function(x) {
  if (is.ordered(x)) return("ordered factor")
  if (is.factor(x)) return("factor")
  # IDate extends Date and ITime is stored as an integer, so both have to be
  # tested before the classes they are built on
  if (inherits(x, "IDate")) return("IDate")
  if (inherits(x, "ITime")) return("ITime")
  if (inherits(x, "Date")) return("Date")
  if (inherits(x, c("POSIXct", "POSIXt"))) return("datetime")
  if (is.list(x)) return("list")
  cl <- class(x)[1L]
  if (cl == "numeric") "double" else cl
}

key_suffix <- function(k) {
  if (is.null(k) || !length(k)) "" else paste0(", keyed by (", format_list(k), ")")
}

# ---- column level comparison ----------------------------------------------

# number of values that differ between two vectors of equal length,
# NA if the comparison is not possible
n_changed <- function(old, new) {
  if (length(old) != length(new)) return(NA_integer_)
  if (identical(old, new)) return(0L)
  if (is.list(old) || is.list(new)) {
    return(sum(!vapply(
      seq_along(old),
      function(i) identical(old[[i]], new[[i]]),
      logical(1L)
    )))
  }
  if (is.factor(old)) old <- as.character(old)
  if (is.factor(new)) new <- as.character(new)
  na_old <- is.na(old)
  na_new <- is.na(new)
  # Warnings are silenced rather than treated as failure: the comparison is
  # dtlog's own, so its warnings are noise, but its result is still wanted.
  cmp <- tryCatch(suppressWarnings(old != new), error = function(e) NULL)
  if (is.null(cmp)) return(NA_integer_)
  sum((na_old != na_new) | (!na_old & !na_new & cmp))
}

# A list column is reported as having no NA: is.na() on a list is elementwise
# and says nothing useful about a column whose cells are themselves vectors.
n_na <- function(x) {
  if (is.list(x)) return(0L)
  sum(is.na(x))
}

# "(double) with 130 unique values and 0% NA" -- the value level part of the
# message that tidylog prints for new variables
describe_values <- function(x) {
  if (!detail_full()) return(sprintf("(%s)", get_type(x)))
  n <- length(x)
  unique_values <- tryCatch(
    if (is.list(x)) NA_integer_ else data.table::uniqueN(x),
    error = function(e) NA_integer_
  )
  na <- n_na(x)
  if (is.na(unique_values)) {
    sprintf("(%s) with %s NA", get_type(x), percent(na, n))
  } else {
    sprintf(
      "(%s) with %s and %s NA",
      get_type(x), plural(unique_values, "unique value"), percent(na, n)
    )
  }
}

# "11 new NAs", "one fewer NA" -- the wording tidylog uses for changed values
na_text <- function(old, new) {
  delta <- n_na(new) - n_na(old)
  mid <- if (delta >= 0) "new " else "fewer "
  if (abs(delta) == 1L) paste0("one ", mid, "NA") else
    paste0(fmt_n(abs(delta)), " ", mid, "NAs")
}

# tidylog keeps this one singular after a type conversion
na_text_converted <- function(old, new) {
  delta <- n_na(new) - n_na(old)
  sprintf("%s %s NA", fmt_n(abs(delta)), if (delta >= 0) "new" else "fewer")
}
