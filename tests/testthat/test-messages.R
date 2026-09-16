test_that("i produces filter and arrange messages", {
  expect_dtlog_message(quote(DT[mpg > 20]),
                       "filter: removed 18 rows \\(56%\\), 14 rows remaining")
  expect_dtlog_message(quote(DT[mpg > 0]), "filter: no rows removed")
  expect_dtlog_message(quote(DT[mpg > 1000]), "filter: removed all rows")
  expect_dtlog_message(quote(DT[order(-mpg)]), "arrange: reordered 32 rows")
  expect_dtlog_message(quote(OTHER[c(1, 1, 2)]), "filter: added one row, 3 rows total")
  expect_dtlog_message(quote(DT[mpg > 20, which = TRUE]),
                       "which: 14 out of 32 rows match \\(44%\\)")
})

test_that("j produces select, mutate and summarize messages", {
  expect_dtlog_message(quote(DT[, .(car, mpg)]),
                       "select: dropped 10 variables \\(cyl, disp, hp, drat, wt, \u2026\\)")
  msgs_t <- dtlog_messages(quote(DT[, .(mpg2 = mpg * 2)]))
  expect_match(msgs_t[1L],
               "^transmute: new variable 'mpg2' \\(double\\) with 25 unique values and 0% NA$")
  expect_match(msgs_t[2L], "dropped 12 variables")
  expect_dtlog_message(quote(DT[, .SD]), "select: no changes")
  expect_dtlog_message(quote(OTHER[, c("cyl", "label"), with = FALSE]),
                       "select: no changes")
  expect_dtlog_message(quote(OTHER[, .(label, cyl)]),
                       "select: columns reordered \\(label, cyl\\)")
  expect_dtlog_message(quote(OTHER[, lapply(.SD, identity)]),
                       "mutate: no changes")
  expect_dtlog_message(quote(DT[, sum(mpg)]),
                       "summarize: returned one value \\(double\\)")
  expect_dtlog_message(quote(DT[, mpg]),
                       "summarize: returned double of length 32")
  msgs <- dtlog_messages(quote(DT[, .(m = mean(mpg)), by = cyl]))
  expect_match(msgs[1L], "group_by: one grouping variable \\(cyl\\)")
  expect_match(msgs[2L], "summarize: now 3 rows and 2 columns \\(was 32 rows and 12 columns\\)")
})

test_that(":= produces mutate messages", {
  env <- fresh_env()
  expect_dtlog_message(quote(DT[, kpl := mpg * 0.425]),
                       "mutate: new variable 'kpl' \\(double\\)", env)
  expect_dtlog_message(quote(DT[cyl == 4, mpg := NA]),
                       "mutate: changed 11 values \\(34%\\) of 'mpg' \\(11 new NAs\\)", env)
  expect_dtlog_message(quote(DT[, kpl := as.integer(kpl)]),
                       "mutate: converted 'kpl' from double to integer \\(0 new NA\\)", env)
  expect_dtlog_message(quote(DT[, kpl := NULL]),
                       "mutate: dropped one variable \\(kpl\\)", env)
  expect_dtlog_message(quote(DT[, hp := hp]), "mutate: no changes to 'hp'", env)
  expect_dtlog_message(quote(DT[, mean_hp := mean(hp), by = cyl]),
                       "mutate \\(by cyl\\): new variable 'mean_hp'", env)
  msgs <- dtlog_messages(quote(DT[, `:=`(one = 1, two = 2)]), env)
  expect_length(msgs, 2L)
  expect_match(msgs[2L], "^ {8}new variable 'two'")
})

test_that(":= names the column type a factor or a list column was given", {
  env <- fresh_env()
  expect_dtlog_message(
    quote(DT[, grade := factor(ifelse(mpg > 20, "high", "low"))]),
    "mutate: new variable 'grade' \\(factor\\) with 2 unique values and 0% NA",
    env)
  # an ordered factor is a factor, and has to be recognised before one
  expect_dtlog_message(
    quote(DT[, rank := ordered(cyl, levels = c(4, 6, 8))]),
    "mutate: new variable 'rank' \\(ordered factor\\) with 3 unique values",
    env)
  # uniqueN() means nothing for a column whose cells are vectors, and is.na()
  # on one is elementwise, so neither number is claimed for a list column
  expect_dtlog_message(quote(DT[, parts := .(list(1:2))]),
                       "mutate: new variable 'parts' \\(list\\) with 0% NA", env)
  # a factor is compared as character: `!=` on two factors would warn about
  # their level sets, and dtlog's own comparison must not warn at the caller.
  # loud() keeps the log running while sending its output to a collector, so a
  # warning raised on the way to the message is the only thing left to escape.
  expect_dtlog_message(quote(DT[1L, grade := "low"]),
                       "mutate: changed one value \\(3%\\) of 'grade'", env)
  expect_silent(loud(eval(quote(DT[2L, grade := "low"]), env)))
})

test_that("a single NA gained or recovered is reported in the singular", {
  env <- fresh_env()
  expect_dtlog_message(quote(WITH_NA[1L, a := NA]),
                       "changed one value \\(33%\\) of 'a' \\(one new NA\\)", env)
  expect_dtlog_message(quote(WITH_NA[2L, a := 2]),
                       "changed one value \\(33%\\) of 'a' \\(one fewer NA\\)", env)
})

test_that("an aggregating j is not reported as a filter", {
  # the row count of the result says nothing about how many rows i selected
  expect_identical(
    dtlog_messages(quote(DT[mpg > 20, .(m = mean(mpg))])),
    "summarize: now one row and one column (was 32 rows and 12 columns, after filtering with i)"
  )
  msgs <- dtlog_messages(quote(DT[mpg > 20, .N, by = cyl]))
  expect_match(msgs[1L], "^group_by: one grouping variable \\(cyl\\)$")
  expect_match(msgs[2L], "after filtering with i")

  # a j that only selects columns leaves the rows to i, so both are reported
  msgs2 <- dtlog_messages(quote(DT[mpg > 20, .(car, mpg)]))
  expect_match(msgs2[1L], "^filter: removed 18 rows")
  expect_match(msgs2[2L], "^select: dropped 10 variables")
  msgs3 <- dtlog_messages(quote(DT[mpg > 20, cols, with = FALSE]))
  expect_match(msgs3[1L], "^filter: removed 18 rows")
  expect_match(msgs3[2L], "^select: dropped 10 variables")

  # a j that computes columns without aggregating leaves the rows to i as well
  msgs4 <- dtlog_messages(quote(DT[mpg > 20, .(car, kpl = mpg * 0.425)]))
  expect_match(msgs4[1L], "^filter: removed 18 rows \\(56%\\), 14 rows remaining$")
  expect_match(msgs4[2L], "^mutate: new variable 'kpl' \\(double\\)")
  expect_match(msgs4[3L], "dropped 11 variables")
  msgs5 <- dtlog_messages(quote(DT[mpg > 1000, .(car, kpl = mpg * 0.425)]))
  expect_match(msgs5[1L], "^filter: removed all rows \\(100%\\)$")

  # aggregation without i keeps the plain wording
  expect_identical(
    dtlog_messages(quote(DT[, lapply(.SD, mean), .SDcols = c("mpg", "hp")])),
    "summarize: now one row and 2 columns (was 32 rows and 12 columns)"
  )
})

test_that("a j that computes its columns is not reported as a select", {
  # every name it returns was already there, but the values were computed
  msgs <- dtlog_messages(quote(DT[, .(car, mpg = as.integer(mpg))]))
  expect_match(msgs[1L], "^mutate: dropped 10 variables")
  expect_match(msgs[2L], "converted 'mpg' from double to integer \\(0 new NA\\)$")
  msgs2 <- dtlog_messages(quote(DT[, .(mpg = mpg * 2)]))
  expect_match(msgs2[1L], "^mutate: dropped 11 variables")
  expect_match(msgs2[2L], "changed 32 values \\(100%\\) of 'mpg' \\(0 new NAs\\)$")

  # the rows do not line up after a filter, but the type change still shows
  msgs3 <- dtlog_messages(quote(DT[mpg > 20, .(car, mpg = as.integer(mpg))]))
  expect_match(msgs3[1L], "^filter: removed 18 rows")
  expect_match(msgs3[3L], "converted 'mpg' from double to integer$")

  # excluding columns by name is still a select
  expect_identical(dtlog_messages(quote(DT[, !c("vs", "am")])),
                   "select: dropped 2 variables (vs, am)")
  expect_identical(dtlog_messages(quote(DT[, -c("vs", "am")])),
                   "select: dropped 2 variables (vs, am)")
  expect_identical(dtlog_messages(quote(DT[, !"vs"])),
                   "select: dropped one variable (vs)")
  # -mpg negates the column, it does not leave it out
  expect_match(dtlog_messages(quote(DT[, -mpg]))[1L], "^summarize: returned double")

  # DT[, ..cols] takes the names from a variable and is a select as well
  expect_match(dtlog_messages(quote(DT[, ..cols]))[1L],
               "^select: dropped 10 variables \\(car, mpg, cyl, disp, drat, …\\)$")
  msgs4 <- dtlog_messages(quote(DT[mpg > 20, ..cols]))
  expect_match(msgs4[1L], "^filter: removed 18 rows")
  expect_match(msgs4[2L], "^select: dropped 10 variables")
})

test_that("the special variables are reported through the surrounding call", {
  env <- fresh_env()
  expect_dtlog_message(quote(DT[, n := .N, by = cyl]),
                       "mutate \\(by cyl\\): new variable 'n' \\(integer\\)", env)
  expect_dtlog_message(quote(DT[, grp := .GRP, by = cyl]),
                       "mutate \\(by cyl\\): new variable 'grp' \\(integer\\)", env)
  expect_dtlog_message(quote(DT[, lag_mpg := data.table::shift(mpg)]),
                       "mutate: new variable 'lag_mpg' \\(double\\) with .* and 3% NA", env)
  msgs <- dtlog_messages(quote(DT[, lapply(.SD, mean), by = cyl,
                                  .SDcols = c("mpg", "hp")]), env)
  expect_match(msgs[2L], "^summarize: now 3 rows and 3 columns")
})

test_that("joins report the columns and rows they add", {
  msgs <- dtlog_messages(quote(DT[OTHER, on = "cyl"]))
  expect_match(msgs[1L], "^join \\(on cyl\\): added one column \\(label\\)$")
  expect_match(msgs[2L], "rows: was 32, now 18 \\(-14\\)")
  # .() cannot be evaluated outside data.table, but still reads as a column
  expect_match(dtlog_messages(quote(DT[OTHER, on = .(cyl)]))[1L],
               "^join \\(on cyl\\): ")
  expect_match(dtlog_messages(quote(DT[OTHER, on = c(cyl = "cyl")]))[1L],
               "^join \\(on cyl == cyl\\): ")
})

test_that("by= names the columns data.table actually grouped by", {
  env <- fresh_env()
  # a variable in the caller must not shadow a column of the same name: inside
  # by= the columns win, so resolving the caller first would name the wrong one
  env$cyl <- "gear"
  expect_match(dtlog_messages(quote(DT[, .N, by = cyl]), env)[1L],
               "^group_by: one grouping variable \\(cyl\\)$")
  # a variable that is not a column does supply the names
  expect_match(dtlog_messages(quote(DT[, .N, by = cols]), env)[1L],
               "^group_by: 2 grouping variables \\(hp, wt\\)$")
  # c("a", "b") reads the same as .(a, b), without the quotes
  expect_match(dtlog_messages(quote(DT[, .N, by = c("cyl", "gear")]), env)[1L],
               "^group_by: 2 grouping variables \\(cyl, gear\\)$")
  expect_match(dtlog_messages(quote(DT[, .N, by = .(cyl, gear)]), env)[1L],
               "^group_by: 2 grouping variables \\(cyl, gear\\)$")
})

test_that("merge reports the join type and the matching", {
  msgs <- dtlog_messages(quote(merge(DT, OTHER, by = "cyl", all.x = TRUE)))
  expect_match(msgs[1L], "^left_join: added one column \\(label\\)")
  expect_match(msgs[2L], "rows only in DT\\s+14")
  expect_match(msgs[3L], "rows only in OTHER\\s+\\( 0\\)")
  expect_match(msgs[4L], "matched rows\\s+18")
  expect_match(msgs[6L], "rows total\\s+32")
  expect_match(dtlog_messages(quote(merge(DT, OTHER, by = "cyl")))[1L], "^inner_join")
  expect_match(dtlog_messages(quote(merge(DT, OTHER, by = "cyl", all = TRUE)))[1L],
               "^full_join")
})

test_that("merge without by= counts on the key, like merge.data.table does", {
  env <- fresh_env()
  # the two tables share more columns than their key; data.table joins on the
  # key alone, so the unmatched rows have to be counted on the key alone too
  env$A <- data.table::data.table(id = 1:4, grp = c(1, 1, 2, 2), v = 1:4,
                                  key = "id")
  env$B <- data.table::data.table(id = 3:6, grp = c(9, 9, 9, 9), w = 1:4,
                                  key = "id")
  msgs <- dtlog_messages(quote(merge(A, B)), env)
  expect_match(msgs[1L], "^inner_join: added 3 columns \\(grp\\.x, grp\\.y, w\\)$")
  expect_match(msgs[2L], "rows only in A\\s+\\(2\\)")
  expect_match(msgs[3L], "rows only in B\\s+\\(2\\)")
  # no "(includes duplicates)": there are none once the key is used
  expect_match(msgs[4L], "matched rows\\s+2$")
  expect_match(msgs[6L], "rows total\\s+2$")
})

test_that("the other wrapped functions report what they did", {
  expect_dtlog_message(quote(unique(DT, by = "cyl")),
                       "distinct: removed 29 rows \\(91%\\), 3 rows remaining")
  expect_dtlog_message(quote(duplicated(DT, by = "cyl")),
                       "duplicated: 29 of 32 rows marked as duplicates")
  expect_dtlog_message(quote(stats::na.omit(WITH_NA)),
                       "drop_na: removed 2 rows \\(67%\\), one row remaining")
  expect_dtlog_message(quote(rbindlist(list(OTHER, OTHER))),
                       "rbindlist: combined 2 tables into 4 rows and 2 columns")
  expect_dtlog_message(quote(funion(OTHER, HALF)),
                       "funion: 2 rows and one row in, 2 rows out")
  expect_dtlog_message(quote(melt(WIDE, id.vars = "id")),
                       "melt: reorganized \\(p, q\\) into \\(variable, value\\) \\[was 2x3, now 4x3\\]")
  expect_dtlog_message(
    quote(melt(WIDE, id.vars = "id", measure.vars = "p", value.name = "val")),
    "melt: reorganized \\(p\\) into \\(variable, val\\) \\[was 2x3, now 2x3\\], dropped one variable \\(q\\)"
  )
  # column numbers have to be resolved to names, or q reads as reorganized
  expect_dtlog_message(
    quote(melt(WIDE, id.vars = "id", measure.vars = 2L)),
    "melt: reorganized \\(p\\) into \\(variable, value\\) \\[was 2x3, now 2x3\\], dropped one variable \\(q\\)"
  )
  # patterns() never evaluates outside melt(), so the stacked columns are read
  # off the result rather than off the argument
  expect_dtlog_message(
    quote(melt(WIDE, id.vars = "id", measure.vars = data.table::patterns("^p"))),
    "melt: reorganized \\(p\\) into \\(variable, value\\) \\[was 2x3, now 2x3\\], dropped one variable \\(q\\)"
  )
  # a multi-value melt numbers its groups instead of naming them, and then
  # nothing is reported as dropped rather than the wrong thing
  expect_dtlog_message(
    quote(melt(WIDE, id.vars = "id", measure.vars = list("p", "q"))),
    "melt: reorganized \\(p, q\\) into \\(variable, value1, value2\\)"
  )
  expect_dtlog_message(quote(dcast(LONG, id ~ variable)),
                       "dcast: reorganized \\(variable, value\\) into \\(p, q\\)")
  expect_dtlog_message(quote(head(DT, 5)),
                       "head: removed 27 rows \\(84%\\), 5 rows remaining")
  expect_dtlog_message(quote(tail(DT, 5)),
                       "tail: removed 27 rows \\(84%\\), 5 rows remaining")
  expect_dtlog_message(quote(head(DT, 100)), "head: no rows removed")
  expect_dtlog_message(quote(stats::na.omit(WITH_NA, invert = TRUE)),
                       "na.omit \\(invert\\): kept the 2 rows with NA")
  expect_dtlog_message(quote(fread(text = "a,b\n1,2")),
                       "fread: read one row and 2 columns")
  expect_dtlog_message(quote(fwrite(OTHER, TMPFILE)),
                       "fwrite: wrote 2 rows and 2 columns to '.*\\.csv'")
  expect_dtlog_message(quote(fwrite(OTHER, TMPFILE, append = TRUE)),
                       "fwrite: appended 2 rows and 2 columns")
  expect_dtlog_message(quote(as.data.table(as.data.frame(OTHER))),
                       "as.data.table: converted data.frame to data.table \\(2 rows, 2 columns\\)")
  expect_dtlog_message(quote(as.data.table(head(mtcars, 3), keep.rownames = "car")),
                       "as.data.table: converted data.frame to data.table \\(3 rows, 12 columns\\), added \\(car\\)")
})

test_that("setorder() reports whether any row actually moved", {
  env <- fresh_env()
  env$S <- data.table::data.table(a = c(3, 1, 2), b = 1)
  expect_dtlog_message(quote(setorder(S, a)), "arrange: sorted 3 rows by \\(a\\)", env)
  expect_dtlog_message(quote(setorder(S, a)), "setorder: no changes", env)
  expect_dtlog_message(quote(setorderv(S, "a")), "setorderv: no changes", env)
  expect_dtlog_message(quote(setorder(S, a, b)), "setorder: no changes", env)
  expect_dtlog_message(quote(setnames(S, "a", "a")), "setnames: no changes", env)
  # an expression is not a column name, so there is nothing to compare against
  expect_dtlog_message(quote(setorder(S, -a)), "arrange: sorted 3 rows by \\(-a\\)", env)

  # detail = "compact" never copies, so it cannot compare either
  old <- options(dtlog.detail = "compact")
  on.exit(options(old), add = TRUE)
  expect_dtlog_message(quote(setorder(S, a)), "arrange: sorted 3 rows by \\(a\\)", env)
  expect_dtlog_message(quote(setorder(S, a)), "arrange: sorted 3 rows by \\(a\\)", env)
})

test_that("setattr() reports what it did to the attribute", {
  env <- fresh_env()
  env$A <- data.table::data.table(u = 1:2)
  expect_dtlog_message(quote(setattr(A, "note", "hello")),
                       "setattr: added attribute 'note' by reference", env)
  expect_dtlog_message(quote(setattr(A, "note", "hello")),
                       "setattr: no changes to attribute 'note'", env)
  expect_dtlog_message(quote(setattr(A, "note", "bye")),
                       "setattr: changed attribute 'note' by reference", env)
  expect_dtlog_message(quote(setattr(A, "note", NULL)),
                       "setattr: removed attribute 'note' by reference", env)
  # setattr() rewrites the very vector that attr() hands out, so the old value
  # has to be copied before the call or every change would look like none
  expect_dtlog_message(quote(setattr(A, "names", "v")),
                       "setattr: changed attribute 'names' by reference", env)
})

test_that("the set functions report what they changed", {
  env <- fresh_env()
  expect_dtlog_message(quote(setnames(DT, "mpg", "miles")),
                       "rename: renamed one variable \\(mpg -> miles\\)", env)
  expect_dtlog_message(quote(setcolorder(DT, c("miles", "car"))),
                       "relocate: columns reordered \\(miles, car, cyl, disp, hp, \u2026\\)", env)
  expect_dtlog_message(quote(setkey(DT, cyl)), "setkey: keyed by \\(cyl\\), 32 rows sorted", env)
  expect_dtlog_message(quote(setkey(DT, NULL)), "setkey: removed the key \\(was cyl\\)", env)
  expect_dtlog_message(quote(setorder(DT, -miles)), "arrange: sorted 32 rows by \\(-miles\\)", env)
  expect_dtlog_message(quote(setorderv(DT, "cyl")), "arrange: sorted 32 rows by \\(cyl\\)", env)
  expect_dtlog_message(quote(setindex(DT, gear)), "setindex: added index \\(gear\\)", env)
  expect_dtlog_message(quote(set(DT, i = 1L, j = "miles", value = 0)),
                       "set: changed one value \\(3%\\) of 'miles'", env)
  expect_dtlog_message(quote(set(DT, j = "gear", value = NULL)),
                       "set: dropped one variable \\(gear\\)", env)
  expect_dtlog_message(quote(DT[, c("vs", "am") := NULL]),
                       "mutate: dropped 2 variables \\(vs, am\\)", env)
  expect_dtlog_message(quote(setDF(DT)), "setDF: converted data.table to data.frame", env)
  expect_dtlog_message(quote(setDT(DT)), "setDT: converted data.frame to data.table", env)
})

test_that("options control the output", {
  env <- fresh_env()
  old <- options(dtlog.display = list())
  expect_silent(eval(quote(DT[mpg > 20]), env))
  options(old)

  collected <- character()
  old <- options(dtlog.display = list(function(x) collected <<- c(collected, x)))
  eval(quote(DT[mpg > 20]), env)
  options(old)
  expect_length(collected, 1L)
  expect_match(collected, "^filter: removed")

  dtlog_pause()
  expect_silent(eval(quote(DT[mpg > 20]), env))
  dtlog_resume()
  expect_message(eval(quote(DT[mpg > 20]), env), "filter")
})

test_that("pause and resume report the state they found", {
  on.exit(dtlog_resume(), add = TRUE)
  # the call that actually pauses reports that logging was active
  expect_true(dtlog_pause())
  # and a second one reports that it was already paused
  expect_false(dtlog_pause())
  # the call that actually resumes reports that logging was paused
  expect_false(dtlog_resume())
  expect_true(dtlog_resume())
  # both return their answer invisibly
  expect_false(withVisible(dtlog_pause())$visible)
  expect_false(withVisible(dtlog_resume())$visible)
})

test_that("the compact detail level avoids value level information", {
  env <- fresh_env()
  old <- options(dtlog.detail = "compact")
  on.exit(options(old), add = TRUE)
  expect_identical(dtlog_messages(quote(DT[, kpl := mpg * 0.425]), env),
                   "mutate: new variable 'kpl' (double)")
  msgs <- dtlog_messages(quote(DT[, kpl := 2]), env)
  expect_identical(msgs, "mutate: updated one variable (kpl)")
  msgs2 <- dtlog_messages(quote(merge(DT, OTHER, by = "cyl")), env)
  expect_match(msgs2[2L], "rows: was 32, now 18")
})

test_that("foverlaps reports the rows it matched and the columns it added", {
  env <- fresh_env()
  expect_dtlog_message(
    quote(foverlaps(SPAN, WINDOW)),
    "^foverlaps: 3 rows in, 3 rows out, added 2 columns \\(i\\.s, i\\.e\\)", env)
  # which = TRUE answers with row numbers, and none of x's columns come back
  expect_dtlog_message(quote(foverlaps(SPAN, WINDOW, which = TRUE)),
                       "^foverlaps: 3 rows in, 3 matching pairs out", env)
  expect_dtlog_message(
    quote(foverlaps(SPAN, WINDOW, which = TRUE, mult = "first")),
    "^foverlaps: 3 rows in, 3 row numbers out", env)
})

test_that("setnafill reports the NAs it filled and the ones it left", {
  env <- fresh_env()
  expect_dtlog_message(quote(setnafill(NAFILL, type = "const", fill = 0)),
                       "^setnafill: filled 4 NAs in 2 columns \\(a, b\\)", env)
  # the second call has nothing left to do
  expect_dtlog_message(quote(setnafill(NAFILL, type = "const", fill = 0)),
                       "^setnafill: no NAs to fill", env)
  env2 <- fresh_env()
  expect_dtlog_message(
    quote(setnafill(NAFILL, type = "const", fill = 0, cols = "a")),
    "^setnafill: filled 2 NAs in one column \\(a\\), 2 NAs remaining", env2)
})

test_that("setdroplevels names the levels it dropped", {
  env <- fresh_env()
  expect_dtlog_message(quote(setdroplevels(FACTORS)),
                       "^setdroplevels: dropped 2 levels from 2 columns \\(k: c, m: q\\)",
                       env)
  expect_dtlog_message(quote(setdroplevels(FACTORS)),
                       "^setdroplevels: no levels dropped", env)
})

test_that("an aggregation over grouping sets reports itself once", {
  env <- fresh_env()
  # data.table runs one `x[, j, by]` per grouping set and evaluates each of them
  # in the caller's frame, so without the wrapper silencing them the user would
  # read four group_by/summarize pairs for one rollup()
  expect_identical(
    dtlog_messages(quote(rollup(GROUPS, j = sum(v), by = c("g", "h"))), env),
    "rollup: now 6 rows and 3 columns (was 3 rows and 3 columns)")
  expect_identical(
    dtlog_messages(quote(cube(GROUPS, j = sum(v), by = c("g", "h"))), env),
    "cube: now 8 rows and 3 columns (was 3 rows and 3 columns)")
  expect_identical(
    dtlog_messages(quote(groupingsets(GROUPS, j = sum(v), by = c("g", "h"),
                                      sets = list("g", "h"))), env),
    "groupingsets: now 4 rows and 3 columns (was 3 rows and 3 columns)")
  # the silence lasts exactly as long as the call
  expect_dtlog_message(quote(GROUPS[v > 1]), "^filter: removed one row", env)

  # a result that is not the shape the log expects is passed over rather than
  # described wrongly. No call a user can write gets here, so it is checked
  # directly, as the reshape fallbacks are.
  expect_silent(log_grouping_sets("rollup")(1:3, list(), NULL, NULL))
  expect_silent(log_split(1:3, list(), NULL, NULL))
})

test_that("an error inside a silenced call still leaves logging on", {
  env <- fresh_env()
  expect_error(eval(quote(rollup(GROUPS, j = stop("boom"), by = "g")), env),
               "boom")
  expect_dtlog_message(quote(GROUPS[v > 1]), "^filter: removed one row", env)
})

test_that("a call made while logging is paused leaves it paused", {
  env <- fresh_env()
  quiet(dtlog_pause())
  on.exit(quiet(dtlog_resume()), add = TRUE)
  expect_silent(eval(quote(rollup(GROUPS, j = sum(v), by = "g")), env))
  expect_silent(eval(quote(GROUPS[v > 1]), env))
})

test_that("the remaining wrapped functions report what they did", {
  env <- fresh_env()
  expect_dtlog_message(quote(fsetequal(OTHER, OTHER)),
                       "^fsetequal: the two tables hold the same rows \\(2 rows each\\)",
                       env)
  expect_dtlog_message(
    quote(fsetequal(OTHER, HALF)),
    "^fsetequal: the two tables do not hold the same rows \\(2 rows and one row\\)",
    env)
  # the two split messages differ only by a suffix, so they are compared whole
  expect_identical(dtlog_messages(quote(split(GROUPS, by = "g")), env),
                   "split: 3 rows into 2 tables (a: 2 rows, b: one row)")
  # splitting on two columns without flattening nests one list inside another,
  # and then there is no row count to report for the parts
  expect_identical(
    dtlog_messages(quote(split(GROUPS, by = c("g", "h"), flatten = FALSE)), env),
    "split: 3 rows into 2 tables")
  expect_dtlog_message(quote(copy(OTHER)),
                       "^copy: deep copy of 2 rows and 2 columns", env)
  expect_dtlog_message(quote(copy(1:5)), "^copy: deep copy \\(length 5\\)", env)
})

test_that("calls from other packages are silent by default", {
  # data.table calls inside a package namespace must not produce output
  f <- function() {
    dt <- data.table::data.table(a = 1:3)
    dt[a > 1]
  }
  environment(f) <- asNamespace("dtlog")
  expect_silent(f())

  old <- options(dtlog.log_from_packages = TRUE)
  on.exit(options(old), add = TRUE)
  expect_message(f(), "filter")
})
