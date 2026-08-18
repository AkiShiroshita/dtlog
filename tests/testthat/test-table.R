# table() describes a single data.table and is base::table() for everything else

SEX <- c("m", "f", "m", "f")
DEATH <- c(0, 1, 1, 0)
DF <- data.frame(sex = SEX, death = DEATH)

# the same transcript helper test-transcript.R uses
table_transcript <- function(expr) {
  path <- tempfile(fileext = ".txt")
  dt_log(path, echo = FALSE)
  on.exit(if (!is.null(dt_log_file())) suppressMessages(dt_log_end()), add = TRUE)
  force(expr)
  suppressMessages(dt_log_end())
  readLines(path)
}

test_that("anything that is not a single data.table goes to base::table()", {
  expect_identical(table(DF$sex, DF$death), base::table(DF$sex, DF$death))
  expect_identical(table(SEX, DEATH), base::table(SEX, DEATH))
  expect_identical(table(SEX), base::table(SEX))
  expect_identical(table(DF), base::table(DF))
  expect_identical(table(as.data.frame(DF)), base::table(as.data.frame(DF)))
  expect_identical(table(factor(SEX, levels = c("m", "f", "x"))),
                   base::table(factor(SEX, levels = c("m", "f", "x"))))
})

test_that("the arguments of base::table() keep working", {
  expect_identical(table(SEX, DEATH, deparse.level = 2),
                   base::table(SEX, DEATH, deparse.level = 2))
  expect_identical(table(DF$sex, DF$death, deparse.level = 2),
                   base::table(DF$sex, DF$death, deparse.level = 2))
  expect_identical(table(SEX, DEATH, dnn = c("S", "D")),
                   base::table(SEX, DEATH, dnn = c("S", "D")))
  expect_identical(table(c(1, NA, 2), useNA = "ifany"),
                   base::table(c(1, NA, 2), useNA = "ifany"))
  expect_identical(table(c(1, 2, 2), exclude = 2), base::table(c(1, 2, 2), exclude = 2))
  # the names of the dimnames still come from the expressions as written
  expect_identical(names(dimnames(table(DF$sex, DF$death, deparse.level = 2))),
                   c("DF$sex", "DF$death"))
})

test_that("a two by two table built inside with() is base's", {
  dat <- data.table::data.table(estrogen = c(0, 1, 1, 0, 1, 0, 1, 1),
                                dead = c(1, 0, 1, 1, 0, 0, 1, 0))
  two_by_two <- with(dat, table(estrogen = estrogen, dead = dead))
  expect_identical(two_by_two, with(dat, base::table(estrogen = estrogen, dead = dead)))
  expect_identical(names(dimnames(two_by_two)), c("estrogen", "dead"))
  expect_silent(with(dat, table(estrogen = estrogen, dead = dead)))
  # the same call on a data.frame, and with an argument of base::table()
  expect_identical(with(as.data.frame(dat), table(estrogen = estrogen, dead = dead)),
                   two_by_two)
  expect_identical(with(dat, table(estrogen = estrogen, dead = dead, useNA = "ifany")),
                   with(dat, base::table(estrogen = estrogen, dead = dead, useNA = "ifany")))
})

test_that("a data.table with any other argument goes to base::table() too", {
  dt <- data.table::data.table(a = c(1, NA), b = c("x", "x"))
  expect_identical(table(dt, useNA = "ifany"), base::table(dt, useNA = "ifany"))
  # two tables are as much of an error as they are without dtlog
  expect_identical(
    tryCatch(table(dt, dt), error = conditionMessage),
    tryCatch(base::table(dt, dt), error = conditionMessage)
  )
})

test_that("base::table() calls stay visible and silent", {
  expect_true(withVisible(table(SEX))$visible)
  expect_silent(table(SEX, DEATH))
})

test_that("a single data.table is described", {
  env <- fresh_env()
  out <- quiet(table(env$DT))
  expect_s3_class(out, "data.table")
  expect_identical(names(out), c("Variable", "N_unique", "Unique_value"))
  expect_identical(out$Variable, names(env$DT))
  expect_identical(nrow(out), ncol(env$DT))
  expect_type(out$N_unique, "integer")
  expect_type(out[["Unique_value"]], "character")
  expect_identical(out$N_unique[out$Variable == "cyl"], 3L)
  expect_identical(out[["Unique_value"]][out$Variable == "cyl"], "4; 6; 8")
  # the description is printed, not returned visibly
  expect_false(withVisible(quiet(table(env$DT)))$visible)
})

test_that("the description is logged", {
  msgs <- dtlog_messages(quote(table(OTHER)))
  expect_identical(msgs[1L], "table: 2 rows and 2 columns")
  expect_match(msgs[2L], "^ +Variable N_unique Unique_value$")
  expect_match(msgs[3L], "^ +cyl +2 +4; 6$")
  expect_match(msgs[4L], "^ +label +2 +four; six$")
  # every line lines up underneath the first
  expect_true(all(startsWith(msgs[-1L], strrep(" ", nchar("table: ")))))
})

test_that("columns that cannot be listed are described instead", {
  dt <- data.table::data.table(
    many = seq_len(25),
    all_na = rep(NA, 25),
    some_na = c(NA, rep(1, 24)),
    long = paste0("value_", sprintf("%02d", seq_len(25) %% 15)),
    lst = rep(list(1:2), 25)
  )
  out <- quiet(table(dt))
  values <- out[["Unique_value"]]
  names(values) <- out$Variable
  expect_identical(values[["many"]], "20+ unique values \u2014 possibly continuous")
  expect_identical(out$N_unique[out$Variable == "many"], 25L)
  expect_identical(values[["all_na"]], "Missing")
  expect_identical(values[["some_na"]], "1; Missing")
  expect_identical(values[["lst"]], "list column")
  expect_identical(out$N_unique[out$Variable == "lst"], NA_integer_)
  expect_match(values[["long"]], "\\.\\.\\.$")
  expect_identical(nchar(values[["long"]]), 80L)
})

test_that("missing values are listed as Missing", {
  dt <- data.table::data.table(
    num = c(1, NA, 2, NA),
    chr = c("a", NA, "b", "b"),
    empty = c("a", "", "b", NA),
    fac = factor(c("yes", NA, "no", "yes")),
    fac_level = addNA(factor(c("yes", NA, "no", "yes"))),
    all_na = rep(NA, 4),
    nan = c(NaN, NA, Inf, 1),
    date = as.Date(c("2020-01-01", NA, "2020-01-02", NA))
  )
  out <- quiet(table(dt))
  values <- out[["Unique_value"]]
  names(values) <- out$Variable
  expect_identical(values[["num"]], "1; 2; Missing")
  expect_identical(values[["chr"]], "a; b; Missing")
  # an empty string is a value of its own, not a missing one
  expect_identical(values[["empty"]], "; a; b; Missing")
  expect_identical(values[["fac"]], "no; yes; Missing")
  # NA as a level of its own (addNA) is missing too
  expect_identical(values[["fac_level"]], "no; yes; Missing")
  expect_identical(values[["all_na"]], "Missing")
  # NaN is missing, but it is not the same value as NA
  expect_identical(values[["nan"]], "1; Inf; NaN; Missing")
  expect_identical(values[["date"]], "2020-01-01; 2020-01-02; Missing")
  # NA counts as one of the unique values, as uniqueN() counts it
  expect_identical(out$N_unique, c(3L, 3L, 4L, 3L, 3L, 1L, 4L, 3L))
})

test_that("a factor carrying NA as a level is missing like any other NA", {
  x <- addNA(factor(c("a", NA, "b")))
  # NA is a level here, not a missing code, so is.na() on the column says no
  expect_false(anyNA(x))
  out <- quiet(table(data.table::data.table(x)))
  expect_identical(out[["Unique_value"]], "a; b; Missing")
  expect_identical(out$N_unique, 3L)
})

test_that("factors, dates and an empty table are described", {
  dt <- data.table::data.table(
    f = factor(c("b", "a", "b")),
    d = as.Date(c("2020-01-02", "2020-01-01", "2020-01-02"))
  )
  out <- quiet(table(dt))
  expect_identical(out[["Unique_value"]], c("a; b", "2020-01-01; 2020-01-02"))
  expect_identical(out$N_unique, c(2L, 2L))

  empty <- quiet(table(data.table::data.table()))
  expect_identical(nrow(empty), 0L)
  expect_identical(names(empty), c("Variable", "N_unique", "Unique_value"))
  expect_identical(dtlog_messages(quote(table(data.table::data.table()))),
                   "table: 0 rows and 0 columns")

  no_rows <- quiet(table(data.table::data.table(a = integer(0))))
  expect_identical(no_rows$N_unique, 0L)
  expect_identical(no_rows[["Unique_value"]], "")
})

test_that("the values are listed in the order the column sorts in", {
  dt <- data.table::data.table(
    int = c(3L, 1L, 10L, 2L),
    dbl = c(2.5, 10, 1 / 3, 0),
    lgl = c(TRUE, FALSE, TRUE, FALSE),
    chr = c("banana", "apple", "cherry", "apple"),
    fac = factor(c("yes", "no", "yes", "no"), levels = c("yes", "no")),
    ord = factor(c("high", "low", "mid", "low"),
                 levels = c("low", "mid", "high"), ordered = TRUE),
    date = as.Date(c("2021-03-01", "2020-01-02", "2020-01-01", "2020-01-01")),
    time = data.table::as.ITime(c("10:00:00", "09:00:00", "23:30:00", "09:00:00")),
    stamp = as.POSIXct(c("2020-01-02 10:00", "2020-01-01 09:00",
                         "2020-01-01 08:00", "2020-01-01 08:00"), tz = "UTC")
  )
  values <- quiet(table(dt))[["Unique_value"]]
  names(values) <- names(dt)
  # numbers in numeric order, not as the text 1, 10, 2, 3
  expect_identical(values[["int"]], "1; 2; 3; 10")
  expect_identical(values[["dbl"]], "0; 0.3333333; 2.5; 10")
  expect_identical(values[["lgl"]], "FALSE; TRUE")
  expect_identical(values[["chr"]], "apple; banana; cherry")
  # a factor keeps the order of its levels, whatever it is
  expect_identical(values[["fac"]], "yes; no")
  expect_identical(values[["ord"]], "low; mid; high")
  expect_identical(values[["date"]], "2020-01-01; 2020-01-02; 2021-03-01")
  # a class writes its own values: an ITime is a time, not the seconds it holds
  expect_identical(values[["time"]], "09:00:00; 10:00:00; 23:30:00")
  expect_identical(values[["stamp"]],
                   paste("2020-01-01 08:00:00", "2020-01-01 09:00:00",
                         "2020-01-02 10:00:00", sep = "; "))
})

test_that("dtlog.table_max_unique moves the point where values stop being listed", {
  dt <- data.table::data.table(a = 1:5)
  old <- options(dtlog.table_max_unique = 5)
  on.exit(options(old), add = TRUE)
  expect_identical(quiet(table(dt))[["Unique_value"]],
                   "5+ unique values \u2014 possibly continuous")
  options(dtlog.table_max_unique = 6)
  expect_identical(quiet(table(dt))[["Unique_value"]], "1; 2; 3; 4; 5")
  # everything is listed, however much there is of it (the 80 character cap
  # still applies, so this stays just under it)
  options(dtlog.table_max_unique = Inf)
  expect_identical(quiet(table(data.table::data.table(a = 1:22)))[["Unique_value"]],
                   paste(1:22, collapse = "; "))
  # a threshold no column can reach lists everything, and does not become the
  # NA that `if` cannot be asked about
  options(dtlog.table_max_unique = 1e10)
  expect_identical(quiet(table(dt))[["Unique_value"]], "1; 2; 3; 4; 5")
  options(dtlog.table_max_unique = .Machine$integer.max + 1)
  expect_identical(quiet(table(dt))[["Unique_value"]], "1; 2; 3; 4; 5")
  # a threshold between two whole numbers is floored, and the message names the
  # number the column was measured against
  options(dtlog.table_max_unique = 3.5)
  expect_identical(quiet(table(dt))[["Unique_value"]],
                   "3+ unique values \u2014 possibly continuous")
  # 20 by default, and for an option that cannot be a threshold
  for (bad in list(NULL, "many", 0, 0.5, -1, NA, c(5, 10), TRUE)) {
    options(dtlog.table_max_unique = bad)
    expect_identical(
      quiet(table(data.table::data.table(a = 1:20)))[["Unique_value"]],
      "20+ unique values \u2014 possibly continuous"
    )
  }
})

test_that("a list column is printed like any other", {
  env <- fresh_env()
  env$WITH_LIST <- data.table::data.table(a = 1:2, lst = list(1:2, "x"))
  msgs <- dtlog_messages(quote(table(WITH_LIST)), env)
  expect_identical(msgs[1L], "table: 2 rows and 2 columns")
  expect_match(msgs[3L], "^ +a +2 +1; 2$")
  # N_unique is NA here, which is a width print has to be given
  expect_match(msgs[4L], "^ +lst +NA +list column$")
})

test_that("variables named in another script are described as they are shown", {
  # the names and the values are written in escapes so that this file stays
  # ASCII, as R CMD check asks a package to be
  skip_if_not(l10n_info()[["UTF-8"]], "not a UTF-8 locale")
  age <- "\u5e74\u9f62"        # nen-rei
  sex <- "\u6027\u5225"        # sei-betsu
  male <- "\u7537\u6027"       # dan-sei
  female <- "\u5973\u6027"     # jo-sei
  env <- fresh_env()
  env$JP <- data.table::data.table(
    c(65L, 72L, 65L, NA),
    factor(c(male, female, male, male), levels = c(male, female)),
    id = 1:4
  )
  data.table::setnames(env$JP, c(age, sex, "id"))

  out <- quiet(eval(quote(table(JP)), env))
  expect_identical(out$Variable, c(age, sex, "id"))
  expect_identical(out[["Unique_value"]],
                   c("65; 72; Missing", paste(male, female, sep = "; "), "1; 2; 3; 4"))

  # one line per variable: a character that takes two columns is measured as
  # two, so print() has the width it needs and wraps nothing
  msgs <- dtlog_messages(quote(table(JP)), env)
  expect_length(msgs, 5L)
  expect_identical(msgs[1L], "table: 4 rows and 3 columns")
  expect_match(msgs[3L], paste0("^ +", age, " +3 +65; 72; Missing$"))
})

test_that("a long list of values is cut to 80 columns, not 80 characters", {
  wide <- data.table::data.table(x = paste0(strrep("\u3042", 8L), 1:12))
  value <- quiet(table(wide))[["Unique_value"]]
  expect_match(value, "\\.\\.\\.$")
  expect_lte(nchar(value, type = "width"), 80L)
  expect_gt(nchar(value, type = "width"), 70L)
})

test_that("values in any script are listed and cut to 80 columns", {
  skip_if_not(l10n_info()[["UTF-8"]], "not a UTF-8 locale")
  scripts <- list(
    hangul = "\uac00", han = "\u4e2d", cyrillic = "\u0434", greek = "\u03b1",
    arabic = "\u0630", hebrew = "\u05d0", thai = "\u0e01", devanagari = "\u0915",
    accented = "\u00e9", emoji = intToUtf8(0x1F642)
  )
  for (nm in names(scripts)) {
    dt <- data.table::data.table(x = paste0(strrep(scripts[[nm]], 8L), 1:12))
    value <- quiet(table(dt))[["Unique_value"]]
    expect_true(endsWith(value, "..."), label = nm)
    # 80 is a display width, and never more characters than that either
    expect_lte(nchar(value, type = "width"), 80L)
    expect_lte(nchar(value), 80L)
  }
})

test_that("a description in any script survives the transcript", {
  skip_if_not(l10n_info()[["UTF-8"]], "not a UTF-8 locale")
  env <- fresh_env()
  env$MULTI <- data.table::data.table(
    "\ub098\uc774" = c(65L, 72L),                                    # Korean
    "\u0432\u043e\u0437\u0440\u0430\u0441\u0442" = c("\u0434\u0430", "\u043d\u0435\u0442"),  # Russian
    "\u03b7\u03bb\u03b9\u03ba\u03af\u03b1" = c("\u03bd\u03ad\u03bf\u03c2", "\u03b3\u03ad\u03c1\u03bf\u03c2")   # Greek
  )
  out <- quiet(eval(quote(table(MULTI)), env))
  expect_identical(out$Variable, names(env$MULTI))
  expect_false(anyNA(out$Unique_value))
  msgs <- dtlog_messages(quote(table(MULTI)), env)
  expect_length(msgs, 5L)
  lines <- table_transcript(eval(quote(table(MULTI)), env))
  expect_true(all(msgs %in% lines))
})

test_that("the description goes into the transcript", {
  env <- fresh_env()
  lines <- table_transcript(eval(quote(table(OTHER)), env))
  expect_true("> table(OTHER)" %in% lines)
  expect_true("table: 2 rows and 2 columns" %in% lines)
  expect_true(any(grepl("cyl +2 +4; 6$", lines)))
  expect_match(lines[length(lines)], "\\(one operation\\)$")
})

test_that("table() obeys dtlog_pause()", {
  env <- fresh_env()
  dtlog_pause()
  on.exit(dtlog_resume(), add = TRUE)
  expect_silent(paused <- eval(quote(table(OTHER)), env))
  dtlog_resume()
  expect_identical(canonical(paused), canonical(quiet(eval(quote(table(OTHER)), env))))
})

test_that("table() reads its argument once and changes nothing", {
  env <- fresh_env()
  dt <- env$DT
  before <- canonical(dt)
  addresses <- vapply(dt, data.table::address, character(1L))

  calls <- 0L
  counted <- function(x) {
    calls <<- calls + 1L
    x
  }
  loud(table(counted(dt)))
  expect_identical(calls, 1L)
  loud(table(counted(dt$cyl), counted(dt$gear)))
  expect_identical(calls, 3L)

  expect_identical(canonical(dt), before)
  expect_identical(vapply(dt, data.table::address, character(1L)), addresses)
})
