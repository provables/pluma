import PlumaProto

open Lean Elab.Command

namespace Eval

@[plumaData]
structure Code where
  src : String

structure Response where
  compiled : Bool
  deriving ToJson

def doEval (req : Code) : PlumaM Response := do
  IO.println s!"requested: {req.src}"
  let y ← ((do
    elabCommand (← `(command|#print "hello"))
    elabCommand (← `(command|def $(mkIdent `gooo) : Nat := 45))
  ) : CommandElabM Unit)
  dbg_trace y
  return ⟨true⟩

def eval : Plugin := mkPlugin "eval" doEval

end Eval
