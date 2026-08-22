#' Describe the variables of a data table
#'
#' `dttable()` describes a `data.table` rather than cross tabulating it. Given a
#' single `data.table` it reports one row per column -- the name, the number of
#' unique values, and the values themselves -- and returns that description as a
#' `data.table` with the columns `Variable`, `N_unique` and `Unique_value`.
#'
#' `dttable()` is a function of its own: it does not mask [base::table()], and
#' loading `dtlog` leaves `table()` exactly as it was. Every call that is not a
#' single `data.table` is handed to [base::table()] unchanged, so
#' `dttable(dt$sex, dt$death)`, `dttable(x, useNA = "ifany")` and
#' `dttable(as.data.frame(dt))` return what [base::table()] returns. Describing
#' a single `data.table` is the only thing `dttable()` adds.
#'
#' A column with 20 or more unique values is reported as *possibly continuous*
#' rather than listed; the option `dtlog.table_max_unique` moves that point,
#' and `Inf` lists every column however many values it holds. A list column is
#' reported as such, and a list of values longer than 80 characters is
#' truncated.
#'
#' The values are listed in the order the column sorts in: numbers ascending,
#' characters alphabetically, dates and times chronologically, factors and
#' ordered factors by their levels, `FALSE` before `TRUE`. Each value is
#' written the way its own class writes it, so an `ITime` is listed as
#' `09:00:00` rather than as the seconds it is stored as. A type that cannot be
#' sorted keeps the order its values appear in.
#'
#' Missing values are listed and counted like any other value: `NA` (including
#' `NA` as a level of a factor) appears as `Missing`, `NaN` as `NaN`, and both
#' are counted in `N_unique`. They sort last, so a column that has any ends
#' with `Missing`. An empty string is a value of its own, not a missing one.
#'
#' The description goes through the same output as every other `dtlog`
#' message, so it obeys `dtlog.display`, is silenced by [dtlog_pause()], and is
#' written to the transcript opened by [dt_log()].
#'
#' @param ... The vectors to tabulate, as in [base::table()], or a single
#'   `data.table` to describe.
#' @return For a single `data.table`, a `data.table` with the columns
#'   `Variable`, `N_unique` and `Unique_value`, returned invisibly. For
#'   anything else, whatever [base::table()] returns.
#' @seealso [dtlog_summary()] for the size and key of a table alone.
#' @examples
#' dttable(data.table::data.table(a = 1:3, b = c("x", "y", "x")))
#' dttable(c("a", "b", "a"))
#' @export
dttable <- function(...) {
  # ..1 forces the first argument, exactly once: the base branch is handed the
  # same (already evaluated) promise, so an argument with a side effect runs
  # the same number of times as it does in base::table().
  if (...length() == 1L && data.table::is.data.table(..1)) {
    return(describe_table(..1, sys.call()))
  }
  base::table(...)
}

# ---- the description -------------------------------------------------------

describe_table <- function(x, cl) {
  out <- variable_description(x)
  if (should_display()) {
    with_logged_call(cl, try_log(display_description(x, out)))
  }
  invisible(out)
}

# One row per column of `x`. Built as three vectors and handed to data.table()
# in one go: `[` is never used here, because dtlog redefines it and an internal
# `:=` would log a mutate of its own under dtlog.log_from_packages = TRUE.
variable_description <- function(x) {
  cols <- as.list(x)
  nms <- names(cols)
  if (is.null(nms)) nms <- character(length(cols))
  max_n <- max_unique()
  n_unique <- vapply(cols, n_unique_values, integer(1L))
  values <- vapply(seq_along(cols), function(i) {
    unique_values(cols[[i]], n_unique[[i]], max_n)
  }, character(1L))
  data.table::data.table(
    Variable = nms,
    N_unique = n_unique,
    Unique_value = truncate_values(values)
  )
}

# uniqueN() counts NA as a value, so this agrees with the values listed
# alongside it. A list column has no meaningful count, which is the same
# verdict describe_values() reaches for a mutate message.
n_unique_values <- function(x) {
  if (is.list(x)) return(NA_integer_)
  tryCatch(as.integer(data.table::uniqueN(x)), error = function(e) NA_integer_)
}

# The values themselves, as one string. Nothing is listed once there are
# `max_n` or more of them: the column is then more likely to be continuous than
# categorical, and the list would be unreadable anyway.
unique_values <- function(x, n, max_n = max_unique()) {
  if (is.list(x)) return("list column")
  if (is.na(n)) return("")
  if (n >= max_n) {
    return(sprintf("%s+ unique values \u2014 possibly continuous", fmt_n(max_n)))
  }
  values <- tryCatch(sorted_unique(x), error = function(e) NULL)
  if (!length(values)) return("")
  # values[i], not values[[i]]: `[` is the method a class such as ITime or
  # POSIXct keeps, so the value handed to format_value() still knows what it is.
  one <- vapply(seq_along(values), function(i) format_value(values[i]), character(1L))
  paste(one, collapse = "; ")
}

# How many unique values a column may hold and still have them listed. Anything
# that is not a single positive number is ignored, the way an unusable
# dtlog.display is.
#
# The threshold stays a double: Inf then really is Inf, so `n >= max_n` is false
# for every column and everything is listed, which is what the option promises.
# Converting it to an integer instead would cap "everything" at 2^31 - 1, and
# would turn a threshold larger than that into NA -- which is not a condition
# `if` can be asked about. A threshold between two whole numbers is floored, so
# that the message names the number the column was actually measured against.
max_unique <- function() {
  n <- getOption("dtlog.table_max_unique", 20L)
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1) return(20L)
  floor(n)
}

# The values in the order the column itself sorts in: numbers, dates and times
# ascending, characters alphabetically, factors and ordered factors by their
# levels, FALSE before TRUE. Missing values sort last, so a column that has any
# ends with "Missing". A type that sort() cannot order (a complex column, an
# unusual S4 class) keeps the order the values appear in.
sorted_unique <- function(x) {
  values <- unique(x)
  tryCatch(sort(values, na.last = TRUE), error = function(e) values)
}

# One value, as a string. `v` is always a single value, so nothing here has to
# reduce a vector.
#
# NaN is missing as far as is.na() is concerned, but it is not the same value as
# NA, and a column holding both would otherwise list "Missing" twice, so it is
# asked about first.
#
# as.character() is then what decides whether the value is missing, because it
# is the one that says NA for a factor level that has no label (addNA()), where
# is.na() says no. format() is what decides how a value that is there is
# written: it is the method a class provides for people to read (09:00:00 for an
# ITime, where as.character() gives the 32400 seconds it is stored as), and it
# keeps a double to a readable number of digits.
format_value <- function(v) {
  if (is.numeric(v) && isTRUE(is.nan(v[1L]))) return("NaN")
  txt <- as.character(v)[1L]
  if (is.na(txt)) return("Missing")
  formatted <- tryCatch(format(v)[1L], error = function(e) NA_character_)
  if (is.na(formatted)) txt else formatted
}

# 80 is a display width, not a count of characters: a list of values written in
# a script whose characters take two columns each is then as wide on the screen
# as an English one, rather than twice.
truncate_values <- function(values) {
  if (!length(values)) return(values)
  long <- !is.na(values) & nchar(values, type = "width", keepNA = FALSE) > 80L
  values[long] <- paste0(trim_to_width(values[long], 77L), "...")
  values
}

# strtrim() cuts to a display width and never splits a character in two, but it
# falls back to counting characters for the ones outside the basic plane (an
# emoji is two columns wide and strtrim() keeps it as one), so what it returns
# is measured and cut again, character by character, where it did not fit.
trim_to_width <- function(x, width) {
  out <- strtrim(x, width)
  wide <- which(nchar(out, type = "width", keepNA = FALSE) > width)
  for (i in wide) {
    chars <- strsplit(out[[i]], "", fixed = TRUE)[[1L]]
    keep <- cumsum(nchar(chars, type = "width", keepNA = FALSE)) <= width
    out[[i]] <- paste(chars[keep], collapse = "")
  }
  out
}

# ---- output ----------------------------------------------------------------

display_description <- function(x, out) {
  display_block("dttable: ", c(
    sprintf("%s and %s", plural(nrow(x), "row"), plural(ncol(x), "column")),
    description_lines(out)
  ))
}

# The description as printed by data.table, one string per line.
#
# nrows= is passed explicitly so that a table with many columns is described in
# full rather than cut down to the first and last few rows, and the width is
# widened to what this particular description needs, because print() otherwise
# wraps the value column onto lines of its own at getOption("width"). 10000 is
# the largest width R accepts.
description_lines <- function(out) {
  if (!nrow(out)) return(NULL)
  # type = "width" is what print() lays the columns out in, so a name or a value
  # written in a script that takes two columns per character is measured as it
  # is shown. keepNA = FALSE counts an NA as the two characters print writes for
  # it; nchar() would otherwise answer NA and there would be no width to ask for.
  widths <- vapply(seq_along(out), function(i) {
    max(nchar(c(names(out)[[i]], as.character(out[[i]])),
              type = "width", keepNA = FALSE))
  }, numeric(1L))
  needed <- as.integer(sum(widths) + 2L * length(widths) + 2L)
  if (is.na(needed)) needed <- 80L
  old <- options(width = max(80L, min(10000L, needed)))
  on.exit(options(old), add = TRUE)
  utils::capture.output(
    print(out, row.names = FALSE, class = FALSE, nrows = nrow(out))
  )
}
