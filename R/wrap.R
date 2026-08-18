# ---- machinery shared by all wrapped data.table functions ------------------

# The original function is fetched from the data.table namespace on load, so
# that dtlog can call it even though the call it re-evaluates uses the plain
# name.
original <- function(name) {
  fun <- .dt[[name]]
  if (is.null(fun)) {
    fun <- utils::getFromNamespace(name, "data.table")
    .dt[[name]] <- fun
  }
  fun
}

# Run the call the user wrote, but with `name` bound to data.table's version of
# the function, in a child of the caller's frame. Non standard evaluation
# (setkey(dt, col)), modification by reference and functions that assign back
# into the caller's frame (setDT) therefore behave exactly as without dtlog.
#
# Because the call goes through eval(), parent.frame() inside data.table's
# function is that child rather than the caller's frame. setDT() and friends
# still reach the caller: for a symbol they use assign(..., inherits = TRUE),
# which walks past the (empty) child into the caller's frame, and for a simple
# extraction such as `l$dt` they write back by reference. See bracket_env(),
# which relies on the same two properties.
run_wrapped <- function(name, cl, pf, before = NULL, log_fn = NULL,
                        bindings = list()) {
  fun <- original(name)
  if (is.null(cl)) stopf_missing_call(name)
  cl[[1L]] <- as.name(name)
  env <- new.env(parent = pf)
  assign(name, fun, envir = env)
  for (nm in names(bindings)) assign(nm, bindings[[nm]], envir = env)
  if (is.null(log_fn)) return(eval_visible(cl, env))
  res <- withVisible(eval(cl, env))
  with_logged_call(before$.call %||% cl, try_log(log_fn(res$value, before, cl, pf)))
  if (res$visible) res$value else invisible(res$value)
}

# The entry point every wrapper uses.
#
# `values` holds the arguments that the wrapper itself already forced (R
# evaluates them once, when the wrapper touches them). Their expressions in the
# call are replaced by those values, so that nothing is computed a second time
# when dtlog re-evaluates the call. That is safe for every function except the
# set*() family, which uses substitute() on its first argument to write back
# into the caller; for those, pass `args` instead, and dtlog resolves those
# arguments with resolve_arg() -- leaving the expression alone when data.table
# needs to see it, and evaluating it exactly once otherwise.
#
# `values` and `args` can be combined: fwrite() forces `x` itself and lets
# dtlog resolve `file` and `append`. A log function must then read those
# arguments off `before` rather than evaluating them again, which would run a
# side effecting expression a second time.
#
# `match` normalises the call with match.call() before anything else, so that
# an argument passed positionally can be found by name. Only pass it for
# functions that do not use substitute() on their arguments.
logged <- function(name, cl, pf, log_fn = NULL, values = NULL, args = NULL,
                   match = FALSE) {
  written_call <- cl
  bindings <- list()
  if (length(values) || isTRUE(match)) {
    substituted <- tryCatch({
      m <- match.call(original(name), cl)
      for (a in names(values)) {
        if (!(a %in% names(m))) next
        placeholder <- paste0(".dtlog_", a)
        bindings[placeholder] <- values[a]
        m[[a]] <- as.name(placeholder)
      }
      m
    }, error = function(e) NULL)
    if (is.null(substituted)) bindings <- list() else cl <- substituted
  }
  if (is.null(log_fn) || !should_log_call(pf)) {
    return(run_wrapped(name, cl, pf, bindings = bindings))
  }
  before <- list()
  if (length(values)) {
    snapped <- try_log(lapply(values, snap))
    if (is.list(snapped)) before <- snapped
  }
  for (a in args) {
    resolved <- try_log(resolve_arg(cl, name, a, pf))
    if (!is.list(resolved)) resolved <- no_arg(cl)
    cl <- resolved$cl
    bindings[names(resolved$bindings)] <- resolved$bindings
    before[a] <- list(try_log(snap(resolved$value)))
  }
  before$.call <- written_call
  run_wrapped(name, cl, pf, before, log_fn, bindings = bindings)
}

stopf_missing_call <- function(name) {
  stop(sprintf("dtlog could not reconstruct the call to %s()", name), call. = FALSE)
}

# Get hold of the value of one argument of the call before the call runs,
# without ever computing it twice. Returns the (possibly rewritten) call, the
# value, and any placeholder binding the rewritten call needs.
#
# When the expression is one that data.table assigns back into -- a symbol, or
# an extraction such as `l$dt` -- it is left in the call untouched, because
# data.table needs to see it: setDT() and friends use substitute() on it, and
# an over-allocating call writes the shallow copy back to that name. Evaluating
# such an expression here is harmless, so the value is simply read off.
#
# Anything else (a chained `dt[...][...]`, a function call, the left-hand side
# of a pipe) is evaluated once here and bound to a placeholder that replaces it
# in the call, so that re-evaluating the call does not compute it a second
# time. `[.data.table` does exactly the same thing; see bracket_env().
resolve_arg <- function(cl, name, arg, pf) {
  k <- arg_index(cl, arg)
  if (is.na(k)) return(no_arg(cl))
  expr <- cl[[k]]
  if (is_missing_arg(expr)) return(no_arg(cl))
  got <- tryCatch(list(ok = TRUE, value = eval(expr, pf)),
                  error = function(e) list(ok = FALSE, value = NULL))
  if (!got$ok) return(no_arg(cl))
  # A constant has no side effect either, and data.table sometimes inspects the
  # expression it was given (fread() checks all.vars(substitute(input)) before
  # treating input= as a shell command), so leave it exactly as written.
  if (is_reference_target(expr) || is_constant(expr)) {
    return(list(cl = cl, value = got$value, bindings = list()))
  }
  placeholder <- paste0(".dtlog_", arg)
  cl[[k]] <- as.name(placeholder)
  list(cl = cl, value = got$value,
       bindings = stats::setNames(list(got$value), placeholder))
}

no_arg <- function(cl) list(cl = cl, value = NULL, bindings = list())

is_constant <- function(expr) !is.name(expr) && !is.call(expr) && !is.expression(expr)

# Position of `arg` in the call as written. Only a formal that comes first can
# be matched positionally, which is what `x` is for every function dtlog wraps
# with args = "x" (several of them, such as setindex(), are declared as
# function(...), so match.call() is no help here). Any other argument -- fread()
# resolves `input` and `file`, fwrite() `file` and `append` -- can only be found
# by name, so those wrappers have to pass match = TRUE, which names the
# positional arguments before resolve_arg() looks for them.
arg_index <- function(cl, arg) {
  if (length(cl) < 2L) return(NA_integer_)
  nms <- names(cl)
  if (is.null(nms)) return(if (identical(arg, "x")) 2L else NA_integer_)
  hit <- which(nms == arg)
  if (length(hit)) return(hit[1L])
  if (!identical(arg, "x")) return(NA_integer_)
  unnamed <- which(!nzchar(nms))
  unnamed <- unnamed[unnamed > 1L]
  if (length(unnamed)) unnamed[1L] else NA_integer_
}

matched_arg <- function(cl, name, arg) {
  m <- tryCatch(match.call(original(name), cl), error = function(e) NULL)
  if (is.null(m) || !(arg %in% names(m))) return(NULL)
  m[[arg]]
}

# What a table looked like before the call. Everything here is a copy except
# `obj`, which is the table itself: after a set*() call it therefore shows the
# new state, which is exactly what the log functions read it for (`after <-
# names(x$obj)`). Nothing may use `obj` as the state before the call.
snap <- function(x) {
  if (is.null(x)) return(NULL)
  list(
    obj = x,
    nrow = if (is.data.frame(x)) nrow(x) else length(x),
    ncol = if (is.data.frame(x)) ncol(x) else 1L,
    names = copy_names(x),
    key = if (data.table::is.data.table(x)) data.table::key(x) else NULL,
    indices = if (data.table::is.data.table(x)) data.table::indices(x) else NULL,
    class = class(x)[1L]
  )
}

dims <- function(x) {
  if (is.data.frame(x)) sprintf("%sx%s", nrow(x), ncol(x)) else
    sprintf("length %s", length(x))
}

# "removed 5 rows (16%), 27 rows remaining"
rows_removed <- function(before_n, after_n) {
  removed <- before_n - after_n
  if (removed == 0L) return("no rows removed")
  if (removed < 0L) {
    return(sprintf("added %s, %s total", plural(-removed, "row"),
                   plural(after_n, "row")))
  }
  if (after_n == 0L) return("removed all rows (100%)")
  sprintf("removed %s (%s), %s remaining", plural(removed, "row"),
          percent(removed, before_n), plural(after_n, "row"))
}
