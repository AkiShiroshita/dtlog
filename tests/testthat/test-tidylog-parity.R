# Cross check against tidylog, which computes the same statistics for
# dplyr/tidyr. Both the data and, where the two packages describe the same
# operation, the wording have to agree.

skip_if_no_tidyverse <- function() {
  skip_if_not_installed("dplyr")
  skip_if_not_installed("tidyr")
  skip_if_not_installed("tidylog")
}

collect <- function(expr, env) {
  msgs <- character()
  value <- withCallingHandlers(
    eval(expr, env),
    message = function(m) {
      msgs <<- c(msgs, sub("\n$", "", conditionMessage(m)))
      invokeRestart("muffleMessage")
    }
  )
  list(value = value, msgs = msgs)
}

plain <- function(x) {
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  rownames(df) <- NULL
  df <- df[order(names(df))]
  df[do.call(order, c(lapply(df, as.character), list(method = "radix"))), ,
     drop = FALSE]
}

numbers_in <- function(msgs) {
  txt <- paste(msgs, collapse = " ")
  as.numeric(unlist(regmatches(txt, gregexpr("[0-9]+\\.?[0-9]*", txt))))
}

tidy_env <- function() {
  env <- new.env(parent = globalenv())
  env$DT <- data.table::as.data.table(mtcars, keep.rownames = "car")
  env$DF <- tibble::as_tibble(mtcars, rownames = "car")
  env$LAB_DT <- data.table::data.table(cyl = c(4, 6, 3),
                                       label = c("four", "six", "three"))
  env$LAB_DF <- tibble::tibble(cyl = c(4, 6, 3), label = c("four", "six", "three"))
  env$NA_DT <- data.table::data.table(a = c(1, NA, 3), b = c(NA, 2, 3))
  env$NA_DF <- tibble::tibble(a = c(1, NA, 3), b = c(NA, 2, 3))
  env$WIDE_DT <- data.table::data.table(id = 1:3, p = 4:6, q = 7:9)
  env$WIDE_DF <- tibble::tibble(id = 1:3, p = 4:6, q = 7:9)
  env
}

# operations that both packages describe in the same words
same_wording <- list(
  filter        = list(quote(DT[mpg > 20]),
                       quote(filter(DF, mpg > 20))),
  filter_none   = list(quote(DT[mpg > 0]),
                       quote(filter(DF, mpg > 0))),
  filter_all    = list(quote(DT[mpg > 1000]),
                       quote(filter(DF, mpg > 1000))),
  select        = list(quote(DT[, .(car, mpg, cyl)]),
                       quote(select(DF, car, mpg, cyl))),
  select_drop   = list(quote(DT[, !c("vs", "am")]),
                       quote(select(DF, -vs, -am))),
  mutate_new    = list(quote(DT[, kpl := mpg * 0.425][]),
                       quote(mutate(DF, kpl = mpg * 0.425))),
  mutate_change = list(quote(DT[, mpg := ifelse(cyl == 4, NA, mpg)][]),
                       quote(mutate(DF, mpg = ifelse(cyl == 4, NA, mpg)))),
  mutate_type   = list(quote(DT[, hp := as.integer(hp)][]),
                       quote(mutate(DF, hp = as.integer(hp)))),
  mutate_drop   = list(quote(DT[, car := NULL][]),
                       quote(mutate(DF, car = NULL))),
  distinct      = list(quote(unique(DT, by = "cyl")),
                       quote(distinct(DF, cyl, .keep_all = TRUE))),
  drop_na       = list(quote(stats::na.omit(NA_DT)),
                       quote(drop_na(NA_DF))),
  drop_na_col   = list(quote(stats::na.omit(NA_DT, cols = "a")),
                       quote(drop_na(NA_DF, a))),
  drop_na_none  = list(quote(stats::na.omit(DT)),
                       quote(drop_na(DF))),
  delete_one    = list(quote(DT[, cyl := NULL][]),
                       quote(mutate(DF, cyl = NULL))),
  delete_many   = list(quote(DT[, c("vs", "am") := NULL][]),
                       quote(mutate(DF, vs = NULL, am = NULL))),
  delete_sdcols = list(quote(DT[, .SD, .SDcols = !"vs"]),
                       quote(select(DF, -vs))),
  relocate      = list(quote({
                         setcolorder(DT, c("cyl", "car"))
                         DT
                       }),
                       quote(relocate(DF, cyl, car)))
)

test_that("dtlog and tidylog describe the same operation the same way", {
  skip_if_no_tidyverse()
  suppressPackageStartupMessages({
    library(dplyr); library(tidyr); library(tidylog)
  })
  for (name in names(same_wording)) {
    case <- same_wording[[name]]
    env <- tidy_env()
    dt <- collect(case[[1L]], env)
    tl <- collect(case[[2L]], env)
    expect_equal(plain(dt$value), plain(tl$value), ignore_attr = TRUE,
                 label = paste0("data for ", name))
    expect_identical(dt$msgs, tl$msgs, label = paste0("log for ", name))
  }
})

# joins: same numbers, but dtlog names the tables it was given
join_cases <- list(
  inner = list(quote(merge(DT, LAB_DT, by = "cyl")),
               quote(inner_join(DF, LAB_DF, by = "cyl"))),
  left  = list(quote(merge(DT, LAB_DT, by = "cyl", all.x = TRUE)),
               quote(left_join(DF, LAB_DF, by = "cyl"))),
  right = list(quote(merge(DT, LAB_DT, by = "cyl", all.y = TRUE)),
               quote(right_join(DF, LAB_DF, by = "cyl"))),
  full  = list(quote(merge(DT, LAB_DT, by = "cyl", all = TRUE)),
               quote(full_join(DF, LAB_DF, by = "cyl")))
)

test_that("the join statistics agree with tidylog", {
  skip_if_no_tidyverse()
  suppressPackageStartupMessages({
    library(dplyr); library(tidylog)
  })
  for (name in names(join_cases)) {
    case <- join_cases[[name]]
    env <- tidy_env()
    dt <- collect(case[[1L]], env)
    tl <- collect(case[[2L]], env)
    expect_equal(plain(dt$value), plain(tl$value), ignore_attr = TRUE,
                 label = paste0("data for ", name, " join"))
    expect_identical(numbers_in(dt$msgs), numbers_in(tl$msgs),
                     label = paste0("counts for ", name, " join"))
    expect_identical(sub(":.*", "", dt$msgs[1L]), sub(":.*", "", tl$msgs[1L]),
                     label = paste0("join type for ", name))
    expect_identical(grepl("includes duplicates", paste(dt$msgs, collapse = " ")),
                     grepl("includes duplicates", paste(tl$msgs, collapse = " ")),
                     label = paste0("duplicate note for ", name))
  }
})

# taking a subset of the rows: the same counts, but dtlog names the verb after
# the data.table function that was called
slice_cases <- list(
  slice      = list(quote(DT[1:5]), quote(slice(DF, 1:5)), "filter"),
  slice_head = list(quote(head(DT, 5)), quote(slice_head(DF, n = 5)), "head"),
  slice_tail = list(quote(tail(DT, 5)), quote(slice_tail(DF, n = 5)), "tail"),
  slice_none = list(quote(head(DT, 100)), quote(slice_head(DF, n = 100)), "head")
)

test_that("taking rows reports the same counts as tidylog", {
  skip_if_no_tidyverse()
  suppressPackageStartupMessages({
    library(dplyr); library(tidylog)
  })
  for (name in names(slice_cases)) {
    case <- slice_cases[[name]]
    env <- tidy_env()
    dt <- collect(case[[1L]], env)
    tl <- collect(case[[2L]], env)
    expect_equal(plain(dt$value), plain(tl$value), ignore_attr = TRUE,
                 label = paste0("data for ", name))
    # only the verb differs: head: ... vs slice_head: ...
    expect_identical(sub("^[a-z_]+:", "", dt$msgs), sub("^[a-z_]+:", "", tl$msgs),
                     label = paste0("counts for ", name))
    expect_match(dt$msgs[1L], paste0("^", case[[3L]], ":"))
  }
})

test_that("reshaping reports the same thing as tidyr", {
  skip_if_no_tidyverse()
  suppressPackageStartupMessages({
    library(tidyr); library(tidylog)
  })
  env <- tidy_env()
  dt <- collect(quote(melt(WIDE_DT, id.vars = "id", variable.factor = FALSE)), env)
  tl <- collect(quote(pivot_longer(WIDE_DF, c(p, q), names_to = "variable")), env)
  expect_equal(plain(dt$value), plain(tl$value), ignore_attr = TRUE)
  # only the name of the function differs
  expect_identical(sub("^melt", "pivot_longer", dt$msgs), tl$msgs)
})
