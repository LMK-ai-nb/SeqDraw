///|
fn chars_of(s : String) -> Array[Char] {
  s.to_array()
}

///|
fn slice_chars(src : Array[Char], start : Int32, end : Int32) -> String {
  let sb = StringBuilder()
  let mut i = start
  while i < end && i < src.length() {
    sb.write_char(src[i])
    i = i + 1
  }
  sb.to_string()
}

///|
fn trim_text(s : String) -> String {
  let a = chars_of(s)
  let mut lo = 0
  let mut hi = a.length()
  while lo < hi && (a[lo] == ' ' || a[lo] == '\t') {
    lo = lo + 1
  }
  while hi > lo && (a[hi - 1] == ' ' || a[hi - 1] == '\t') {
    hi = hi - 1
  }
  slice_chars(a, lo, hi)
}

///|
fn find_sub(src : Array[Char], pat : Array[Char], from : Int32) -> Int32 {
  if pat.length() == 0 {
    return from
  }
  let mut i = from
  while i + pat.length() <= src.length() {
    let mut j = 0
    let mut same = true
    while j < pat.length() {
      if src[i + j] != pat[j] {
        same = false
        break
      }
      j = j + 1
    }
    if same {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn starts_with(src : Array[Char], pat : String) -> Bool {
  let p = chars_of(pat)
  if p.length() > src.length() {
    return false
  }
  let mut i = 0
  while i < p.length() {
    if src[i] != p[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn strip_prefix(line : Array[Char], prefix : String) -> String {
  let p = chars_of(prefix).length()
  slice_chars(line, p, line.length())
}

///|
fn index_of_char(src : Array[Char], c : Char, from : Int32) -> Int32 {
  let mut i = from
  while i < src.length() {
    if src[i] == c {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn style_of(arrow : String) -> (ArrowStyle, Bool) {
  match arrow {
    "-->>" => (Dashed, true)
    "->>" => (Solid, true)
    "-->" => (Dashed, false)
    _ => (Solid, false)
  }
}

///|
fn is_arrow(arrow : String) -> Bool {
  arrow == "->" || arrow == "-->" || arrow == "->>" || arrow == "-->>"
}

///|
/// Parse the line-oriented DSL into a diagram.
///
/// Grammar, one construct per line:
///   participant ID as LABEL      declare a column (also created on first use)
///   A -> B: text                 solid arrow, filled head
///   A --> B: text                dashed arrow
///   A ->> B: text                solid arrow, open head
///   A -->> B: text               dashed arrow, open head
///   A -> A: text                 self message
///   note over A[,B]: text        note box spanning the given columns
///   alt LABEL / else LABEL / loop LABEL / opt LABEL / end
/// Lines starting with # or // are comments.
fn step(
  lines : Array[String],
  index : Int32,
  participants : Array[Participant],
  items : Array[Item],
  groups : Int32,
) -> Result[Int32, ParseError] {
  if index >= lines.length() {
    return Ok(groups)
  }
  let line_no = index + 1
  let line = chars_of(trim_text(lines[index]))
  let next = index + 1
  if line.length() == 0 {
    return step(lines, next, participants, items, groups)
  }
  if line[0] == '#' || starts_with(line, "//") {
    return step(lines, next, participants, items, groups)
  }
  if starts_with(line, "participant ") {
    let rest = trim_text(strip_prefix(line, "participant "))
    if rest.length() == 0 {
      return Err({ line: line_no, message: "participant needs an id", })
    }
    let pair = split_as(rest)
    add_participant(participants, pair.0, pair.1)
    return step(lines, next, participants, items, groups)
  }
  if starts_with(line, "note over ") {
    let rest = trim_text(strip_prefix(line, "note over "))
    let rchars = chars_of(rest)
    let colon = index_of_char(rchars, ':', 0)
    if colon < 0 {
      return Err({
        line: line_no,
        message: "note needs ': text' after the participants",
      })
    }
    let head = trim_text(slice_chars(rchars, 0, colon))
    let text = trim_text(slice_chars(rchars, colon + 1, rchars.length()))
    let parts = split_comma(head)
    let from = if parts.length() > 0 { parts[0] } else { "" }
    let to = if parts.length() > 1 { parts[1] } else { from }
    if from.length() == 0 {
      return Err({
        line: line_no,
        message: "note needs at least one participant",
      })
    }
    let from_id = ensure(participants, from)
    let to_id = ensure(participants, to)
    items.push(Note({ from: from_id, to: to_id, text, }))
    return step(lines, next, participants, items, groups)
  }
  match group_keyword(line) {
    Some(kind) =>
      if kind == "else" {
        if groups == 0 {
          return Err({
            line: line_no,
            message: "else without a matching alt or loop",
          })
        }
        let rest = trim_text(strip_prefix(line, "else"))
        items.push(GroupElse(rest))
        return step(lines, next, participants, items, groups)
      } else if kind == "end" {
        if groups == 0 {
          return Err({
            line: line_no,
            message: "end without a matching alt or loop",
          })
        }
        items.push(GroupEnd)
        return step(lines, next, participants, items, groups - 1)
      } else {
        let rest = trim_text(strip_prefix(line, kind))
        items.push(GroupStart({ kind, label: rest, }))
        return step(lines, next, participants, items, groups + 1)
      }
    None => ()
  }
  match parse_message(line) {
    Some(msg) => {
      let from_id = ensure(participants, msg.0)
      let to_id = ensure(participants, msg.1)
      let (style, open_head) = style_of(msg.2)
      if from_id == to_id {
        items.push(SelfMessage({ who: from_id, label: msg.3, style, }))
      } else {
        items.push(
          Message({ from: from_id, to: to_id, label: msg.3, style, open_head, }),
        )
      }
      return step(lines, next, participants, items, groups)
    }
    None =>
      return Err({
        line: line_no,
        message: "cannot read this line; expected a message, message arrow, note, group or participant declaration",
      })
  }
}

///|
/// Parse the line-oriented DSL into a diagram.
pub fn parse(source : String) -> Result[Diagram, ParseError] {
  let participants : Array[Participant] = []
  let items : Array[Item] = []
  match step(chars_lines(source), 0, participants, items, 0) {
    Err(err) => Err(err)
    Ok(groups) =>
      if groups != 0 {
        Err({ line: 1, message: "unclosed alt or loop block", })
      } else {
        Ok({ participants, items, })
      }
  }
}

///|
fn chars_lines(source : String) -> Array[String] {
  let out : Array[String] = []
  let src = chars_of(source)
  let mut start = 0
  let mut i = 0
  while i < src.length() {
    if src[i] == '\n' {
      let mut end = i
      if end > start && src[end - 1] == '\r' {
        end = end - 1
      }
      out.push(slice_chars(src, start, end))
      start = i + 1
    }
    i = i + 1
  }
  if start < src.length() {
    let mut end = src.length()
    if end > start && src[end - 1] == '\r' {
      end = end - 1
    }
    out.push(slice_chars(src, start, end))
  }
  out
}

///|
fn split_as(rest : String) -> (String, String) {
  let a = chars_of(rest)
  let pos = find_sub(a, chars_of(" as "), 0)
  if pos < 0 {
    let id = trim_text(rest)
    (id, id)
  } else {
    let id = trim_text(slice_chars(a, 0, pos))
    let label = trim_text(slice_chars(a, pos + 4, a.length()))
    (id, if label.length() == 0 { id } else { label })
  }
}

///|
fn split_comma(text : String) -> Array[String] {
  let out : Array[String] = []
  let a = chars_of(text)
  let mut start = 0
  let mut i = 0
  while i < a.length() {
    if a[i] == ',' {
      out.push(trim_text(slice_chars(a, start, i)))
      start = i + 1
    }
    i = i + 1
  }
  out.push(trim_text(slice_chars(a, start, a.length())))
  out
}

///|
fn group_keyword(line : Array[Char]) -> String? {
  if starts_with(line, "alt ") || line == chars_of("alt") {
    return Some("alt")
  }
  if starts_with(line, "loop ") || line == chars_of("loop") {
    return Some("loop")
  }
  if starts_with(line, "opt ") || line == chars_of("opt") {
    return Some("opt")
  }
  if line == chars_of("else") || starts_with(line, "else ") {
    return Some("else")
  }
  if line == chars_of("end") {
    return Some("end")
  }
  None
}

///|
/// Return (from, to, arrow, label) when the line is a message.
fn parse_message(line : Array[Char]) -> (String, String, String, String)? {
  let arrows = ["-->>", "->>", "-->", "->"]
  let mut i = 0
  while i < arrows.length() {
    let arrow = arrows[i]
    let pos = find_sub(line, chars_of(arrow), 1)
    if pos > 0 {
      let from = trim_text(slice_chars(line, 0, pos))
      let after = pos + chars_of(arrow).length()
      let colon = index_of_char(line, ':', after)
      if colon < 0 {
        return None
      }
      let to = trim_text(slice_chars(line, after, colon))
      let label = trim_text(slice_chars(line, colon + 1, line.length()))
      if from.length() == 0 || to.length() == 0 || !is_arrow(arrow) {
        return None
      }
      return Some((from, to, arrow, label))
    }
    i = i + 1
  }
  None
}

///|
fn find_participant(ps : Array[Participant], id : String) -> Int32 {
  let mut i = 0
  while i < ps.length() {
    if ps[i].id == id {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn add_participant(
  ps : Array[Participant],
  id : String,
  label : String,
) -> Unit {
  if find_participant(ps, id) < 0 {
    ps.push({ id, label, })
  }
}

///|
/// Register a participant if it is new, and return its id.
fn ensure(ps : Array[Participant], id : String) -> String {
  if find_participant(ps, id) < 0 {
    ps.push({ id, label: id, })
  }
  id
}
