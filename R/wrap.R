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
# arguments with resolve_all() -- leaving the expression alone when data.table
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
  cl <- expand_dots(cl, pf)
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
  if (length(args)) {
    resolved <- try_log(resolve_all(cl, dt_formals(name), args, pf))
    if (!is.list(resolved)) resolved <- nothing_resolved(cl, args)
    cl <- resolved$cl
    bindings[names(resolved$bindings)] <- resolved$bindings
    for (a in args) before[a] <- list(try_log(snap(resolved$values[[a]])))
  }
  before$.call <- written_call
  run_wrapped(name, cl, pf, before, log_fn, bindings = bindings)
}

# A wrapper is declared as function(...), so a call that reaches it through a
# function which passes its own dots on -- lapply(files, fread) becomes
# FUN(X[[i]], ...) -- carries a literal `...` that belongs to `pf`, not to the
# wrapper. match.call() would expand it with the wrapper's own dots instead,
# turning fread(path) into fread(input = path, file = ..1), which then fails
# when the call is re-evaluated in `pf` where that ..1 does not exist. Writing
# the caller's own ..1, ..2, ... into the call keeps every argument the promise
# `pf` holds, so nothing is evaluated in the wrong environment or twice.
expand_dots <- function(cl, pf) {
  if (length(cl) < 2L) return(cl)
  k <- match("...", vapply(as.list(cl), symbol_text, character(1L)), nomatch = 0L)
  if (k < 2L) return(cl)
  # substitute() reads the expressions the dots hold without forcing them, and
  # gives NULL when the frame has no dots left to pass on
  dots <- tryCatch(eval(quote(substitute(...())), pf), error = function(e) NULL)
  if (!is.null(dots) && !is.pairlist(dots) && !is.list(dots)) return(cl)
  supplied <- lapply(seq_along(dots), function(j) as.name(sprintf("..%d", j)))
  names(supplied) <- names(dots)
  parts <- as.list(cl)
  out <- as.call(c(parts[seq_len(k - 1L)], supplied, parts[-seq_len(k)]))
  if (!any(nzchar(names(out) %||% ""))) names(out) <- NULL
  out
}

stopf_missing_call <- function(name) {
  stop(sprintf("dtlog could not reconstruct the call to %s()", name), call. = FALSE)
}

# Resolve several arguments of one call, each of them evaluated at most once.
# Returns the (possibly rewritten) call, the values by argument name, and the
# placeholder bindings the rewritten call needs.
#
# The positions are worked out once for the whole call, so an argument is found
# wherever data.table would find it -- named, named in part, or positional --
# without the call itself having to be rearranged.
resolve_all <- function(cl, fun, args, pf, pos = NULL) {
  if (is.null(pos)) pos <- if (is.null(fun)) integer() else arg_positions(cl, fun)
  values <- list()
  bindings <- list()
  for (arg in args) {
    k <- position_of(pos, arg)
    if (is.na(k)) k <- arg_index(cl, arg)
    # by far the most common case is an argument the call does not have, and it
    # is not worth a tryCatch to find that out
    if (is.na(k)) {
      values[arg] <- list(NULL)
      next
    }
    resolved <- try_log(resolve_at(cl, k, pf))
    if (!is.list(resolved)) resolved <- no_arg(cl)
    cl <- resolved$cl
    bindings[names(resolved$bindings)] <- resolved$bindings
    values[arg] <- list(resolved$value)
  }
  list(cl = cl, values = values, bindings = bindings, positions = pos)
}

# what resolve_all() would have returned had it not failed
nothing_resolved <- function(cl, args) {
  list(cl = cl, values = stats::setNames(vector("list", length(args)), args),
       bindings = list(), positions = integer())
}

# Get hold of the value of the argument at position `k` before the call runs,
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
resolve_at <- function(cl, k, pf) {
  # an empty slot has to be recognised before it is bound to a variable: R
  # calls reading such a variable a missing argument, and stops
  if (is.na(k) || is_missing_arg(cl[[k]])) return(no_arg(cl))
  expr <- cl[[k]]
  got <- tryCatch(list(ok = TRUE, value = eval(expr, pf)),
                  error = function(e) list(ok = FALSE, value = NULL))
  if (!got$ok) return(no_arg(cl))
  # A constant has no side effect either, and data.table sometimes inspects the
  # expression it was given (fread() checks all.vars(substitute(input)) before
  # treating input= as a shell command), so leave it exactly as written.
  if (is_reference_target(expr) || is_constant(expr)) {
    return(list(cl = cl, value = got$value, bindings = list()))
  }
  placeholder <- sprintf(".dtlog_arg%d", k)
  cl[[k]] <- as.name(placeholder)
  list(cl = cl, value = got$value,
       bindings = stats::setNames(list(got$value), placeholder))
}

no_arg <- function(cl) list(cl = cl, value = NULL, bindings = list())

is_constant <- function(expr) !is.name(expr) && !is.call(expr) && !is.expression(expr)

# Where each formal of `fun` ended up in the call as written. Every argument is
# replaced by a marker before match.call() runs, so what comes back is a set of
# positions in `cl` rather than a rearranged call: the call keeps the shape
# data.table expects, and an argument given positionally or under a partial
# name is still found. Functions declared as function(...) -- setindex() is one
# -- have nothing to match against and give an empty answer; arg_index() then
# falls back to looking for the argument by name.
arg_positions <- function(cl, fun) {
  n <- length(cl)
  if (n < 2L) return(integer())
  if (is.null(names(cl))) {
    # nothing is named, so the arguments line up with the formals in order and
    # there is nothing for match.call() to work out. Everything from the first
    # `...` on is swallowed by it -- setorder(x, ..., na.last) never matches a
    # positional argument to na.last -- so the answer stops there.
    formal_names <- names(formals(fun))
    dots <- match("...", formal_names, nomatch = 0L)
    if (dots > 0L) formal_names <- formal_names[seq_len(dots - 1L)]
    last <- min(n - 1L, length(formal_names))
    if (last < 1L) return(integer())
    return(stats::setNames(seq.int(2L, last + 1L), formal_names[seq_len(last)]))
  }
  markers <- paste0(".dtlog_at", seq.int(2L, n))
  probe <- cl
  for (k in seq.int(2L, n)) probe[[k]] <- as.name(markers[k - 1L])
  m <- tryCatch(match.call(fun, probe, expand.dots = TRUE),
                error = function(e) NULL)
  if (is.null(m) || length(m) < 2L) return(integer())
  parts <- as.list(m)[-1L]
  nms <- names(parts)
  if (is.null(nms)) return(integer())
  at <- match(vapply(parts, symbol_text, character(1L)), markers)
  keep <- !is.na(at) & nzchar(nms)
  stats::setNames(at[keep] + 1L, nms[keep])
}

# the name of a symbol, and "" for anything else
symbol_text <- function(x) if (is.name(x)) as.character(x) else ""

position_of <- function(pos, arg) {
  if (arg %in% names(pos)) unname(pos[[arg]]) else NA_integer_
}

# Position of `arg` in the call as written, for the calls that arg_positions()
# cannot match: `x` is the first formal of every function dtlog wraps with
# args = "x", so an unnamed first argument is it.
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

# data.table's version of a wrapped function, or NULL when it cannot be found.
# Only its formals are wanted, to work out which argument is where.
dt_formals <- function(name) tryCatch(original(name), error = function(e) NULL)

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
