///|
/// How a message line is drawn.
pub(all) enum ArrowStyle {
  Solid
  Dashed
}

///|
/// One participant column.
pub(all) struct Participant {
  id : String
  label : String
}

///|
/// One item in the diagram body.
pub(all) enum Item {
  Message(Message)
  SelfMessage(SelfMessage)
  Note(Note)
  GroupStart(GroupStart)
  GroupElse(String)
  GroupEnd
}

///|
pub(all) struct Message {
  from : String
  to : String
  label : String
  style : ArrowStyle
  open_head : Bool
}

///|
pub(all) struct SelfMessage {
  who : String
  label : String
  style : ArrowStyle
}

///|
pub(all) struct Note {
  from : String
  to : String
  text : String
}

///|
pub(all) struct GroupStart {
  kind : String
  label : String
}

///|
pub(all) struct Diagram {
  participants : Array[Participant]
  items : Array[Item]
}

///|
/// A parse error carries the 1-based line number so the CLI can point at it.
pub(all) struct ParseError {
  line : Int32
  message : String
}

///|
/// Render the error for the command line.
pub fn ParseError::to_text(self : ParseError) -> String {
  "line \{self.line}: \{self.message}"
}
