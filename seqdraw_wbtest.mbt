///|
/// Tests for display width, parsing and rendering.
test "width counts wide characters twice" {
  assert_eq(text_width("abc"), 3)
  assert_eq(text_width("服务端"), 6)
  assert_eq(text_width("a服b"), 4)
}

///|
test "clip never splits a wide character" {
  let (text, used) = clip_to_width("服务端", 5)
  assert_eq(text, "服务")
  assert_eq(used, 4)
}

///|
test "parse reads declarations, arrows and blocks" {
  let source =
    #|participant A as Client
    #|participant B as Server
    #|A -> B: ping
    #|B --> A: pong
    #|alt ok
    #|  A -> A: note to self
    #|end
  let diagram = parse(source).unwrap()
  assert_eq(diagram.participants.length(), 2)
  assert_eq(diagram.items.length(), 5)
}

///|
test "parse reports the line of a broken construct" {
  let source =
    #|A -> B: fine
    #|this line is not a message
  match parse(source) {
    Ok(_) => fail("expected a parse error")
    Err(err) => assert_eq(err.line, 2)
  }
}

///|
test "parse rejects an unclosed block" {
  let source =
    #|alt ok
    #|  A -> B: ping
  match parse(source) {
    Ok(_) => fail("expected a parse error")
    Err(err) => assert_eq(err.message, "unclosed alt or loop block")
  }
}

///|
test "renders a stable diagram" {
  let source =
    #|participant A as Client
    #|participant B as Server
    #|A -> B: ping
    #|B --> A: pong
  let diagram = parse(source).unwrap()
  let expected =
    #|┌────────┐    ┌────────┐
    #|│ Client │    │ Server │
    #|└────┬───┘    └────┬───┘
    #|     │    ping     │
    #|     │────────────>│
    #|     │    pong     │
    #|     │┄┄┄┄┄┄┄┄┄┄┄┄>│
    #|     │             │
  assert_eq(render(diagram), expected)
}
