#' Modify a data table by reference, with a log
#'
#' These functions are the `data.table` `set*()` functions. They still change
#' their input by reference and return exactly what `data.table` returns; they
#' only report what they changed.
#'
#' @param x The data table (or, for [setDT()], the object to convert).
#' @param ... All other arguments, passed on unchanged.
#' @return Whatever the corresponding `data.table` function returns.
#' @examples
#' dt <- data.table::data.table(a = 3:1, b = 1:3)
#' data.table::setnames(dt, "a", "alpha")
#' data.table::setkey(dt, alpha)
#' @name set_functions
NULL

#' @rdname set_functions
#' @rawNamespace export("setnames")
setnames <- function(x, ...) {
  logged("setnames", sys.call(), parent.frame(), log_setnames, args = "x")
}

log_setnames <- function(out, before, cl, pf) {
  x <- before$x
  if (is.null(x)) return(invisible(NULL))
  after <- names(x$obj)
  if (length(after) != length(x$names)) {
    return(display(sprintf("setnames: now %s (%s)",
                           plural(length(after), "variable"), format_list(after))))
  }
  changed <- which(after != x$names)
  if (!length(changed)) return(display("setnames: no changes"))
  display(sprintf(
    "rename: renamed %s (%s)",
    plural(length(changed), "variable"),
    format_list(sprintf("%s -> %s", x$names[changed], after[changed]))
  ))
}

#' @rdname set_functions
#' @rawNamespace export("setcolorder")
setcolorder <- function(x, ...) {
  logged("setcolorder", sys.call(), parent.frame(), log_setcolorder,
         args = "x")
}

log_setcolorder <- function(out, before, cl, pf) {
  x <- before$x
  if (is.null(x)) return(invisible(NULL))
  after <- names(x$obj)
  if (identical(after, x$names)) return(display("setcolorder: no changes"))
  display(sprintf("relocate: columns reordered (%s)", format_list(after)))
}

#' @rdname set_functions
#' @rawNamespace export("setkey")
setkey <- function(x, ...) {
  logged("setkey", sys.call(), parent.frame(), log_setkey("setkey"),
         args = "x")
}

#' @rdname set_functions
#' @rawNamespace export("setkeyv")
setkeyv <- function(x, ...) {
  logged("setkeyv", sys.call(), parent.frame(), log_setkey("setkeyv"),
         args = "x")
}

log_setkey <- function(fun) {
  function(out, before, cl, pf) {
    x <- before$x
    if (is.null(x)) return(invisible(NULL))
    after <- data.table::key(x$obj)
    if (identical(after, x$key)) {
      return(display(sprintf("%s: no changes", fun)))
    }
    if (is.null(after)) {
      return(display(sprintf("%s: removed the key (was %s)", fun,
                             format_list(x$key))))
    }
    display(sprintf(
      "%s: keyed by (%s), %s sorted",
      fun, format_list(after), plural(nrow(x$obj), "row")
    ))
  }
}

#' @rdname set_functions
#' @rawNamespace export("setorder")
setorder <- function(x, ...) {
  logged("setorder", sys.call(), parent.frame(),
         log_setorder("setorder", "..."), args = "x")
}

#' @rdname set_functions
#' @rawNamespace export("setorderv")
setorderv <- function(x, ...) {
  logged("setorderv", sys.call(), parent.frame(),
         log_setorder("setorderv", "cols"), args = "x")
}

log_setorder <- function(fun, arg) {
  function(out, before, cl, pf) {
    x <- before$x
    if (is.null(x)) return(invisible(NULL))
    by <- order_columns(cl, fun, arg, pf)
    display(sprintf(
      "arrange: sorted %s%s",
      plural(nrow(x$obj), "row"),
      if (length(by)) sprintf(" by (%s)", format_list(by)) else ""
    ))
  }
}

order_columns <- function(cl, fun, arg, pf) {
  if (identical(arg, "...")) {
    args <- as.list(cl)[-1L]
    nms <- names(args)
    if (!is.null(nms)) args <- args[!nzchar(nms)]
    if (length(args)) args <- args[-1L]  # drop x
    return(vapply(args, deparse_short, character(1L)))
  }
  expr <- matched_arg(cl, fun, arg)
  value <- tryCatch(eval(expr, pf), error = function(e) NULL)
  if (is.character(value)) value else character()
}

#' @rdname set_functions
#' @rawNamespace export("setindex")
setindex <- function(x, ...) {
  logged("setindex", sys.call(), parent.frame(), log_setindex("setindex"),
         args = "x")
}

#' @rdname set_functions
#' @rawNamespace export("setindexv")
setindexv <- function(x, ...) {
  logged("setindexv", sys.call(), parent.frame(), log_setindex("setindexv"),
         args = "x")
}

log_setindex <- function(fun) {
  function(out, before, cl, pf) {
    x <- before$x
    if (is.null(x)) return(invisible(NULL))
    after <- data.table::indices(x$obj)
    added <- setdiff(after, x$indices)
    removed <- setdiff(x$indices, after)
    if (!length(added) && !length(removed)) {
      return(display(sprintf("%s: no changes", fun)))
    }
    if (length(added)) {
      display(sprintf("%s: added index (%s)", fun, format_list(added)))
    }
    if (length(removed)) {
      display(sprintf("%s: removed index (%s)", fun, format_list(removed)))
    }
  }
}

#' @rdname set_functions
#' @rawNamespace export("set")
set <- function(x, ...) {
  cl <- sys.call()
  pf <- parent.frame()
  if (!should_log_call(pf)) return(run_wrapped("set", cl, pf))
  written_call <- cl
  resolved <- try_log(resolve_arg(cl, "set", "x", pf))
  if (!is.list(resolved)) resolved <- no_arg(cl)
  target <- resolved$value
  cl <- resolved$cl
  before <- try_log(list(x = snap(target), cols = set_columns(cl, pf, target)))
  if (is.list(before)) before$.call <- written_call
  run_wrapped("set", cl, pf, before, log_set, bindings = resolved$bindings)
}

# the columns a set() call writes to, and a copy of their current values
set_columns <- function(cl, pf, target) {
  if (is.null(target)) return(NULL)
  expr <- matched_arg(cl, "set", "j")
  value <- tryCatch(eval(expr, pf), error = function(e) NULL)
  cols <- if (is.character(value)) value else
    if (is.numeric(value)) names(target)[value] else NULL
  cols <- intersect(cols, names(target))
  if (!length(cols) || !detail_full()) return(NULL)
  stats::setNames(lapply(cols, function(nm) data.table::copy(target[[nm]])), cols)
}

log_set <- function(out, before, cl, pf) {
  x <- before$x
  if (is.null(x)) return(invisible(NULL))
  after_names <- names(x$obj)
  added <- setdiff(after_names, x$names)
  dropped <- setdiff(x$names, after_names)
  lines <- list()
  if (length(dropped)) {
    lines <- c(lines, sprintf("dropped %s (%s)", plural(length(dropped), "variable"),
                              format_list(dropped)))
  }
  for (nm in added) {
    lines <- c(lines, sprintf("new variable '%s' %s", nm, describe_values(x$obj[[nm]])))
  }
  updated <- setdiff(names(before$cols) %||% character(), c(added, dropped))
  for (nm in updated) {
    lines <- c(lines, describe_update(nm, before$cols[[nm]], x$obj[[nm]]))
  }
  if (!length(lines)) lines <- list("updated by reference")
  display_block("set: ", lines)
}

#' @rdname set_functions
#' @rawNamespace export("setDT")
setDT <- function(x, ...) {
  logged("setDT", sys.call(), parent.frame(), log_convert("setDT"),
         args = "x")
}

#' @rdname set_functions
#' @rawNamespace export("setDF")
setDF <- function(x, ...) {
  logged("setDF", sys.call(), parent.frame(), log_convert("setDF"),
         args = "x")
}

log_convert <- function(fun) {
  function(out, before, cl, pf) {
    if (!is.data.frame(out)) return(invisible(NULL))
    from <- if (is.null(before$x)) "input" else before$x$class
    display(sprintf(
      "%s: converted %s to %s (%s, %s)",
      fun, from, class(out)[1L], plural(nrow(out), "row"),
      plural(ncol(out), "column")
    ))
  }
}

#' @rdname set_functions
#' @rawNamespace export("setattr")
setattr <- function(x, ...) {
  logged("setattr", sys.call(), parent.frame(), log_setattr, args = "x")
}

log_setattr <- function(out, before, cl, pf) {
  name <- tryCatch(eval(matched_arg(cl, "setattr", "name"), pf),
                   error = function(e) NULL)
  display(sprintf(
    "setattr: set attribute%s by reference",
    if (is.character(name)) sprintf(" '%s'", name) else ""
  ))
}
