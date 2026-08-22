# Pause and resume logging

\`dtlog_pause()\` turns off all \`dtlog\` messages without detaching the
package, \`dtlog_resume()\` turns them back on. This is useful for a
block of code that would otherwise produce a lot of output.

## Usage

``` r
dtlog_pause()

dtlog_resume()
```

## Value

Invisibly the logging state \*before\* the call: \`TRUE\` if logging was
active, \`FALSE\` if it was paused. Both functions report the state they
found rather than the one they left behind, so \`dtlog_pause()\` returns
\`TRUE\` when it is the call that actually paused logging, and
\`dtlog_resume()\` returns \`FALSE\` when it is the call that actually
resumed it.

## Examples

``` r
dtlog_pause()
dtlog_resume()
```
