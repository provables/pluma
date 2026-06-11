import PlumaProto

open Lean Elab.Command

namespace Compile

@[plumaData]
structure Code where
  src : String

@[plumaData]
structure Response where
  compiled : Bool
  messages : Array String

private def doCompile (req : Code) : PlumaM Response := do
  let src := req.src
  let env := (← read).env
  let cursor := Syntax.Traverser.fromSyntax (← Parser.testParseModule env "<input>" src)
  let mut commands := cursor.down 1 |>.down 0
  while true do
    elabCommand commands.cur
    let messages := (← get).messages
    if messages.hasErrors then
      return ⟨ false, (← messages.toArray.mapM (·.toString)) ⟩
    commands := commands.right
    if commands.cur.isMissing then
      break
  return ⟨ true, #[] ⟩

def compile : Plugin := mkPlugin "compile" doCompile

end Compile
