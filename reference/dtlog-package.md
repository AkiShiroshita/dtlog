# dtlog: logging for data.table operations

\`dtlog\` provides feedback about \`data.table\` operations. It
redefines the subsetting method \`\[.data.table\` as well as several
functions exported by \`data.table\`, so it should be loaded
\*\*after\*\* \`data.table\`, otherwise there will be no output. A more
explicit way to resolve namespace conflicts is to use the \`conflicted\`
package.

## Details

The operations themselves are never changed: \`dtlog\` only adds a
message. Modification by reference (\`:=\`, \`set\*()\`), keys, indices,
return values and visibility all behave exactly as they do in
\`data.table\`. The one thing that is not identical is that \`with=\`
and \`which=\` are evaluated twice, once by \`dtlog\` to classify the
call and once by \`data.table\`; this is only noticeable if such an
argument is written as an expression with a side effect.

## Options

- \`dtlog.display\`:

  \`NULL\` (default) prints with \[message()\]. A list of functions
  sends the output to each of them. An empty list turns logging off, as
  does anything that is not a function, which is ignored.

- \`dtlog.detail\`:

  \`"full"\` (default) reports value level information (types, unique
  values, share of \`NA\`, number of changed values). \`"compact"\` only
  reports rows, columns and column names, and never copies data.

- \`dtlog.log_from_packages\`:

  \`FALSE\` (default) only logs calls made from the global environment,
  so that \`data.table\` calls inside other packages stay silent.

- \`dtlog.table_max_unique\`:

  \`20\` (default). A column with this many unique values or more is
  described by \[dttable()\] as possibly continuous instead of having
  its values listed. \`Inf\` lists every column.

## See also

Useful links:

- <https://github.com/AkiShiroshita/dtlog>

- <https://akishiroshita.github.io/dtlog/>

- Report bugs at <https://github.com/AkiShiroshita/dtlog/issues>

## Author

**Maintainer**: Akihiro Shiroshita <akihirokun8@gmail.com>
([ORCID](https://orcid.org/0000-0003-0262-459X)) \[copyright holder\]

Authors:

- Akihiro Shiroshita <akihirokun8@gmail.com>
  ([ORCID](https://orcid.org/0000-0003-0262-459X)) \[copyright holder\]
