import PlumaProto

open Lean Elab.Command Parser

namespace Compile

@[plumaData]
structure Code where
  src : String

@[plumaData]
structure Response where
  compiled : Bool
  messages : Array String

/--
We reproduce the parser test function from Lean, so we can collect the error
messages instead of printing them.
-/
partial def parseModuleAux (env : Environment) (inputCtx : InputContext) (s : ModuleParserState) (msgs : MessageLog) (stxs  : Array Syntax) : IO (Array Syntax) :=
  let rec parse (state : ModuleParserState) (msgs : MessageLog) (stxs : Array Syntax) :=
    match parseCommand inputCtx { env := env, options := {} } state msgs with
    | (stx, state, msgs) =>
      if isTerminalCommand stx then
        if !msgs.hasUnreported then
          pure (stxs.push stx)
        else do
          let messages ← msgs.toList.mapM (·.toString)
          throw <| IO.userError <| "\n".intercalate messages
      else
        parse state msgs (stxs.push stx)
  parse s msgs stxs

def parseModule (env : Environment) (fname contents : String) : IO Syntax := do
  let inputCtx := mkInputContext contents fname
  let (header, state, messages) ← parseHeader inputCtx
  let cmds ← parseModuleAux env inputCtx state messages #[]
  let stx := mkNode `Lean.Parser.Module.module #[header, mkListNode cmds]
  pure stx

private def doCompile (req : Code) : PlumaM Response := do
  let src := req.src
  let env := (← read).env
  let mod ← try
      parseModule env "<input>" src
    catch e =>
      return ⟨ false, #[s!"{repr e}"] ⟩
  let cursor := Syntax.Traverser.fromSyntax mod
  let act : CommandElabM Response := withoutModifyingEnv do
    let mut commands := cursor.down 1 |>.down 0
    while true do
      try
        elabCommand commands.cur
      catch e =>
        return ⟨ false, #[s!"{← e.toMessageData.toString}"] ⟩
      let messages := (← get).messages
      if messages.hasErrors then
        return ⟨ false, (← messages.toArray.mapM (·.toString)) ⟩
      commands := commands.right
      if commands.cur.isMissing then
        break
    return ⟨ true, #[] ⟩
  act

def compile : Plugin := mkPlugin "compile" doCompile

end Compile
