///|
/// Command line front end: read a .seq file, render it, print the result.
fn usage() -> Unit {
  println("seqdraw — render sequence diagrams as terminal text")
  println("")
  println("usage: seqdraw <file.seq>")
  println("")
  println("The file grammar is documented in README.md: participants, arrows,")
  println("self messages, notes and alt/loop blocks, one construct per line.")
}

///|
fn load(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => ""
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    usage()
    return
  }
  let path = args[1]
  if path == "--help" || path == "-h" {
    usage()
    return
  }
  let source = load(path)
  if source.length() == 0 {
    eprintln("seqdraw: cannot read '\{path}'")
    return
  }
  match @seqdraw.parse(source) {
    Err(err) => eprintln("seqdraw: \{err.to_text()}")
    Ok(diagram) => println(@seqdraw.render(diagram))
  }
}
