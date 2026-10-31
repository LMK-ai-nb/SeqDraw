# SeqDraw

Render sequence diagrams as terminal text. Write a five-line description of a
call flow, get an aligned diagram you can paste into a README, a CI log, a pull
request description or a terminal.

```
 ┌────────┐    ┌────────┐
 │ Client │    │ Server │
 └────┬───┘    └────┬───┘
      │    ping     │
      │────────────>│
      │    pong     │
      │┄┄┄┄┄┄┄┄┄┄┄┄>│
      │             │
```

## Why this exists

Diagrams that live in a browser do not survive a terminal, a CI log or a code
review. SeqDraw keeps the source in the repository as plain text and produces
output that is readable wherever plain text is readable, with no runtime, no
image files and no font fallback to worry about.

The value is in the layout: columns are sized from the labels, lifelines keep
their position across every row, and double-width characters (Chinese, Japanese,
Korean, emoji) advance exactly two cells so the box borders stay aligned.

## Install

```
moon add LMK-ai-nb/seqdraw
```

## Command line

```
moon run cmd/main -- examples/login.seq
```

The command reads one file and prints the diagram. The grammar is documented
below; `examples/` holds three runnable diagrams.

## Grammar

One construct per line. Blank lines, `#` and `//` comments are ignored.

| Line | Meaning |
| --- | --- |
| `participant A as Client` | declare a column; the label is optional and defaults to the id |
| `A -> B: text` | solid arrow with a filled head |
| `A --> B: text` | dashed arrow |
| `A ->> B: text` | solid arrow with an open head |
| `A -->> B: text` | dashed arrow with an open head |
| `A -> A: text` | self message, drawn as a loop |
| `note over A: text` | note box over one column |
| `note over A,B: text` | note box spanning two columns |
| `alt label` / `else label` / `end` | conditional block |
| `loop label` / `end` | repeated block |
| `opt label` / `end` | optional block |

Participants are created on first use, so the `participant` line is only needed
when the label differs from the id. Blocks nest.

## Library

```moonbit
match @seqdraw.parse(source) {
  Err(err) => println(err.to_text())
  Ok(diagram) => println(@seqdraw.render(diagram))
}
```

`parse` returns a `Diagram` of participants and items; `render` turns it back
into text. Both are pure: no file or terminal access, so the renderer runs on
wasm, wasm-gc, js and native.

## Examples

| File | Shows |
| --- | --- |
| `examples/login.seq` | three columns, a conditional block, a note |
| `examples/payment.seq` | self messages, a nested loop inside a condition |
| `examples/pipeline.seq` | short labels and a two-branch hand-off |

## Design notes

- **Column geometry.** The space between two lifelines is the smallest distance
  that still fits the widest label crossing it; labels spanning several columns
  push the involved gaps until the text fits. This is computed once, before any
  row is painted.
- **Cell grid.** Rows are arrays of cells, not strings, so a wide character can
  mark the cell it covers as occupied without faking a space. The final string
  drops those markers, which is why box borders line up under CJK text.
- **Group frames.** Nesting depth decides how far a frame is inset; the frame is
  painted after its body, so the vertical borders pass over every row it owns.

## Boundaries

- Text only. No colours, no box styles, no themes.
- One note per line; multi-line notes are not implemented.
- Long labels widen the canvas instead of wrapping.
- The DSL is read line by line; a construct cannot span two lines.

## Tests

```
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc
```

The suite covers width accounting for wide characters, clipping, parsing,
line-numbered errors, unclosed blocks and a golden rendering.

## License

Apache-2.0. See `LICENSE`.
