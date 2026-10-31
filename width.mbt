///|
/// Display width of a character in a terminal cell.
///
/// The table below covers the ranges a diagram label realistically uses. It is
/// deliberately a range table rather than a Unicode database: the renderer only
/// needs to keep columns aligned, and every range here is documented so the
/// boundary is explicit instead of guessed.
pub fn char_width(c : Char) -> Int32 {
  let n = c.to_int()
  // Control characters and zero-width marks occupy no cell.
  if n < 0x20 || (n >= 0x7F && n < 0xA0) {
    return 0
  }
  if is_zero_width(n) {
    return 0
  }
  if is_wide(n) {
    return 2
  }
  1
}

///|
fn is_zero_width(n : Int32) -> Bool {
  (n >= 0x0300 && n <= 0x036F) ||
  (n >= 0x200B && n <= 0x200F) ||
  (n >= 0xFE00 && n <= 0xFE0F) ||
  n == 0xFEFF
}

///|
fn is_wide(n : Int32) -> Bool {
  (n >= 0x1100 && n <= 0x115F) ||
  (n >= 0x2E80 && n <= 0x303E) ||
  (n >= 0x3041 && n <= 0x33FF) ||
  (n >= 0x3400 && n <= 0x4DBF) ||
  (n >= 0x4E00 && n <= 0x9FFF) ||
  (n >= 0xA000 && n <= 0xA4CF) ||
  (n >= 0xAC00 && n <= 0xD7A3) ||
  (n >= 0xF900 && n <= 0xFAFF) ||
  (n >= 0xFE30 && n <= 0xFE6F) ||
  (n >= 0xFF00 && n <= 0xFF60) ||
  (n >= 0xFFE0 && n <= 0xFFE6) ||
  (n >= 0x1F300 && n <= 0x1F64F) ||
  (n >= 0x1F900 && n <= 0x1F9FF) ||
  (n >= 0x20000 && n <= 0x3FFFD)
}

///|
/// Display width of a whole string.
pub fn text_width(text : String) -> Int32 {
  let mut total = 0
  for c in text {
    total = total + char_width(c)
  }
  total
}

///|
/// Slice a string so that its display width does not exceed `limit`.
/// Returns the prefix and the width actually used.
pub fn clip_to_width(text : String, limit : Int32) -> (String, Int32) {
  let sb = StringBuilder()
  let mut used = 0
  for c in text {
    let w = char_width(c)
    if used + w > limit {
      break
    }
    sb.write_char(c)
    used = used + w
  }
  (sb.to_string(), used)
}

///|
/// Pad with spaces on the right until the display width reaches `target`.
pub fn pad_right(text : String, target : Int32) -> String {
  let w = text_width(text)
  if w >= target {
    return text
  }
  text + " ".repeat(target - w)
}

///|
/// Pad on both sides as evenly as possible.
pub fn pad_center(text : String, target : Int32) -> String {
  let w = text_width(text)
  if w >= target {
    return text
  }
  let diff = target - w
  let left = diff / 2
  " ".repeat(left) + text + " ".repeat(diff - left)
}
