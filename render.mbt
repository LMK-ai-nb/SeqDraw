///|
/// Rendering engine: computes column geometry, then paints rows onto a
/// fixed-width grid of cells so wide characters keep every column aligned.
const SKIP : Char = '\u{0}'

///|
fn blank(width : Int32) -> Array[Char] {
  Array::make(width, ' ')
}

///|
fn put_cell(row : Array[Char], col : Int32, c : Char) -> Unit {
  if col >= 0 && col < row.length() {
    row[col] = c
  }
}

///|
/// Write text at a column, advancing by display width. The second cell of a
/// wide character is marked SKIP so it is dropped when the row is joined.
fn put_text(row : Array[Char], col : Int32, text : String) -> Unit {
  let mut x = col
  for c in text {
    let w = char_width(c)
    if w == 0 {
      continue
    }
    put_cell(row, x, c)
    if w == 2 {
      put_cell(row, x + 1, SKIP)
    }
    x = x + w
  }
}

///|
fn fill_run(row : Array[Char], from : Int32, to : Int32, c : Char) -> Unit {
  let mut x = from
  while x <= to {
    put_cell(row, x, c)
    x = x + 1
  }
}

///|
/// A body row with every lifeline already drawn, so messages and boxes only
/// overwrite the cells they own.
fn body_row(
  width : Int32,
  centers : Array[Int32],
  margin : Int32,
) -> Array[Char] {
  let row = blank(width)
  let mut i = 0
  while i < centers.length() {
    put_cell(row, margin + centers[i], '│')
    i = i + 1
  }
  row
}

///|
fn row_to_string(row : Array[Char]) -> String {
  let sb = StringBuilder()
  for c in row {
    if c != SKIP {
      sb.write_char(c)
    }
  }
  sb.to_string().trim_end(chars=" ").to_owned()
}

///|
fn index_of_participant(d : Diagram, id : String) -> Int32 {
  let mut i = 0
  while i < d.participants.length() {
    if d.participants[i].id == id {
      return i
    }
    i = i + 1
  }
  0
}

///|
/// Center distance required between neighbour i and i+1 by the widest label
/// that has to fit between the two lifelines.
fn required_steps(d : Diagram) -> Array[Int32] {
  let n = d.participants.length()
  let steps : Array[Int32] = []
  let widths : Array[Int32] = []
  for p in d.participants {
    let w = if text_width(p.label) + 4 < 8 {
      8
    } else {
      text_width(p.label) + 4
    }
    widths.push(w)
  }
  let mut i = 0
  while i + 1 < n {
    let base = (widths[i] + widths[i + 1]) / 2 + 4
    steps.push(base)
    i = i + 1
  }
  // Grow the steps until every spanning label fits.
  let mut pass = 0
  while pass < 4 {
    for item in d.items {
      match item {
        Message(m) =>
          if m.from != m.to {
            let a = index_of_participant(d, m.from)
            let b = index_of_participant(d, m.to)
            let lo = if a < b { a } else { b }
            let hi = if a < b { b } else { a }
            let need = text_width(m.label) + 4
            let mut have = 0
            let mut k = lo
            while k < hi {
              have = have + steps[k]
              k = k + 1
            }
            if have < need {
              let deficit = need - have
              let share = (deficit + (hi - lo) - 1) / (hi - lo)
              let mut k2 = lo
              while k2 < hi {
                steps[k2] = steps[k2] + share
                k2 = k2 + 1
              }
            }
          }
        SelfMessage(s) => {
          let a = index_of_participant(d, s.who)
          if a < steps.length() {
            let need = text_width(s.label) + 6
            if steps[a] < need {
              steps[a] = need
            }
          }
        }
        Note(n) => {
          let a = index_of_participant(d, n.from)
          let b = index_of_participant(d, n.to)
          let lo = if a < b { a } else { b }
          let hi = if a < b { b } else { a }
          let need = text_width(n.text) + 4
          let mut have = 0
          let mut k = lo
          while k < hi {
            have = have + steps[k]
            k = k + 1
          }
          if have < need && hi > lo {
            let deficit = need - have
            let share = (deficit + (hi - lo) - 1) / (hi - lo)
            let mut k2 = lo
            while k2 < hi {
              steps[k2] = steps[k2] + share
              k2 = k2 + 1
            }
          }
        }
        _ => ()
      }
    }
    pass = pass + 1
  }
  steps
}

///|
fn max_depth(d : Diagram) -> Int32 {
  let mut depth = 0
  let mut max = 0
  for item in d.items {
    match item {
      GroupStart(_) => {
        depth = depth + 1
        if depth > max {
          max = depth
        }
      }
      GroupEnd => depth = depth - 1
      _ => ()
    }
  }
  max
}

///|
/// Render a parsed diagram as text.
pub fn render(d : Diagram) -> String {
  let lines : Array[Array[Char]] = []
  let n = d.participants.length()
  if n == 0 {
    return ""
  }
  let widths : Array[Int32] = []
  for p in d.participants {
    let w = if text_width(p.label) + 4 < 8 {
      8
    } else {
      text_width(p.label) + 4
    }
    widths.push(w)
  }
  let steps = required_steps(d)
  let centers : Array[Int32] = []
  let mut cursor = widths[0] / 2
  centers.push(cursor)
  let mut i = 1
  while i < n {
    cursor = cursor + steps[i - 1]
    centers.push(cursor)
    i = i + 1
  }
  let margin = max_depth(d)
  let mut content_w = centers[n - 1] + widths[n - 1] / 2 + 1
  for item in d.items {
    match item {
      SelfMessage(sm) => {
        let a = index_of_participant(d, sm.who)
        let need = margin + centers[a] + text_width(sm.label) + 8
        if need > content_w {
          content_w = need
        }
      }
      _ => ()
    }
  }
  let width = margin + content_w + margin
  let open : Array[(Int32, Int32, Int32)] = [] // (start line, border col, right col)
  // Header: top border, label, bottom border with the lifeline stub.
  let top = blank(width)
  let mid = blank(width)
  let bot = blank(width)
  let mut p = 0
  while p < n {
    let left = margin + centers[p] - widths[p] / 2
    put_cell(top, left, '┌')
    fill_run(top, left + 1, left + widths[p] - 2, '─')
    put_cell(top, left + widths[p] - 1, '┐')
    let label = pad_center(d.participants[p].label, widths[p] - 2)
    put_text(mid, left + 1, label)
    put_cell(mid, left, '│')
    put_cell(mid, left + widths[p] - 1, '│')
    put_cell(bot, left, '└')
    fill_run(bot, left + 1, margin + centers[p] - 1, '─')
    put_cell(bot, margin + centers[p], '┬')
    fill_run(bot, margin + centers[p] + 1, left + widths[p] - 2, '─')
    put_cell(bot, left + widths[p] - 1, '┘')
    p = p + 1
  }
  lines.push(top)
  lines.push(mid)
  lines.push(bot)
  for item in d.items {
    match item {
      Message(m) => {
        let a = index_of_participant(d, m.from)
        let b = index_of_participant(d, m.to)
        let ca = margin + centers[a]
        let cb = margin + centers[b]
        let lo = if ca < cb { ca } else { cb }
        let hi = if ca < cb { cb } else { ca }
        let label_row = body_row(width, centers, margin)
        let label = m.label
        let lw = text_width(label)
        let span = hi - lo
        let start = lo + (span - lw) / 2
        put_text(label_row, start, label)
        lines.push(label_row)
        let arrow = body_row(width, centers, margin)
        let glyph = match m.style {
          Solid => '─'
          Dashed => '┄'
        }
        fill_run(arrow, lo + 1, hi - 1, glyph)
        put_cell(arrow, hi - 1, '>')
        let _ = m.open_head
        lines.push(arrow)
      }
      SelfMessage(s) => {
        let a = index_of_participant(d, s.who)
        let c = margin + centers[a]
        let text = " " + s.label
        let label_row = body_row(width, centers, margin)
        put_text(label_row, c + 2, text)
        lines.push(label_row)
        let glyph = match s.style {
          Solid => '─'
          Dashed => '┄'
        }
        let l = text_width(text) + 2
        let r1 = body_row(width, centers, margin)
        put_cell(r1, c, '├')
        fill_run(r1, c + 1, c + l - 1, glyph)
        put_cell(r1, c + l, '┐')
        lines.push(r1)
        let r2 = body_row(width, centers, margin)
        put_cell(r2, c, '│')
        put_cell(r2, c + 1, '<')
        fill_run(r2, c + 2, c + l - 1, glyph)
        put_cell(r2, c + l, '┘')
        lines.push(r2)
      }
      Note(nt) => {
        let a = index_of_participant(d, nt.from)
        let b = index_of_participant(d, nt.to)
        let ca = margin + centers[a]
        let cb = margin + centers[b]
        let lo = if ca < cb { ca } else { cb }
        let hi = if ca < cb { cb } else { ca }
        let inner = hi - lo - 1
        let top_row = body_row(width, centers, margin)
        put_cell(top_row, lo, '╭')
        fill_run(top_row, lo + 1, hi - 1, '─')
        put_cell(top_row, hi, '╮')
        lines.push(top_row)
        let text_row = body_row(width, centers, margin)
        put_cell(text_row, lo, '│')
        put_cell(text_row, hi, '│')
        let title = if text_width(nt.text) + 2 <= inner {
          pad_center(" " + nt.text + " ", inner)
        } else {
          let (clipped, _) = clip_to_width(nt.text, inner - 2)
          pad_center(" " + clipped + " ", inner)
        }
        put_text(text_row, lo + 1, title)
        lines.push(text_row)
        let bottom_row = body_row(width, centers, margin)
        put_cell(bottom_row, lo, '╰')
        fill_run(bottom_row, lo + 1, hi - 1, '─')
        put_cell(bottom_row, hi, '╯')
        lines.push(bottom_row)
      }
      GroupStart(g) => {
        let depth = open.length()
        let border = depth
        let right = width - 1 - depth
        let start = lines.length()
        open.push((start, border, right))
        let row = body_row(width, centers, margin)
        let head = if g.label.length() == 0 {
          g.kind
        } else {
          g.kind + " " + g.label
        }
        put_cell(row, border, '┌')
        put_cell(row, border + 1, '─')
        put_text(row, border + 3, head)
        let used = border + 3 + text_width(head) + 1
        fill_run(row, used, right - 1, '─')
        put_cell(row, right, '┐')
        lines.push(row)
      }
      GroupElse(label) =>
        if open.length() > 0 {
          let (_, border, right) = open[open.length() - 1]
          let row = body_row(width, centers, margin)
          put_cell(row, border, '├')
          fill_run(row, border + 1, right - 1, '─')
          put_cell(row, right, '┤')
          if label.length() > 0 {
            put_text(row, border + 2, " " + label + " ")
            put_cell(row, border + 2 + text_width(label) + 2, '─')
          }
          lines.push(row)
        }
      GroupEnd =>
        if open.length() > 0 {
          let (start, border, right) = open[open.length() - 1]
          ignore(open.pop())
          let row = body_row(width, centers, margin)
          put_cell(row, border, '└')
          fill_run(row, border + 1, right - 1, '─')
          put_cell(row, right, '┘')
          lines.push(row)
          // Draw the vertical borders on the rows the block owns.
          let mut k = start + 1
          while k < lines.length() - 1 {
            if lines[k][border] != '├' {
              put_cell(lines[k], border, '│')
            }
            put_cell(lines[k], right, '│')
            k = k + 1
          }
        }
    }
  }
  // Lifelines below the last item, so every column visibly ends.
  let tail = blank(width)
  let mut q = 0
  while q < n {
    put_cell(tail, margin + centers[q], '│')
    q = q + 1
  }
  lines.push(tail)
  let out = StringBuilder()
  let mut r = 0
  while r < lines.length() {
    out.write_string(row_to_string(lines[r]))
    if r + 1 < lines.length() {
      out.write_char('\n')
    }
    r = r + 1
  }
  out.to_string()
}
