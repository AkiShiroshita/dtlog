#' Subset, aggregate and update a data.table, with a log
#'
#' `dtlog` redefines the `[` method for data tables. The call is passed on to
#' `data.table` unchanged -- same arguments, same evaluation environment, same
#' return value, same modification by reference -- and a message describing
#' what happened is printed afterwards.
#'
#' Depending on the call, the message uses the vocabulary of `tidylog`:
#' `filter` (rows removed by `i`), `arrange` (rows reordered), `join` (`i` is a
#' table or `on=` was given), `select` (`j` only picks existing columns),
#' `mutate` (`:=`), `group_by`/`summarize` (`by=`/`keyby=`).
#'
#' @param x A `data.table`.
#' @param ... All other arguments of `[.data.table`, i.e. `i`, `j`, `by`,
#'   `keyby`, `with`, `nomatch`, `mult`, `roll`, `rollends`, `which`,
#'   `.SDcols`, `verbose`, `allow.cartesian`, `drop`, `on`, `env` and
#'   `showProgress`. They are never touched by `dtlog`.
#' @return Whatever `data.table`'s `[` returns, with the same visibility.
#' @examples
#' dt <- data.table::as.data.table(mtcars)
#' dt[mpg > 20]
#' dt[, mpg_per_cyl := mpg / cyl]
#' @rawNamespace export("[.data.table")
#' @export
`[.data.table` <- function(x, ...) {
  cl <- sys.call()
  pf <- parent.frame()
  if (is.null(cl)) return(.dt$bracket(x, ...))
  written_call <- cl
  cl[[1L]] <- quote(`[.data.table`)
  env <- bracket_env(pf, cl, x)
  cl <- attr(env, "call")
  if (!should_log_call(pf)) return(eval_visible(cl, env))
  info <- try_log(parse_bracket_call(cl, pf))
  before <- try_log(snapshot_bracket(x, info))
  res <- withVisible(eval(cl, env))
  with_logged_call(written_call, try_log(log_bracket(x, res$value, info, before)))
  if (res$visible) res$value else invisible(res$value)
}

# An environment that shadows dtlog's own method with the original one from
# data.table. It is a child of the caller's frame, so that ordinary lexical
# lookup in i, j and by follows the same bindings as it would without dtlog,
# and so that data.table:::cedta() reaches the same verdict about the caller.
#
# Because the call is run through eval(), parent.frame() inside data.table's
# method is this environment rather than the caller's frame. The write-back of
# an over-allocated shallow copy still reaches the caller, because data.table
# uses assign(name, x, parent.frame(), inherits = TRUE) and this environment
# holds no binding of that name, so the assignment walks up into the caller's
# frame. Simple extractions (`l$dt` and friends) are written back by reference
# and are unaffected either way.
#
# The call is re-evaluated in that environment, which would evaluate the
# expression that produced `x` a second time. For a symbol (or a simple
# extraction such as `l$dt`) that is harmless, and data.table needs the
# original expression: when it has to over-allocate it assigns the shallow
# copy back to that name. For anything else -- a chained `dt[...][...]`, a
# function call -- the already evaluated table is bound to a placeholder
# instead, so that nothing is computed twice.
bracket_env <- function(pf, cl, x) {
  env <- new.env(parent = pf)
  assign("[.data.table", .dt$bracket, envir = env)
  k <- x_arg_index(cl)
  if (!is.na(k) && !is_reference_target(cl[[k]])) {
    assign(".dtlog_x", x, envir = env)
    cl[[k]] <- quote(.dtlog_x)
  }
  attr(env, "call") <- cl
  env
}

eval_visible <- function(cl, env) {
  res <- withVisible(eval(cl, env))
  if (res$visible) res$value else invisible(res$value)
}

# position of the argument that data.table matches to `x`
x_arg_index <- function(cl) arg_index(cl, "x")

# data.table reassigns an over-allocated copy to expressions of this shape.
# Deliberately identical to data.table:::.is_simple_extraction(); if that
# predicate ever changes, this one has to change with it, otherwise dtlog
# would replace an expression that data.table still needs to write back to.
is_reference_target <- function(expr) {
  is.name(expr) ||
    (is.call(expr) && is.name(expr[[1L]]) &&
       as.character(expr[[1L]]) %in% c("$", "@", "[[") && is.name(expr[[2L]]))
}
