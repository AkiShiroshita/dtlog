# ---- analysis of the (unevaluated) call ------------------------------------

is_missing_arg <- function(x) identical(x, quote(expr = ))

is_call_to <- function(x, fun_names) is.call(x) && is.name(x[[1L]]) &&
  as.character(x[[1L]]) %in% fun_names

# Split the call into its named arguments. The data.table expressions
# themselves -- i, j, by, keyby -- are never evaluated here. A few control
# arguments are: `which` and `with` decide how the result has to be read, and
# the left hand side of a `(cols) :=` has to be resolved to column names.
# data.table evaluates those a second time, so a side effect written into
# `with=` or `which=` runs twice.
parse_bracket_call <- function(cl, pf) {
  matched <- match.call(.dt$bracket, cl, expand.dots = TRUE)
  arg <- function(name) {
    if (name %in% names(matched)) matched[[name]] else NULL
  }
  i <- arg("i")
  j <- arg("j")
  info <- list(
    i = if (is.null(i) || is_missing_arg(i)) NULL else i,
    j = if (is.null(j) || is_missing_arg(j)) NULL else j,
    by = arg("by"),
    keyby = arg("keyby"),
    on = arg("on"),
    which = arg("which"),
    which_true = isTRUE(tryCatch(eval(arg("which"), pf), error = function(e) FALSE)),
    sdcols = arg(".SDcols"),
    pf = pf
  )
  info$has_i <- !is.null(info$i)
  info$has_j <- !is.null(info$j)
  info$has_by <- !is.null(info$by) || !is.null(info$keyby)
  info$by_expr <- if (!is.null(info$by)) info$by else info$keyby
  info$with_false <- identical(
    tryCatch(eval(arg("with"), pf), error = function(e) NULL), FALSE
  )
  info$is_assign <- is_assign_call(info$j)
  info$assign_targets <- if (info$is_assign) assign_targets(info$j, pf) else NULL
  info$is_join <- is_join_call(info, pf)
  info$is_order <- is_call_to(info$i, c("order", "forder", "rev", "sample",
                                        "sample.int", "setorder", "shuffle"))
  info
}

is_assign_call <- function(j) {
  is.call(j) && is.name(j[[1L]]) && as.character(j[[1L]]) %in% c(":=", "let")
}

# Which columns does a := call touch? Returns NULL when this cannot be
# determined without evaluating user code with side effects.
assign_targets <- function(j, pf) {
  fun <- as.character(j[[1L]])
  nms <- names(j)
  # `:=`(a = 1, b = 2) and let(a = 1, b = 2)
  if (fun == "let" || (length(j) > 3L) ||
      (!is.null(nms) && any(nzchar(nms[-1L])))) {
    targets <- nms[-1L]
    if (length(targets) && all(nzchar(targets))) return(targets)
    return(NULL)
  }
  if (length(j) != 3L) return(NULL)
  lhs <- j[[2L]]
  if (is.name(lhs)) return(as.character(lhs))
  if (is.character(lhs)) return(lhs)
  # (cols) := ... , c("a", "b") := ... and other computed column names
  static <- is_call_to(lhs, "c") &&
    all(vapply(as.list(lhs)[-1L], is.character, logical(1L)))
  computed <- is_call_to(lhs, "(")
  if (static) {
    return(unlist(lapply(as.list(lhs)[-1L], as.character), use.names = FALSE))
  }
  if (computed) {
    value <- tryCatch(eval(lhs, pf), error = function(e) NULL)
    if (is.character(value)) return(value)
  }
  NULL
}

# `on=` given, or i is (very likely) a table to join on
is_join_call <- function(info, pf) {
  if (!is.null(info$on)) return(TRUE)
  i <- info$i
  if (is.null(i)) return(FALSE)
  if (is_call_to(i, c(".", "J", "SJ", "CJ", "list", "data.table",
                      "as.data.table", "data.frame"))) {
    return(TRUE)
  }
  if (is.name(i)) {
    value <- tryCatch(get0(as.character(i), envir = pf), error = function(e) NULL)
    return(is.data.frame(value))
  }
  FALSE
}

# ---- snapshot before the call ----------------------------------------------

# Everything that is needed for the log and that the call itself might
# destroy. Only := (which updates by reference) forces us to copy data, and
# then only the columns it touches.
snapshot_bracket <- function(x, info) {
  if (is.null(info)) return(NULL)
  before <- list(
    nrow = nrow(x),
    names = copy_names(x),
    key = data.table::key(x)
  )
  if (isTRUE(info$is_assign) && detail_full()) {
    targets <- info$assign_targets
    if (is.null(targets)) targets <- before$names
    targets <- intersect(targets, before$names)
    before$cols <- stats::setNames(
      lapply(targets, function(nm) data.table::copy(x[[nm]])),
      targets
    )
  }
  before
}

copy_names <- function(x) {
  nm <- names(x)
  if (is.null(nm)) character() else nm[]
}
