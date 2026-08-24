# ---- analysis of the (unevaluated) call ------------------------------------

is_missing_arg <- function(x) identical(x, quote(expr = ))

is_call_to <- function(x, fun_names) is.call(x) && is.name(x[[1L]]) &&
  as.character(x[[1L]]) %in% fun_names

# Split the call into its named arguments. The data.table expressions
# themselves -- i, j, by, keyby -- are never evaluated here. The control
# arguments that dtlog does need the value of -- `which`, `with` and the left
# hand side of a `(cols) :=` -- were evaluated once before the call by
# resolve_bracket_args(), and their values arrive in `resolved`.
parse_bracket_call <- function(cl, pf, pos = integer(), resolved = list()) {
  pos_names <- names(pos)
  # `DT[, j]` leaves the i slot empty, and there is still a position for it.
  # That empty symbol has to be tested where it sits: bound to a variable
  # first, reading it back is what R calls a missing argument, and stops.
  arg <- function(name) {
    at <- match(name, pos_names)
    if (is.na(at) || is_missing_arg(cl[[pos[[at]]]])) NULL else cl[[pos[[at]]]]
  }
  i <- arg("i")
  j <- arg("j")
  info <- list(
    i = i,
    j = j,
    by = arg("by"),
    keyby = arg("keyby"),
    on = arg("on"),
    which = arg("which"),
    which_true = isTRUE(element(resolved, "which")),
    sdcols = arg(".SDcols"),
    pf = pf
  )
  info$has_i <- !is.null(info$i)
  info$has_j <- !is.null(info$j)
  info$has_by <- !is.null(info$by) || !is.null(info$keyby)
  info$by_expr <- if (!is.null(info$by)) info$by else info$keyby
  info$with_false <- identical(element(resolved, "with"), FALSE)
  info$is_assign <- is_assign_call(info$j)
  info$assign_targets <- if (info$is_assign) {
    assign_targets(info$j, pf, element(resolved, "lhs"))
  } else NULL
  info$is_join <- is_join_call(info, pf)
  info$is_order <- is_call_to(info$i, c("order", "forder", "rev", "sample",
                                        "sample.int", "setorder", "shuffle"))
  info
}

is_assign_call <- function(j) {
  is.call(j) && is.name(j[[1L]]) && as.character(j[[1L]]) %in% c(":=", "let")
}

# `(cols) := value` names its columns through an expression, and data.table
# evaluates anything that is not a plain name to find out which columns are
# meant. Evaluate it once here and put the value back into the call, still
# wrapped in `(`: that wrapper is what tells data.table the name is computed
# rather than literal, so the operation itself is unchanged.
resolve_assign_lhs <- function(cl, k, pf) {
  if (is.na(k)) return(NULL)
  j <- cl[[k]]
  if (!is_assign_call(j) || length(j) != 3L) return(NULL)
  lhs <- j[[2L]]
  if (!is_call_to(lhs, "(") || length(lhs) != 2L) return(NULL)
  inner <- lhs[[2L]]
  # a name or a constant cannot have a side effect, and data.table is happier
  # with the expression the user wrote
  if (is_reference_target(inner) || is_constant(inner)) return(NULL)
  got <- tryCatch(list(ok = TRUE, value = eval(inner, pf)),
                  error = function(e) list(ok = FALSE, value = NULL))
  if (!got$ok) return(NULL)
  cl[[k]][[2L]][[2L]] <- quote(.dtlog_lhs)
  list(cl = cl, value = got$value, bindings = list(.dtlog_lhs = got$value))
}

# Which columns does a := call touch? Returns NULL when this cannot be
# determined without evaluating user code with side effects. `resolved` is the
# value resolve_assign_lhs() already read off a computed `(cols)`.
assign_targets <- function(j, pf, resolved = NULL) {
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
    value <- if (is.null(resolved)) {
      tryCatch(eval(lhs, pf), error = function(e) NULL)
    } else {
      resolved
    }
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
